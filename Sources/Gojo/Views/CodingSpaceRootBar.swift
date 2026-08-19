import SwiftUI
import GojoCore

/// 首页根目录条：已设置时显示缩略路径 + 操作菜单（更改/访达/清除）；
/// 未设置时显示设置入口。常驻显示，高度恒定避免布局跳动。
struct CodingSpaceRootBar: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "externaldrive.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.lightBlue)
            if let root = state.codingSpaceRoot {
                Text("根目录")
                    .font(.caption)
                    .foregroundStyle(Color.textTertiary)
                Menu {
                    Button("更改根目录…") { state.chooseAndSetCodingSpaceRoot() }
                    Button("在访达中打开") { state.openCodingSpaceRootInFinder() }
                    Divider()
                    Button("清除根目录", role: .destructive) { state.clearCodingSpaceRoot() }
                } label: {
                    HStack(spacing: 4) {
                        Text(abbreviatedPath(root))
                            .font(.callout)
                            .foregroundStyle(Color.textSecondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(Color.textTertiary)
                    }
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            } else {
                Button("设置编码空间根目录") { state.chooseAndSetCodingSpaceRoot() }
                    .buttonStyle(.plain)
                    .font(.callout)
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.cardStroke))
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(state.codingSpaceRoot == nil
            ? "设置编码空间根目录"
            : "编码空间根目录，\(state.codingSpaceRoot?.path ?? "")")
    }

    /// home 前缀缩略为 ~，长路径保持原样交给 truncationMode(.middle)。
    private func abbreviatedPath(_ url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = url.path
        if path == home { return "~" }
        if path.hasPrefix(home + "/") { return "~" + path.dropFirst(home.count) }
        return path
    }
}
