import SwiftUI
import GojoCore

struct SidebarView: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        List(selection: $state.selection) {
            Section("🌐 公共空间") {
                Label("公共空间", systemImage: "globe").tag(SidebarSelection.publicSpace)
                ForEach(state.publicRepos, id: \.self) { repo in
                    Text(repo.lastPathComponent).foregroundStyle(.secondary)
                }
            }
            Section("📁 编码空间") {
                ForEach(state.codingSpaces, id: \.self) { space in
                    DisclosureGroup {
                        ForEach(state.devProjects(in: space), id: \.self) { proj in
                            Text(proj.lastPathComponent)
                                .tag(SidebarSelection.devProject(space: space, project: proj))
                        }
                    } label: {
                        Text(space.lastPathComponent)
                            .tag(SidebarSelection.codingSpace(space))
                    }
                }
            }
        }
        .frame(minWidth: 220)
    }
}
