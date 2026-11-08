// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Waan",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Waan"
        ),
    ]
)
