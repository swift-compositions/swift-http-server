public import Byte
import HTTP_Gzip
public import RFC_9110
import RFC_9111

extension RFC_9110.Message.Response where Content == [Byte] {

    public init<Asked>(
        delivering response: Self,
        to request: RFC_9110.Message.Request<Asked>,
        tag: ([Byte]) -> RFC_9110.Representation.Validator.EntityTag
    ) {
        let body = response.content ?? []
        let textual =
            response.headers[.contentType].first
            .flatMap { RFC_9110.MediaType(parsing: $0.description) }?.isTextual ?? false
        let accepted =
            request.headers[.acceptEncoding].first.map {
                RFC_9110.Negotiation.EncodingPreference.best(
                    of: [.gzip, .identity],
                    accepting: RFC_9110.Negotiation.EncodingPreference.parse($0.description)
                ) == .gzip
            } ?? false
        let gzipped = textual && body.count >= Delivery.smallest && accepted

        var headers = response.headers
        let named = headers[.vary].flatMap { $0.description.split(separator: ",").map { String($0).filter { $0 != " " } } }
        let varied = named + (textual ? ["Accept-Encoding"] : [])
        headers.remove(.vary)
        if gzipped {
            headers.append(RFC_9110.Field(name: .contentEncoding, value: RFC_9110.Field.Value(unchecked: "gzip")))
        }

        let written = headers[.cacheControl].first.map {
            var input = [Byte](utf8: $0.description)[...]
            return RFC_9110.Cache.Control.coder.parse(&input)
        }
        headers.remove(.cacheControl)
        var control = written ?? RFC_9110.Cache.Control()
        let unchanged: Bool
        let sent: [Byte]
        if control.noStore {
            unchanged = false
            sent = gzipped ? [Byte](bitPatterns: Gzip.compressed(body.map(\.bitPattern))) : body
        } else {
            let given = tag(body)
            let tag = gzipped ? RFC_9110.Representation.Validator.EntityTag(value: given.value + "-gzip", isWeak: given.isWeak) : given
            if written == nil {
                control.noCache = true
            }
            headers.append(RFC_9110.Field(name: .etag, value: RFC_9110.Field.Value(unchecked: tag.headerValue)))
            let held =
                request.headers[.ifNoneMatch].first
                .flatMap { RFC_9110.Precondition.parseIfNoneMatch($0.description) }
                .map { !$0.evaluate(currentETag: tag, lastModified: nil) } ?? false
            unchanged = response.status == .ok && held
            sent = unchanged ? [] : gzipped ? Delivery.gzipped(body, tag: tag.headerValue) : body
        }
        var serialized: [Byte] = []
        RFC_9110.Cache.Control.coder.serialize(control, into: &serialized)
        headers.append(RFC_9110.Field(name: .cacheControl, value: RFC_9110.Field.Value(unchecked: String(decoding: serialized.map(\.bitPattern), as: UTF8.self))))
        if !varied.isEmpty {
            headers.append(RFC_9110.Field(name: .vary, value: RFC_9110.Field.Value(unchecked: RFC_9110.Negotiation.Vary(fieldNames: varied).headerValue)))
        }
        self.init(
            status: unchanged ? .notModified : response.status,
            reason: unchanged ? nil : response.reason,
            headers: headers,
            content: sent,
            trailers: response.trailers
        )
    }
}
