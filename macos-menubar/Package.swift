// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TextSnapBar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "TextSnapBar",
            path: "Sources/TextSnapBar"
        )
    ]
)
