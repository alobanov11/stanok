// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StanokKit",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "StanokKit", targets: ["StanokKit"]),
        .library(name: "StanokTerminal", targets: ["StanokTerminal"])
    ],
    targets: [
        .target(name: "StanokKit", path: "Sources"),
        .binaryTarget(name: "GhosttyKit", path: "GhosttyKit.xcframework"),
        .target(name: "StanokTerminal", dependencies: ["StanokKit", "GhosttyKit"], path: "Terminal")
    ]
)
