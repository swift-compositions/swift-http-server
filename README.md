# swift-http-server

Use this package to send RFC 9110 responses well: with an entity tag and a 304 when the reader already holds the answer, gzipped when the reader takes gzip, and with the request fields the answer varies on. Depend on `HTTP Delivery` and call `RFC_9110.Message.Response(delivering:to:tag:)` on the response your site made for a request, with the function that names a body's entity tag. To serve a function of an RFC 9110 request to an RFC 9110 response with Hummingbird, turn on the `Hummingbird` trait and use `Responder` from `HTTP Server Hummingbird`.

## Laws

- A body is gzipped only when its media type is textual (`text/*`, JSON, XML, or a `+json` or `+xml` suffix), it is at least 1,024 bytes, and the request's `Accept-Encoding` takes gzip over identity. Without `Accept-Encoding` nothing is gzipped.
- A gzipped answer has `Content-Encoding: gzip`, and every textual answer varies on `Accept-Encoding`, added after any `Vary` the site wrote; `Vary` is written through `RFC_9110.Negotiation.Vary`, so its field names go out lower case, which RFC 9110 reads as the same names.
- An answer whose `Cache-Control` says `no-store` gets no entity tag and never a 304.
- Every other answer gets the entity tag the caller's function names for its body, with `-gzip` added for the gzipped copy, so the two copies never share a tag. The package has no hash of its own. An answer without `Cache-Control` gets `no-cache`; a `Cache-Control` the site wrote is read and written back through `RFC_9110.Cache.Control`, in RFC 9111's directive order.
- A 200 answer whose tag the request's `If-None-Match` names, weakly or as `*`, becomes a 304 with no body.
- The last 256 gzipped bodies are kept by tag, so an answer asked for again is not compressed again.
- `HTTP Gzip` compresses with the system's zlib at its best compression.
- `Responder` refuses a request whose body is larger than `limit` gives for its media type with 413, and a request with a header RFC 9110 refuses with 400, without calling `answer`.
- `RFC_9110.Negotiation.EncodingPreference.best(of:accepting:)` from swift-rfc-9110 picks the encoding.
