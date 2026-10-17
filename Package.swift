// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClipLine",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "ClipLine", targets: ["ClipLine"])
    ],
    targets: [
        .executableTarget(name: "ClipLine", path: "Sources/ClipLine"),
        .testTarget(name: "ClipLineTests", dependencies: ["ClipLine"])
    ]
)
