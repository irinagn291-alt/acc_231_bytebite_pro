// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ByteKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "ByteKit", targets: ["ByteKit"]),
    ],
    targets: [
        .target(name: "ByteKit"),
        .testTarget(name: "ByteKitTests", dependencies: ["ByteKit"]),
    ]
)
