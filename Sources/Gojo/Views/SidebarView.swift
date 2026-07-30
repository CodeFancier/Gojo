import SwiftUI
import GojoCore
import UniformTypeIdentifiers

/// 成员拖拽 payload：三行文本，首行哨兵，避免与公共项目的裸 UUID 串混淆。
private enum DragPayload {
    static let memberPrefix = "gojo-member"

    static func member(space: URL, folder: String) -> String {
        "\(memberPrefix)\n\(space.path)\n\(folder)"
    }

    /// 解析成员 payload；非成员格式返回 nil。
    static func parseMember(_ s: String) -> (space: URL, folder: String)? {
        let parts = s.components(separatedBy: "\n")
        guard parts.count == 3, parts[0] == memberPrefix else { return nil }
        return (URL(fileURLWithPath: parts[1]), parts[2])
    }
}

struct SidebarView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showModePicker = false
    @State private var dropTargetSpace: URL?
    @State private var droppedProjectId: UUID?

    // 拖拽视觉态
    @State private var targetedSpace: URL?              // 光标当前悬停的空间
    @State private var draggingFromSpace: URL?          // 成员拖拽的源空间（用于抑制源高亮）

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $state.selection) {
                Section("🌐 公共空间") {
                    Label("公共空间", systemImage: "globe").tag(SidebarSelection.publicSpace)
                    ForEach(state.publicProjects) { proj in
                        HStack {
                            Image(systemName: proj.cloned ? "checkmark.circle.fill" : "circle.dashed")
                                .foregroundStyle(proj.cloned ? .green : .secondary)
                            Text(proj.name)
                        }
                        .foregroundStyle(.secondary)
                        .onDrag {
                            NSItemProvider(object: proj.id.uuidString as NSString)
                        }
                    }
                }
                Section("📁 编码空间") {
                    ForEach(state.codingSpaces, id: \.self) { space in
                        DisclosureGroup {
                            ForEach(state.members(in: space)) { member in
                                memberRow(member)
                                    .onDrag {
                                        draggingFromSpace = space
                                        return NSItemProvider(
                                            object: DragPayload.member(space: space,
                                                                       folder: member.folderName) as NSString)
                                    } preview: {
                                        DragChip(systemImage: icon(for: member.form),
                                                 title: member.folderName)
                                    }
                            }
                        } label: {
                            Text(space.lastPathComponent)
                                .tag(SidebarSelection.codingSpace(space))
                        }
                        .listRowBackground(dropHighlight(for: space))
                        .onDrop(of: [.text], isTargeted: Binding(
                            get: { targetedSpace == space },
                            set: { hovering in
                                targetedSpace = hovering ? space
                                    : (targetedSpace == space ? nil : targetedSpace)
                            })) { providers in
                            handleDrop(providers, into: space)
                        }
                    }
                }
            }
            .frame(minWidth: 240)
            HStack {
                Button("指定公共空间") { state.chooseAndSetPublicSpace() }
                Button("新建编码空间") { state.createCodingSpace() }
            }.padding(8)
        }
        .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.72),
                   value: targetedSpace)
        .confirmationDialog("选择加入模式", isPresented: $showModePicker) {
            Button("Git 模式") {
                if let s = dropTargetSpace, let id = droppedProjectId {
                    state.addPublicToSpace(s, projectId: id, mode: .git)
                }
            }
            Button("软链接模式") {
                if let s = dropTargetSpace, let id = droppedProjectId {
                    state.addPublicToSpace(s, projectId: id, mode: .symlink)
                }
            }
            Button("取消", role: .cancel) {}
        }
    }

    // MARK: - 行

    @ViewBuilder
    private func memberRow(_ member: ScannedMember) -> some View {
        HStack {
            Image(systemName: icon(for: member.form))
            Text(member.folderName)
            Spacer()
            if let b = member.branch {
                Text(b).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 拖放高亮

    /// 合法放置目标才发光：光标悬停其上，且不是成员拖拽的源空间。
    private func isDropTarget(_ space: URL) -> Bool {
        targetedSpace == space && draggingFromSpace != space
    }

    @ViewBuilder
    private func dropHighlight(for space: URL) -> some View {
        if isDropTarget(space) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.accentColor.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.accentColor.opacity(0.6), lineWidth: 1.5))
        } else {
            Color.clear
        }
    }

    // MARK: - 放置处理

    private func handleDrop(_ providers: [NSItemProvider], into space: URL) -> Bool {
        guard let p = providers.first else { return false }
        _ = p.loadObject(ofClass: NSString.self) { obj, _ in
            guard let s = obj as? String else { return }
            DispatchQueue.main.async {
                targetedSpace = nil
                if let move = DragPayload.parseMember(s) {
                    draggingFromSpace = nil
                    state.moveMember(move.folder, from: move.space, to: space)
                } else if let id = UUID(uuidString: s) {
                    dropTargetSpace = space
                    droppedProjectId = id
                    showModePicker = true
                }
            }
        }
        return true
    }

    private func icon(for form: MemberForm) -> String {
        switch form {
        case .standalone:     return "shippingbox"          // 📦 独立
        case .publicGit:      return "arrow.triangle.branch" // ⑂ Git
        case .publicSymlink:  return "link"                  // 🔗 软链接
        }
    }
}

/// 拖拽时跟随光标的浮起芯片：thinMaterial 胶囊 + 强调色发丝边框。
private struct DragChip: View {
    let systemImage: String
    let title: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(title).lineLimit(1)
        }
        .font(.callout.weight(.medium))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.thinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.accentColor.opacity(0.7), lineWidth: 1))
    }
}
