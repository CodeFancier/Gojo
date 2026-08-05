import SwiftUI
import GojoCore

struct NestedPublicProjectRow: View {
    let project: NestedPublicProject
    let onPromote: (NestedPublicProject) -> Void

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
                Label("已转为公共项目", systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.green)
            } else {
                Button("转为公共项目") { onPromote(project) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(10)
        .background(Color.chrome, in: RoundedRectangle(cornerRadius: 8))
    }
}
