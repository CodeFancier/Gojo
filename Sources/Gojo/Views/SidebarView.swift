import SwiftUI
import GojoCore
import UniformTypeIdentifiers

struct SidebarView: View {
    @EnvironmentObject var state: AppState

    @State private var showModePicker = false
    @State private var dropTargetSpace: URL?
    @State private var droppedProjectId: UUID?

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
                                HStack {
                                    Image(systemName: icon(for: member.form))
                                    Text(member.folderName)
                                    Spacer()
                                    if let b = member.branch {
                                        Text(b).font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        } label: {
                            Text(space.lastPathComponent)
                                .tag(SidebarSelection.codingSpace(space))
                        }
                        .onDrop(of: [.text], isTargeted: nil) { providers in
                            guard let p = providers.first else { return false }
                            _ = p.loadObject(ofClass: NSString.self) { obj, _ in
                                guard let s = obj as? String, let id = UUID(uuidString: s) else { return }
                                DispatchQueue.main.async {
                                    dropTargetSpace = space
                                    droppedProjectId = id
                                    showModePicker = true
                                }
                            }
                            return true
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

    private func icon(for form: MemberForm) -> String {
        switch form {
        case .standalone:     return "shippingbox"          // 📦 独立
        case .publicGit:      return "arrow.triangle.branch" // ⑂ Git
        case .publicSymlink:  return "link"                  // 🔗 软链接
        }
    }
}
