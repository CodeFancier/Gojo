import SwiftUI

struct DeletionActionBar: View {
    let onDelete: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(role: .destructive, action: onDelete) {
                Label("删除", systemImage: "trash.fill")
                    .frame(minHeight: 28)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)

            Button(action: onCancel) {
                Label("取消", systemImage: "xmark")
                    .frame(minHeight: 28)
            }
            .buttonStyle(.bordered)
        }
        .controlSize(.small)
        .padding(8)
        .background(Color.chrome.opacity(0.98), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.red.opacity(0.5)))
        .shadow(color: .black.opacity(0.28), radius: 8, y: 3)
    }
}
