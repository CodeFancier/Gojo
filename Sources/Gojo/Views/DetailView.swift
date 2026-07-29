import SwiftUI
import GojoCore

struct DetailView: View {
    @EnvironmentObject var state: AppState

    // 新增公共项目
    @State private var showAddProject = false
    @State private var newName = ""
    @State private var newURL = ""

    // 切分支
    @State private var branchTarget: String?
    @State private var branchOptions: [String] = []

    // Git→软链接破坏性确认
    @State private var confirmSymlinkFolder: String?

    var body: some View {
        switch state.selection {
        case .publicSpace, .none:
            publicSpaceView
        case .codingSpace(let space):
            codingSpaceView(space)
        }
    }

    // MARK: 公共空间详情
    private var publicSpaceView: some View {
        List {
            ForEach(state.publicProjects) { proj in
                HStack {
                    VStack(alignment: .leading) {
                        Text(proj.name)
                        Text(proj.url).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if proj.cloned {
                        Label("已克隆", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green).labelStyle(.iconOnly)
                    } else {
                        Button("Clone") { state.clonePublicProject(proj.id) }
                    }
                }
            }
        }
        .navigationTitle("公共空间")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showAddProject = true } label: { Image(systemName: "plus") }
            }
        }
        .alert("新增公共项目", isPresented: $showAddProject) {
            TextField("名称", text: $newName)
            TextField("Git URL", text: $newURL)
            Button("添加") {
                state.addPublicProject(name: newName, url: newURL)
                newName = ""; newURL = ""
            }
            Button("取消", role: .cancel) {}
        } message: { Text("只登记定义，点 Clone 才同步下来") }
    }

    // MARK: 编码空间详情
    private func codingSpaceView(_ space: URL) -> some View {
        List {
            Section("成员仓库") {
                ForEach(state.members(in: space)) { member in
                    memberRow(space, member)
                }
            }
        }
        .navigationTitle(space.lastPathComponent)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    ForEach(state.publicProjects) { proj in
                        Menu(proj.name) {
                            Button("Git 模式") {
                                state.addPublicToSpace(space, projectId: proj.id, mode: .git)
                            }
                            Button("软链接模式") {
                                state.addPublicToSpace(space, projectId: proj.id, mode: .symlink)
                            }
                        }
                    }
                } label: { Image(systemName: "plus") }
            }
        }
        .confirmationDialog("选择分支", isPresented: Binding(
            get: { branchTarget != nil },
            set: { if !$0 { branchTarget = nil } }), presenting: branchOptions) { branches in
            ForEach(branches, id: \.self) { b in
                Button(b) {
                    if let f = branchTarget { state.setBranch(space, folderName: f, branch: b) }
                    branchTarget = nil
                }
            }
        }
        .alert("切回软链接会丢失本地改动", isPresented: Binding(
            get: { confirmSymlinkFolder != nil },
            set: { if !$0 { confirmSymlinkFolder = nil } })) {
            Button("仍然切换", role: .destructive) {
                if let f = confirmSymlinkFolder { state.switchToSymlink(space, folderName: f) }
                confirmSymlinkFolder = nil
            }
            Button("取消", role: .cancel) { confirmSymlinkFolder = nil }
        } message: { Text("该成员的本地 clone 有未提交或未推送的改动，切回软链接将删除它们。") }
    }

    @ViewBuilder
    private func memberRow(_ space: URL, _ member: ScannedMember) -> some View {
        HStack {
            Image(systemName: icon(for: member.form))
            Text(member.folderName)
            Spacer()
            if let b = member.branch {
                Text(b).font(.caption).foregroundStyle(.secondary)
            }
            // git 成员：同步 + 切分支
            if isGit(member.form) {
                Button("同步") { state.syncMember(space, folderName: member.folderName) }
                Button("分支") {
                    branchTarget = member.folderName
                    branchOptions = state.branches(space, folderName: member.folderName)
                }
            }
            // 模式切换（仅公共项目成员）
            switch member.form {
            case .publicSymlink:
                Button("转 Git") { state.switchToGit(space, folderName: member.folderName) }
            case .publicGit:
                Button("转软链接") {
                    if state.memberHasLocalChanges(space, folderName: member.folderName) {
                        confirmSymlinkFolder = member.folderName
                    } else {
                        state.switchToSymlink(space, folderName: member.folderName)
                    }
                }
            case .standalone:
                EmptyView()
            }
        }
    }

    private func isGit(_ form: MemberForm) -> Bool {
        switch form {
        case .standalone, .publicGit: return true
        case .publicSymlink: return false
        }
    }

    private func icon(for form: MemberForm) -> String {
        switch form {
        case .standalone:    return "shippingbox"
        case .publicGit:     return "arrow.triangle.branch"
        case .publicSymlink: return "link"
        }
    }
}
