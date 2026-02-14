// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "AudioInput",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "AudioInput", targets: ["AudioInput"]),
    ],
    targets: [
        .executableTarget(
            name: "AudioInput",
            path: "Sources/AudioInput"
        )
    ]
)
