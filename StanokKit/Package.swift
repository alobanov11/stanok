// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "StanokKit",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "StanokKit", targets: ["StanokKit"]),
        .library(name: "StanokTerminal", targets: ["StanokTerminal"]),
        .library(name: "StanokAgents", targets: ["StanokAgents"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/swiftlang/swift-markdown",
            revision: "ce613726d4047027fdb564bd1ad382a1cee8ecf0"
        )
    ],
    targets: [
        .target(
            name: "StanokKit",
            dependencies: [.product(name: "Markdown", package: "swift-markdown")],
            path: "Sources"
        ),
        .binaryTarget(name: "GhosttyKit", path: "GhosttyKit.xcframework"),
        .target(
            name: "StanokTerminal",
            dependencies: ["StanokKit", "GhosttyKit"],
            path: "Terminal",
            linkerSettings: [.linkedLibrary("stdc++"), .linkedFramework("Carbon")]
        ),
        .target(
            name: "StanokAgents",
            dependencies: ["StanokKit"],
            path: "Agents"
        )
    ]
)
