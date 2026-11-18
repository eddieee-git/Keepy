// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Keepy",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Keepy",
            path: "Sources/Keepy"
        )
    ],
    swiftLanguageModes: [.v5]
)
