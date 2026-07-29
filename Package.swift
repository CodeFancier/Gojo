// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Gojo",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "GojoCore"),
        .executableTarget(
            name: "Gojo",
            dependencies: ["GojoCore"]
        ),
        .testTarget(name: "GojoCoreTests", dependencies: ["GojoCore"]),
    ]
)
