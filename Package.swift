// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Keepy",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Keepy", path: "Sources/Keepy")
    ]
)
