import Byte
import HTTP_Gzip
import RFC_9110
import RFC_9111
import Synchronization

public enum Delivery {}

extension Delivery {

    public static let smallest = 1024

    public static let capacity = 256
}

extension Delivery {

    static let kept = Mutex<[String: [Byte]]>([:])

    static func gzipped(_ body: [Byte], tag: String) -> [Byte] {
        if let kept = kept.withLock({ $0[tag] }) { return kept }
        let compressed = [Byte](bitPatterns: Gzip.compressed(body.map(\.bitPattern)))
        kept.withLock { kept in
            if kept.count >= capacity { kept.removeAll(keepingCapacity: true) }
            kept[tag] = compressed
        }
        return compressed
    }
}
