import SwiftUI

struct CodingSpaceDeletionTaskRow: View {
    let task: CodingSpaceDeletionTask

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: task.item.isRoot ? "shippingbox.fill" : "folder.fill")
                .foregroundStyle(task.item.isRoot ? Color.lightBlue : Color.textSecondary)
                .frame(width: 20)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(task.item.name)
                    .font(.body)
                Text(task.item.isRoot ? "当前编码空间" : "子项目文件夹")
                    .font(.caption)
                    .foregroundStyle(Color.textTertiary)
            }
            Spacer()
            statusView
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var statusView: some View {
        switch task.status {
        case .pending:
            Text("等待")
                .foregroundStyle(Color.textTertiary)
        case .running:
            ProgressView()
                .controlSize(.small)
                .accessibilityLabel("正在移到废纸篓")
        case .completed:
            Label("完成", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed(let message):
            Label("失败", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .help(message)
        }
    }
}
