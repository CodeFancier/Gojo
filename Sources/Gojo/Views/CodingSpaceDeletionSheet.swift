import SwiftUI

struct CodingSpaceDeletionSheet: View {
    @EnvironmentObject private var state: AppState

    private var session: CodingSpaceDeletionSession? {
        state.codingSpaceDeletionSession
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let session {
                Text(title(for: session))
                    .font(.title2.bold())
                Text(message(for: session))
                    .font(.body)
                    .foregroundStyle(Color.textSecondary)

                List(session.tasks) { task in
                    CodingSpaceDeletionTaskRow(task: task)
                }
                .listStyle(.inset)

                controls(for: session)
            }
        }
        .padding(20)
        .frame(width: 500)
        .frame(minHeight: 420)
        .interactiveDismissDisabled(session?.phase == .deleting)
    }

    private func title(for session: CodingSpaceDeletionSession) -> String {
        switch session.phase {
        case .review: "删除“\(session.space.lastPathComponent)”？"
        case .deleting: "正在移到废纸篓"
        case .finished: session.hasFailures ? "部分任务未完成" : "已移到废纸篓"
        }
    }

    private func message(for session: CodingSpaceDeletionSession) -> String {
        switch session.phase {
        case .review:
            "将按列表顺序处理子项目，最后处理当前编码空间。移到废纸篓后仍可恢复。"
        case .deleting:
            "正在逐项处理，请不要关闭窗口。"
        case .finished:
            session.hasFailures
                ? "部分项目未能单独移动，可能已随当前空间一起进入废纸篓；请检查废纸篓。"
                : "所有文件夹均已安全移到废纸篓。"
        }
    }

    @ViewBuilder
    private func controls(for session: CodingSpaceDeletionSession) -> some View {
        switch session.phase {
        case .review:
            HStack {
                Button("取消", action: state.dismissCodingSpaceDeletion)
                Spacer()
                Button("只从当前 Gojo 删除", action: state.unregisterPreparedCodingSpace)
                Button("删除子项目和当前空间", role: .destructive,
                       action: state.trashPreparedCodingSpace)
                    .buttonStyle(.borderedProminent)
            }
        case .deleting:
            HStack {
                Spacer()
                ProgressView()
                    .controlSize(.small)
                Text("任务执行中")
                    .foregroundStyle(Color.textSecondary)
            }
        case .finished:
            HStack {
                Spacer()
                Button("完成", action: state.dismissCodingSpaceDeletion)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}
