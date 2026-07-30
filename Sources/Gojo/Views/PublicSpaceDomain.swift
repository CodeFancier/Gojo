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
                .font(.system(size: 12)).foregroundStyle(Color(white: 0.55))
            Button("指定公共空间文件夹") { state.chooseAndSetPublicSpace() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: 项目列表

    private var projectList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(state.publicProjects) { proj in
                    row(proj)
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

    private func row(_ proj: PublicProject) -> some View {
        let busy = state.publicSpaceFolder.map { state.isBusy(space: $0, folder: proj.name) } ?? false
        return HStack(spacing: 12) {
            SourceBadgeIcon(kind: .unjoinedPublic, size: 20, badgeBackground: Color(white: 0.14))
            VStack(alignment: .leading, spacing: 2) {
                Text(proj.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                Text(proj.url).font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(Color(white: 0.5)).lineLimit(1)
            }
            Spacer()
            if busy {
                ProgressView().controlSize(.small)
            } else if proj.cloned {
                Label("已克隆", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11)).foregroundStyle(.green).labelStyle(.iconOnly)
            } else {
                Button("Clone") { state.clonePublicProject(proj.id) }
                    .buttonStyle(.bordered).controlSize(.small)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.white.opacity(0.05)))
    }
}
