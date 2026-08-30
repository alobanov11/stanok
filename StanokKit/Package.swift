// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StanokKit",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "StanokKit", targets: ["StanokKit"])
    ],
    targets: [
        .target(name: "StanokKit", path: "Sources")
    ]
)
