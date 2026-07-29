import SwiftUI
import GojoCore

struct DetailView: View {
    @EnvironmentObject var state: AppState
    @State private var showClone = false
    @State private var cloneURL = ""
    @State private var cloneSubdir = ""
    @State private var showAddSymlink = false
    @State private var symlinkPublicRepo = ""
    @State private var symlinkLinkName = ""
    @State private var showCreateProject = false
    @State private var newProjectName = ""

    var body: some View {
        switch state.selection {
        case .publicSpace, .none:
            List(state.publicRepos, id: \.self) { Text($0.lastPathComponent) }
                .navigationTitle("公共空间")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("克隆仓库") { showClone = true }
                    }
                }
                .alert("克隆 Git 仓库", isPresented: $showClone) {
                    TextField("Git URL", text: $cloneURL)
                    Button("克隆") {
                        state.addPublicRepo(url: cloneURL)
                        cloneURL = ""
                    }
                    Button("取消", role: .cancel) {}
                }
        case .codingSpace(let space):
            List(state.devProjects(in: space), id: \.self) { Text($0.lastPathComponent) }
                .navigationTitle(space.lastPathComponent)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button("新建开发项目") { showCreateProject = true }
                            Button("指认已存在") { state.adoptExistingProject(in: space) }
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .alert("新建开发项目", isPresented: $showCreateProject) {
                    TextField("项目名称", text: $newProjectName)
                    Button("创建") {
                        state.createDevProject(named: newProjectName, in: space)
                        newProjectName = ""
                    }
                    Button("取消", role: .cancel) {}
                }
        case .devProject(_, let project):
            let m = state.projectManifest(at: project)
            List {
                Section("Git 仓库") {
                    ForEach(m?.repos ?? []) { repo in
                        HStack {
                            Text(repo.subdirectory)
                            Spacer()
                            Text(repo.branch ?? "-").foregroundStyle(.secondary)
                            Button("同步") {
                                state.syncRepo(project, subdir: repo.subdirectory)
                            }
                        }
                    }
                }
                Section("软链接") {
                    ForEach(m?.symlinks ?? []) { link in
                        Text("\(link.linkPath) → \(link.publicRepoName)")
                    }
                }
            }
            .navigationTitle(project.lastPathComponent)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("克隆仓库") { showClone = true }
                        Button("软链接公共库") { showAddSymlink = true }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("克隆 Git 仓库", isPresented: $showClone) {
                TextField("Git URL", text: $cloneURL)
                TextField("子目录名", text: $cloneSubdir)
                Button("克隆") {
                    if case .devProject(_, let project) = state.selection {
                        state.addRepoToProject(project, url: cloneURL, subdir: cloneSubdir)
                    }
                    cloneURL = ""
                    cloneSubdir = ""
                }
                Button("取消", role: .cancel) {}
            }
            .alert("软链接公共库", isPresented: $showAddSymlink) {
                TextField("公共库名", text: $symlinkPublicRepo)
                TextField("链接名", text: $symlinkLinkName)
                Button("创建") {
                    if case .devProject(_, let project) = state.selection {
                        state.addSymlinkToProject(project, publicRepo: symlinkPublicRepo, linkName: symlinkLinkName)
                    }
                    symlinkPublicRepo = ""
                    symlinkLinkName = ""
                }
                Button("取消", role: .cancel) {}
            }
        }
    }
}

