#if Hummingbird
    public import Byte
    import HTTPTypes
    public import Hummingbird
    public import RFC_9110

    public struct Responder {
        public let limit: @Sendable (RFC_9110.MediaType?) -> Int

        public let answer: @Sendable (RFC_9110.Message.Request<[Byte]>) async -> RFC_9110.Message.Response<[Byte]>

        public init(
            limit: @escaping @Sendable (RFC_9110.MediaType?) -> Int,
            answer: @escaping @Sendable (RFC_9110.Message.Request<[Byte]>) async -> RFC_9110.Message.Response<[Byte]>
        ) {
            self.limit = limit
            self.answer = answer
        }
    }

    extension Responder: HTTPResponder {
        public typealias Context = BasicRequestContext

        public func respond(to request: Request, context: BasicRequestContext) async -> Response {
            var fields: [RFC_9110.Field] = []
            if let authority = request.head.authority {
                fields.append(RFC_9110.Field(name: .host, value: RFC_9110.Field.Value(unchecked: authority)))
            }
            for field in request.headers {
                do throws(RFC_9110.Field.Error) {
                    fields.append(try RFC_9110.Field(name: field.name.rawName, value: field.value))
                } catch {
                    return Response(status: .badRequest)
                }
            }
            let type = request.headers[.contentType].flatMap { RFC_9110.MediaType(parsing: $0) }
            let content: [Byte]
            do {
                let buffer = try await request.body.collect(upTo: limit(type))
                content = [Byte](bitPatterns: Array(buffer.readableBytesView))
            } catch {
                return Response(status: .contentTooLarge)
            }
            let answered = await answer(
                RFC_9110.Message.Request(
                    method: RFC_9110.Method(rawValue: request.method.description),
                    target: RFC_9110.Target(unchecked: request.head.path ?? "/"),
                    headers: RFC_9110.Message.Headers(fields),
                    content: content.isEmpty ? nil : content
                )
            )
            return Response(answered)
        }
    }

    extension Response {

        public init(_ response: RFC_9110.Message.Response<[Byte]>) {
            var headers = HTTPFields()
            for field in response.headers {
                guard let name = HTTPField.Name(field.name.description) else { continue }
                headers.append(HTTPField(name: name, value: field.value.description))
            }
            self.init(
                status: HTTPResponse.Status(code: response.status.code),
                headers: headers,
                body: ResponseBody(byteBuffer: ByteBuffer(bytes: (response.content ?? []).map(\.bitPattern)))
            )
        }
    }
#endif
