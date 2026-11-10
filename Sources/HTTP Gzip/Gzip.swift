import CZlib

public enum Gzip {}

extension Gzip {

    public static func compressed(_ bytes: [UInt8]) -> [UInt8] {
        var stream = unsafe z_stream()
        guard
            unsafe deflateInit2_(
                &stream,
                Z_BEST_COMPRESSION,
                Z_DEFLATED,
                15 + 16,
                9,
                Z_DEFAULT_STRATEGY,
                ZLIB_VERSION,
                Int32(MemoryLayout<z_stream>.size)
            ) == Z_OK
        else { preconditionFailure("zlib refused its own defaults") }
        defer { unsafe deflateEnd(&stream) }
        var output = [UInt8](repeating: 0, count: Int(unsafe deflateBound(&stream, uLong(bytes.count))))
        var input = bytes
        let written = input.withUnsafeMutableBufferPointer { source in
            output.withUnsafeMutableBufferPointer { target in
                unsafe stream.next_in = source.baseAddress
                unsafe stream.avail_in = uInt(source.count)
                unsafe stream.next_out = target.baseAddress
                unsafe stream.avail_out = uInt(target.count)
                let result = unsafe deflate(&stream, Z_FINISH)
                precondition(result == Z_STREAM_END, "deflateBound was too small")
                return unsafe target.count - Int(stream.avail_out)
            }
        }
        output.removeLast(output.count - written)
        return output
    }
}
