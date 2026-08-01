// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Gojo",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "GojoCore"),
        .executableTarget(
            name: "Gojo",
            dependencies: ["GojoCore"],
            // Info.plist / Gojo.icns 仅供打包脚本使用，排除出运行时资源 bundle。
            exclude: ["Resources/Info.plist", "Resources/Gojo.icns"],
            resources: [
                .process("Resources/gojo-wordmark.png"),
            ]
        ),
        .testTarget(name: "GojoCoreTests", dependencies: ["GojoCore"]),
    ]
)
