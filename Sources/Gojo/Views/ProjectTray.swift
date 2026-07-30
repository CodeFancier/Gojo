import SwiftUI
import GojoCore

/// 编码空间底部的公共项目托盘。胶囊可拖起 → 触发双落区（Task 9）。
struct ProjectTray: View {
    @EnvironmentObject var state: AppState
    let space: URL
    /// 拖起某个公共项目时回传其 id，由领域展示双落区。
    var onDragProject: (UUID) -> Void = { _ in }

    var body: some View {
        HStack(spacing: 8) {
            Text("公共项目")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color(white: 0.5))
                .textCase(.uppercase)
                .padding(.trailing, 2)

            if state.publicSpaceFolder == nil {
                Text("未指定公共空间")
                    .font(.system(size: 11)).foregroundStyle(Color(white: 0.45))
            } else if state.publicProjects.isEmpty {
                Text("公共空间暂无项目")
                    .font(.system(size: 11)).foregroundStyle(Color(white: 0.45))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(state.publicProjects) { proj in
                            pill(proj)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
        }
    }

    private func pill(_ proj: PublicProject) -> some View {
        HStack(spacing: 5) {
            SourceBadgeIcon(kind: .unjoinedPublic, size: 14)
            Text(proj.name)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(Color(white: 0.85))
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Color.coreBlue.opacity(0.14), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.lightBlue.opacity(0.42), lineWidth: 1))
        .onDrag {
            onDragProject(proj.id)
            return NSItemProvider(object: DragPayload.publicProject(proj.id) as NSString)
        }
    }
}
