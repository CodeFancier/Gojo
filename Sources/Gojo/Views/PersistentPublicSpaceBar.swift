import SwiftUI
import GojoCore

struct PersistentPublicSpaceBar: View {
    @EnvironmentObject private var state: AppState
    @State private var query = ""

    let mode: PublicSpaceBarMode
    let onOpen: () -> Void
    let onDragProject: (UUID) -> Void

    private var visibleProjects: [PublicProject] {
        PublicProjectSearch.filter(state.publicProjects, query: query)
    }

    private var clonedCount: Int { state.publicProjects.lazy.filter(\.cloned).count }
    private var pendingCount: Int { state.publicProjects.count - clonedCount }

    private var summaryStatusText: String {
        if state.publicSpaceFolder == nil {
            "尚未指定公共空间"
        } else if state.publicProjects.isEmpty {
            "暂无公共项目"
        } else {
            "\(state.publicProjects.count) 个公共项目"
        }
    }

    private var searchableStatusText: String {
        if state.publicSpaceFolder == nil {
            "未指定公共空间，请先进入公共空间设置"
        } else if state.publicProjects.isEmpty {
            "公共空间暂无项目"
        } else {
            "\(state.publicProjects.count) 个公共项目"
        }
    }

    private var detailText: String {
        if state.publicSpaceFolder == nil {
            "打开后可指定公共空间文件夹"
        } else if state.publicProjects.isEmpty {
            "打开公共空间添加共享项目"
        } else {
            "\(clonedCount) 已克隆 · \(pendingCount) 待同步"
        }
    }

    var body: some View {
        Group {
            switch mode {
            case .summary:
                Button(action: onOpen) {
                    summaryContent
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("公共空间，\(summaryStatusText)，\(detailText)")
                .accessibilityHint("打开公共空间")
            case .searchable:
                searchableContent
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.publicSurface)
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.publicStroke))
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .onChange(of: mode) { newMode in
            if newMode == .summary {
                query = ""
            }
        }
    }

    private var summaryContent: some View {
        VStack(alignment: .leading, spacing: 5) {
            title
            Text(summaryStatusText)
                .font(.body)
                .foregroundStyle(Color.textPrimary)
            Text(detailText)
                .font(.callout)
                .foregroundStyle(Color.textTertiary)
            Label("打开公共空间", systemImage: "chevron.right")
                .font(.callout.bold())
                .foregroundStyle(Color.publicTeal)
        }
    }

    private var searchableContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                title
                Text(searchableStatusText)
                    .font(.body)
                    .foregroundStyle(Color.textPrimary)
                Text(detailText)
                    .font(.callout)
                    .foregroundStyle(Color.textTertiary)
            }

            if state.publicSpaceFolder != nil {
                TextField("搜索公共项目", text: $query)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 34)
                    .background(Color.chrome, in: RoundedRectangle(cornerRadius: 9))
                    .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color.publicStroke))
                    .accessibilityLabel("搜索公共项目")

                if state.publicProjects.isEmpty {
                    EmptyView()
                } else if visibleProjects.isEmpty {
                    Text("没有匹配的公共项目")
                        .font(.callout)
                        .foregroundStyle(Color.textTertiary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(visibleProjects) { project in
                                projectCard(project)
                            }
                        }
                    }
                }
            }
        }
    }

    private var title: some View {
        Label("公共空间", systemImage: "globe")
            .font(.title3.bold())
            .foregroundStyle(Color.publicTeal)
    }

    private func projectCard(_ project: PublicProject) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SourceBadgeIcon(kind: .unjoinedPublic, size: 18)
            Text(project.name)
                .font(.body)
                .foregroundStyle(Color.textPrimary)
                .lineLimit(1)
            Text(project.url)
                .font(.caption)
                .foregroundStyle(Color.textMuted)
                .lineLimit(1)
        }
        .frame(minWidth: 140, alignment: .leading)
        .padding(12)
        .background(Color.chrome, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.publicStroke))
        .onDrag {
            onDragProject(project.id)
            return NSItemProvider(object: DragPayload.publicProject(project.id) as NSString)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(project.name)，\(project.url)")
        .accessibilityHint("拖动到 Git 克隆或软链接投放区")
    }
}
