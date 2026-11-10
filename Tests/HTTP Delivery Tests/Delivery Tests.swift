import Byte
import HTTP_Delivery
import RFC_9110
import Testing

@Suite
struct `Delivery Tests` {
    let page = RFC_9110.Message.Response<[Byte]>(
        status: .ok,
        headers: [
            RFC_9110.Field(name: .contentType, value: RFC_9110.Field.Value(unchecked: "text/css; charset=utf-8")),
            RFC_9110.Field(name: .cacheControl, value: RFC_9110.Field.Value(unchecked: "public, max-age=31536000, immutable")),
        ],
        content: [Byte](utf8: String(repeating: "body { margin: 0 } ", count: 400))
    )

    static func tag(_ body: [Byte]) -> RFC_9110.Representation.Validator.EntityTag {
        .strong("length-\(body.count)")
    }

    func request(encodings: String? = nil, holding: String? = nil) -> RFC_9110.Message.Request<[Byte]> {
        var headers = RFC_9110.Message.Headers()
        if let encodings {
            headers.append(RFC_9110.Field(name: .acceptEncoding, value: RFC_9110.Field.Value(unchecked: encodings)))
        }
        if let holding {
            headers.append(RFC_9110.Field(name: .ifNoneMatch, value: RFC_9110.Field.Value(unchecked: holding)))
        }
        return RFC_9110.Message.Request(method: .get, target: RFC_9110.Target(unchecked: "/style.css"), headers: headers)
    }

    @Test
    func `a lasting answer's cache control is the site's directives, written in RFC 9111's order`() {
        let delivered = RFC_9110.Message.Response(delivering: page, to: request(), tag: Self.tag)
        #expect(delivered.headers[.cacheControl].map(\.rawValue) == ["max-age=31536000, public, immutable"])
    }

    @Test(arguments: ["gzip", "gzip, deflate, br", "br;q=1.0, gzip;q=0.8", "*"])
    func `text goes out gzipped to a reader that takes gzip`(encodings: String) {
        let delivered = RFC_9110.Message.Response(delivering: page, to: request(encodings: encodings), tag: Self.tag)
        let body = (delivered.content ?? []).map(\.bitPattern)
        #expect(delivered.headers[.contentEncoding].map(\.rawValue) == ["gzip"])
        #expect(body.starts(with: [0x1F, 0x8B]) && body.count < (page.content ?? []).count / 3)
        #expect(delivered.headers[.vary].map(\.rawValue) == ["accept-encoding"])
    }

    @Test(arguments: [nil, "identity", "gzip;q=0", "br"])
    func `text goes out as it is to a reader that does not take gzip`(encodings: String?) {
        let delivered = RFC_9110.Message.Response(delivering: page, to: request(encodings: encodings), tag: Self.tag)
        #expect(delivered.headers[.contentEncoding].isEmpty && delivered.content == page.content)
    }

    @Test
    func `a reader that holds the answer already gets 304 and no body`() throws {
        let first = RFC_9110.Message.Response(delivering: page, to: request(encodings: "gzip"), tag: Self.tag)
        let tag = try #require(first.headers[.etag].first?.rawValue)
        let again = RFC_9110.Message.Response(delivering: page, to: request(encodings: "gzip", holding: tag), tag: Self.tag)
        #expect(again.status == .notModified && (again.content ?? []).isEmpty)
        let plain = RFC_9110.Message.Response(delivering: page, to: request(holding: tag), tag: Self.tag)
        #expect(plain.status == .ok && plain.content == page.content, "a gzipped copy's tag is not the plain copy's")
    }

    @Test
    func `an answer without cache control is revalidated and tagged`() throws {
        var fresh = page
        fresh.headers.remove(.cacheControl)
        let delivered = RFC_9110.Message.Response(delivering: fresh, to: request(), tag: Self.tag)
        #expect(delivered.headers[.cacheControl].map(\.rawValue) == ["no-cache"])
        let tag = try #require(delivered.headers[.etag].first?.rawValue)
        #expect(tag.hasPrefix("\"") && tag.hasSuffix("\""))
    }

    @Test
    func `a personal answer is not stored and carries no tag`() {
        var personal = page
        personal.headers.remove(.cacheControl)
        personal.headers.append(RFC_9110.Field(name: .cacheControl, value: RFC_9110.Field.Value(unchecked: "no-store")))
        let delivered = RFC_9110.Message.Response(delivering: personal, to: request(holding: "*"), tag: Self.tag)
        #expect(delivered.headers[.etag].isEmpty && delivered.status == .ok)
    }

    @Test
    func `a negotiated answer varies on its language and its encoding`() {
        var negotiated = page
        negotiated.headers.append(RFC_9110.Field(name: .vary, value: RFC_9110.Field.Value(unchecked: "Accept-Language")))
        let delivered = RFC_9110.Message.Response(delivering: negotiated, to: request(), tag: Self.tag)
        #expect(delivered.headers[.vary].map(\.rawValue) == ["accept-language, accept-encoding"])
    }

    @Test
    func `a picture is never gzipped and varies on nothing`() {
        let picture = RFC_9110.Message.Response<[Byte]>(
            status: .ok,
            headers: [RFC_9110.Field(name: .contentType, value: RFC_9110.Field.Value(unchecked: "image/png"))],
            content: [Byte](repeating: Byte(bitPattern: 0), count: 4096)
        )
        let delivered = RFC_9110.Message.Response(delivering: picture, to: request(encodings: "gzip"), tag: Self.tag)
        #expect(delivered.headers[.contentEncoding].isEmpty && delivered.headers[.vary].isEmpty)
    }

    @Test
    func `the tag is the one the caller names, and the gzipped copy's adds -gzip`() throws {
        let plain = RFC_9110.Message.Response(delivering: page, to: request(), tag: Self.tag)
        let gzipped = RFC_9110.Message.Response(delivering: page, to: request(encodings: "gzip"), tag: Self.tag)
        #expect(plain.headers[.etag].first?.rawValue == "\"length-\((page.content ?? []).count)\"")
        #expect(gzipped.headers[.etag].first?.rawValue == "\"length-\((page.content ?? []).count)-gzip\"")
    }
}
