// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "EdgeBar",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/Kyome22/OpenMultitouchSupport.git", exact: "4.0.0")
    ],
    targets: [
        .executableTarget(
            name: "EdgeBar",
            dependencies: [.product(name: "OpenMultitouchSupport", package: "OpenMultitouchSupport")]
        )
    ]
)
