public import RFC_9110

extension RFC_9110.MediaType {

    public var isTextual: Bool {
        let type = type.lowercased()
        let subtype = subtype.lowercased()
        return type == "text"
            || subtype == "json" || subtype == "xml"
            || subtype.hasSuffix("+json") || subtype.hasSuffix("+xml")
    }
}
