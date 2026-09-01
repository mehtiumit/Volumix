// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Volumix",
    platforms: [.macOS("14.4")],
    targets: [
        .target(
            name: "AudioCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "Volumix",
            dependencies: ["AudioCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // Phase 0 validation. Retained as a regression tool after the architecture was proven.
        .executableTarget(
            name: "spike",
            dependencies: ["AudioCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
