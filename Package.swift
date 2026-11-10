// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "swift-http-server",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
        .tvOS(.v27),
        .watchOS(.v27),
        .visionOS(.v27),
    ],
    products: [
        .library(name: "HTTP Delivery", targets: ["HTTP Delivery"]),
        .library(name: "HTTP Gzip", targets: ["HTTP Gzip"]),
        .library(name: "HTTP Server Hummingbird", targets: ["HTTP Server Hummingbird"]),
    ],
    traits: [
        .trait(name: "Hummingbird", description: "A Hummingbird responder built from a function of an RFC 9110 request to an RFC 9110 response")
    ],
    dependencies: [
        .package(url: "https://github.com/swift-atoms/swift-byte.git", branch: "main"),
        .package(url: "https://github.com/swift-ietf/swift-rfc-9110.git", branch: "main", traits: ["Coder"]),
        .package(url: "https://github.com/swift-ietf/swift-rfc-9111.git", branch: "main", traits: ["Coder"]),
        .package(url: "https://github.com/apple/swift-http-types.git", from: "1.0.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", exact: "2.28.1"),
    ],
    targets: [
        .systemLibrary(
            name: "Zlib Shims",
            pkgConfig: "zlib",
            providers: [.apt(["zlib1g-dev"]), .brew(["zlib"])]
        ),
        .target(
            name: "HTTP Gzip",
            dependencies: [
                .target(name: "Zlib Shims")
            ]
        ),
        .target(
            name: "HTTP Delivery",
            dependencies: [
                .target(name: "HTTP Gzip"),
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "RFC 9110", package: "swift-rfc-9110"),
                .product(name: "RFC 9111", package: "swift-rfc-9111"),
            ]
        ),
        .target(
            name: "HTTP Server Hummingbird",
            dependencies: [
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "RFC 9110", package: "swift-rfc-9110"),
                .product(name: "HTTPTypes", package: "swift-http-types", condition: .when(traits: ["Hummingbird"])),
                .product(name: "Hummingbird", package: "hummingbird", condition: .when(traits: ["Hummingbird"])),
            ]
        ),
        .testTarget(
            name: "HTTP Delivery Tests",
            dependencies: [
                .target(name: "HTTP Delivery"),
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "RFC 9110", package: "swift-rfc-9110"),
            ]
        ),
        .testTarget(
            name: "HTTP Server Hummingbird Tests",
            dependencies: [
                .target(name: "HTTP Server Hummingbird"),
                .product(name: "Byte", package: "swift-byte"),
                .product(name: "RFC 9110", package: "swift-rfc-9110"),
                .product(name: "HTTPTypes", package: "swift-http-types", condition: .when(traits: ["Hummingbird"])),
                .product(name: "Hummingbird", package: "hummingbird", condition: .when(traits: ["Hummingbird"])),
                .product(name: "HummingbirdTesting", package: "hummingbird", condition: .when(traits: ["Hummingbird"])),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    target.swiftSettings =
        (target.swiftSettings ?? []) + [
            .strictMemorySafety(),
            .enableUpcomingFeature("ExistentialAny"),
            .enableUpcomingFeature("InternalImportsByDefault"),
            .enableUpcomingFeature("MemberImportVisibility"),
            .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            .enableUpcomingFeature("InferIsolatedConformances"),
            .enableExperimentalFeature("Lifetimes"),
            .treatAllWarnings(as: .error),
        ]
}
