// swift-tools-version:5.9
import PackageDescription

// Gojo（SwiftUI/AppKit）只在 macOS 构建；Linux 上仅验证 GojoCore。
#if os(macOS)
let appTargets: [Target] = [
    .executableTarget(
        name: "Gojo",
        dependencies: ["GojoCore"],
        // Info.plist / Gojo.icns 仅供打包脚本使用，排除出运行时资源 bundle。
        exclude: ["Resources/Info.plist", "Resources/Gojo.icns"],
        resources: [
            .process("Resources/gojo-wordmark.png"),
        ]
    ),
    .testTarget(name: "GojoTests", dependencies: ["Gojo"]),
]
#else
let appTargets: [Target] = []
#endif

let package = Package(
    name: "Gojo",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "GojoCore"),
    ] + appTargets + [
        .testTarget(name: "GojoCoreTests", dependencies: ["GojoCore"]),
    ]
)
