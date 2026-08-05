import SwiftUI
import GojoCore

struct CompositePublicFolderRow: View {
    let folder: PublicCompositeFolder
    let onPromote: (NestedPublicProject) -> Void

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(spacing: 8) {
                ForEach(folder.projects) { project in
                    NestedPublicProjectRow(project: project, onPromote: onPromote)
                }
            }
            .padding(.top, 8)
            .padding(.leading, 24)
        } label: {
            HStack {
                Label(folder.name, systemImage: "folder.fill")
                    .font(.body.bold())
                    .foregroundStyle(Color.textPrimary)
                Spacer()
                Text("\(folder.projects.count) 个子项目")
                    .font(.callout)
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .padding(12)
        .background(Color.surface, in: RoundedRectangle(cornerRadius: 10))
        .accessibilityHint(isExpanded ? "收起子项目" : "展开子项目")
    }
}
