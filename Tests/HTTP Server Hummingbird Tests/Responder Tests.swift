#if Hummingbird
    import Byte
    import HTTPTypes
    import HTTP_Server_Hummingbird
    import Hummingbird
    import HummingbirdTesting
    import RFC_9110
    import Testing

    @Suite
    struct `Responder Tests` {
        static let responder = Responder(
            limit: { _ in 8 },
            answer: { request in
                let host = request.headers[.host].first?.rawValue ?? ""
                return RFC_9110.Message.Response(
                    status: .ok,
                    headers: [RFC_9110.Field(name: .contentType, value: RFC_9110.Field.Value(unchecked: "text/plain"))],
                    content: [Byte](utf8: "\(request.method.rawValue) \(host) \((request.content ?? []).count)")
                )
            }
        )

        @Test
        func `a request reaches the answer as an RFC 9110 request, with its host, and its answer goes back`() async throws {
            let application = Application(responder: Self.responder)
            try await application.test(.live) { client in
                try await client.execute(uri: "/apps", method: .post, body: ByteBuffer(string: "four")) { response in
                    #expect(response.status == .ok)
                    let text = String(buffer: response.body)
                    #expect(text == "POST localhost 4")
                    #expect(response.headers[.contentType] == "text/plain")
                }
            }
        }

        @Test
        func `a body over the limit is refused with 413 and never reaches the answer`() async throws {
            let application = Application(responder: Self.responder)
            try await application.test(.router) { client in
                try await client.execute(uri: "/apps", method: .post, body: ByteBuffer(string: "more than eight bytes")) { response in
                    #expect(response.status == .contentTooLarge)
                }
            }
        }
    }
#endif
