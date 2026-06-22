// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SportNotch",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "SportNotchCore"),
        .executableTarget(
            name: "SportNotch",
            dependencies: ["SportNotchCore"]
        ),
        .testTarget(
            name: "SportNotchCoreTests",
            dependencies: ["SportNotchCore"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
