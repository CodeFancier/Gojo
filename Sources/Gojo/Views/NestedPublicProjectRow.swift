import SwiftUI
import GojoCore

/// 复合目录直接子级的 Git 仓库行，可原位「转为公共仓库」。
struct NestedPublicProjectRow: View {
    let project: NestedPublicProject
    /// 传 relativePath（"\(parentRelativePath)/\(name)"，即 project.id）。
    let onPromote: (String) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "shippingbox")
                .foregroundStyle(Color.publicTeal)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.body)
                    .foregroundStyle(Color.textPrimary)
                if !project.url.isEmpty {
                    Text(project.url)
                        .font(.caption.monospaced())
                        .foregroundStyle(Color.textMuted)
                        .lineLimit(1)
                }
            }
            Spacer()
            if project.isPromoted {
                Label("已转为公共仓库", systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.green)
            } else {
                Button("转为公共仓库") { onPromote(project.id) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(10)
        .background(Color.chrome, in: RoundedRectangle(cornerRadius: 8))
    }
}
