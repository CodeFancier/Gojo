import SwiftUI
import GojoCore

struct PublicSpaceSummary: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let isConfigured: Bool
    let projects: [PublicProject]
    let onOpen: () -> Void

    private var clonedCount: Int { projects.lazy.filter(\.cloned).count }
    private var pendingCount: Int { projects.count - clonedCount }

    private var statusText: String {
        guard isConfigured else { return "尚未指定公共空间" }
        guard !projects.isEmpty else { return "暂无公共项目" }
        return "\(projects.count) 个公共项目"
    }

    private var detailText: String {
        guard isConfigured else { return "进入后选择公共文件夹" }
        guard !projects.isEmpty else { return "进入后添加共享项目" }
        return "\(clonedCount) 已克隆 · \(pendingCount) 待同步"
    }

    var body: some View {
        Button(action: onOpen) {
            summaryContent
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.chrome, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.cardStroke))
        .accessibilityLabel("公共空间，\(statusText)，\(detailText)")
        .accessibilityHint("打开公共空间")
    }

    @ViewBuilder
    private var summaryContent: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 10) {
                titleLabel
                statusBlock(lineLimit: 2)
                openLabel
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(spacing: 14) {
                titleLabel
                Divider()
                statusBlock(lineLimit: 1)
                Spacer(minLength: 12)
                openLabel
            }
        }
    }

    private var titleLabel: some View {
        Label("公共空间", systemImage: "globe")
            .font(.headline)
            .foregroundStyle(Color.textPrimary)
    }

    private func statusBlock(lineLimit: Int) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(statusText)
                .font(.subheadline)
                .lineLimit(lineLimit)
            Text(detailText)
                .font(.caption)
                .foregroundStyle(Color.textTertiary)
                .lineLimit(lineLimit)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var openLabel: some View {
        Label("打开公共空间", systemImage: "chevron.right")
            .font(.subheadline)
            .foregroundStyle(Color.textSecondary)
            .lineLimit(1)
    }
}
