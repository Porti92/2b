// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "SecondBrain",
    platforms: [
        .macOS(.v12)
    ],
    dependencies: [
        .package(url: "https://github.com/soffes/HotKey.git", from: "0.1.0")
    ],
    targets: [
        .target(
            name: "SecondBrain",
            dependencies: ["HotKey"]
        )
    ]
) 