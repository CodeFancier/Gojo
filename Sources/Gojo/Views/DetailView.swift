import SwiftUI
import GojoCore

struct DetailView: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        switch state.selection {
        case .publicSpace, .none:
            List(state.publicRepos, id: \.self) { Text($0.lastPathComponent) }
                .navigationTitle("公共空间")
        case .codingSpace(let space):
            List(state.devProjects(in: space), id: \.self) { Text($0.lastPathComponent) }
                .navigationTitle(space.lastPathComponent)
        case .devProject(_, let project):
            let m = state.projectManifest(at: project)
            List {
                Section("Git 仓库") {
                    ForEach(m?.repos ?? []) { repo in
                        HStack { Text(repo.subdirectory); Spacer()
                            Text(repo.branch ?? "-").foregroundStyle(.secondary) }
                    }
                }
                Section("软链接") {
                    ForEach(m?.symlinks ?? []) { link in
                        Text("\(link.linkPath) → \(link.publicRepoName)")
                    }
                }
            }.navigationTitle(project.lastPathComponent)
        }
    }
}
