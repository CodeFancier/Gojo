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
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if state.publicSpaceEntries.isEmpty {
                    Text("公共空间还是空的，点右下角 + 添加，或直接拖入仓库文件夹")
                        .font(.callout)
                        .foregroundStyle(Color.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 32)
                }
                ForEach(state.publicSpaceEntries) { entry in
                    PublicSpaceEntryRow(
                        entry: entry,
                        project: state.publicProjects.first { $0.id == entry.publicProjectID },
                        isBusy: isBusy(entry),
                        onClone: { state.clonePublicProject($0) },
                        onDelete: { state.removePublicProject($0) },
                        onPromote: { state.promotePublicProject(relativePath: $0) }
                    )
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

    private func isBusy(_ entry: PublicSpaceEntry) -> Bool {
        guard let space = state.publicSpaceFolder,
              let project = state.publicProjects.first(where: { $0.id == entry.publicProjectID })
        else { return false }
        return state.isBusy(space: space, folder: project.name)
    }
}
