import SwiftUI
import GojoCore

/// 新建编码空间命名窗：输入名称后自动在根目录下创建同名文件夹（重名自动 _2/_3）。
struct CodingSpaceNamingSheet: View {
    @EnvironmentObject private var state: AppState

    private var session: CodingSpaceNamingSession? { state.codingSpaceNamingSession }

    /// 清洗后为空（纯空白/纯点号等）时禁用创建。
    private var sanitizedName: String {
        WorkspaceManager.sanitizedFolderName(session?.name ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("新建编码空间")
                .font(.title2.bold())
            Text("将在根目录下创建同名文件夹；重名会自动加 _2、_3 后缀")
                .font(.body)
                .foregroundStyle(Color.textSecondary)
            if let root = state.codingSpaceRoot {
                Text(root.path)
                    .font(.caption)
                    .foregroundStyle(Color.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            TextField("编码空间名称", text: Binding(
                get: { session?.name ?? "" },
                set: { state.setCodingSpaceName($0) }))
                .textFieldStyle(.roundedBorder)
                .onSubmit { confirmIfValid() }
            HStack {
                Spacer()
                Button("取消") { state.dismissCodingSpaceNaming() }
                    .keyboardShortcut(.cancelAction)
                Button("创建") { state.confirmCodingSpaceCreation() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(sanitizedName.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private func confirmIfValid() {
        if !sanitizedName.isEmpty { state.confirmCodingSpaceCreation() }
    }
}
