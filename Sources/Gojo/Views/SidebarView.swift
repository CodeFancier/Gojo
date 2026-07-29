import SwiftUI
import GojoCore

struct SidebarView: View {
    @EnvironmentObject var state: AppState

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
                    }
                }
            }
            .frame(minWidth: 240)
            HStack {
                Button("指定公共空间") { state.chooseAndSetPublicSpace() }
                Button("新建编码空间") { state.createCodingSpace() }
            }.padding(8)
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
