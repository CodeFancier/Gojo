import SwiftUI
import GojoCore

/// 公共空间领域：未指定时显空态引导；已指定时列出项目（Clone / 已克隆）并可新增。
struct PublicSpaceDomain: View {
    @EnvironmentObject var state: AppState

    @State private var showAdd = false
    @State private var newName = ""
    @State private var newURL = ""

    var body: some View {
        VStack(spacing: 0) {
            DomainTopBar(title: "公共空间")
            if state.publicSpaceFolder == nil {
                emptyState
            } else {
                projectList
            }
        }
        .background(DomainBackground())
        .alert("新增公共项目", isPresented: $showAdd) {
            TextField("名称", text: $newName)
            TextField("Git URL", text: $newURL)
            Button("添加") {
                state.addPublicProject(name: newName, url: newURL)
                newName = ""; newURL = ""
            }
            Button("取消", role: .cancel) {}
        } message: { Text("只登记定义，点 Clone 才同步下来") }
    }

    // MARK: 空态

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "globe").font(.system(size: 44)).foregroundStyle(Color.lightBlue)
            Text("还没有指定公共空间").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
            Text("公共空间是所有共享仓库的家，指定一个文件夹开始")
                .font(.system(size: 12)).foregroundStyle(Color.textTertiary)
            Button("指定公共空间文件夹") { state.chooseAndSetPublicSpace() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: 项目列表

    private var projectList: some View {
        let standaloneCompositeFolders = state.compositePublicFolders.filter { !$0.isPublicProject }
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if !standaloneCompositeFolders.isEmpty {
                    Text("复合文件夹")
                        .font(.headline)
                        .foregroundStyle(Color.textSecondary)
                    ForEach(standaloneCompositeFolders) { folder in
                        CompositePublicFolderRow(folder: folder) { project in
                            state.promoteNestedPublicProject(project)
                        }
                    }
                }

                if !state.publicProjects.isEmpty {
                    Text("公共仓库")
                        .font(.headline)
                        .foregroundStyle(Color.textSecondary)
                        .padding(.top, standaloneCompositeFolders.isEmpty ? 0 : 8)
                    ForEach(state.publicProjects) { proj in
                        ExpandablePublicProjectRow(
                            project: proj,
                            childProjects: childProjects(of: proj),
                            isBusy: isBusy(proj),
                            onClone: { state.clonePublicProject(proj.id) },
                            onDelete: { state.removePublicProject(proj.id) },
                            onPromote: { state.promoteNestedPublicProject($0) }
                        )
                    }
                }
            }
            .padding(16)
        }
        .overlay(alignment: .bottomTrailing) {
            Button { showAdd = true } label: {
                Image(systemName: "plus").font(.system(size: 16, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.borderedProminent).clipShape(Circle())
            .padding(20)
        }
    }

    private func childProjects(of project: PublicProject) -> [NestedPublicProject] {
        state.compositePublicFolders
            .first(where: { $0.publicProjectID == project.id })?
            .projects ?? []
    }

    private func isBusy(_ project: PublicProject) -> Bool {
        state.publicSpaceFolder.map {
            state.isBusy(space: $0, folder: project.name)
        } ?? false
    }
}
