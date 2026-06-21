// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FootballNotch",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "FootballNotchCore"),
        .executableTarget(
            name: "FootballNotch",
            dependencies: ["FootballNotchCore"]
        ),
        .testTarget(
            name: "FootballNotchCoreTests",
            dependencies: ["FootballNotchCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
