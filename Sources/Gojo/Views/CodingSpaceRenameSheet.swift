import SwiftUI
import GojoCore

/// 重命名编码空间窗：名称=文件夹名，改名即移动目录；检测到旧路径下关联的
/// Claude/Codex 记忆时提示一并转载。转载失败项留在窗内，可幂等重试。
struct CodingSpaceRenameSheet: View {
    @EnvironmentObject private var state: AppState

    private var session: CodingSpaceRenameSession? { state.codingSpaceRenameSession }

    private var sanitizedName: String {
        WorkspaceManager.sanitizedFolderName(session?.name ?? "")
    }

    private var canConfirm: Bool {
        guard let session, session.outcome == nil, !session.migrating else { return false }
        return !sanitizedName.isEmpty && sanitizedName != session.currentName
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("重命名编码空间").font(.title2.bold())
            if let session {
                Text("「\(session.currentName)」将改名为新文件夹名，空间位置与成员不变")
                    .font(.body)
                    .foregroundStyle(Color.textSecondary)
            }

            TextField("新名称", text: Binding(
                get: { session?.name ?? "" },
                set: { state.setCodingSpaceRenameName($0) }))
                .textFieldStyle(.roundedBorder)
                .disabled(session?.outcome != nil || session?.migrating == true)
                .onSubmit { if canConfirm { state.confirmCodingSpaceRename() } }

            migrationSection

            if let error = session?.errorMessage {
                Text(error).font(.callout).foregroundStyle(Color.warmAmber)
            }
            outcomeSection

            HStack {
                Spacer()
                Button(session?.outcome == nil ? "取消" : "关闭") {
                    state.dismissCodingSpaceRename()
                }
                .keyboardShortcut(.cancelAction)
                if session?.outcome == nil {
                    if session?.migrating == true {
                        ProgressView().controlSize(.small).padding(.horizontal, 8)
                    } else {
                        Button("重命名") { state.confirmCodingSpaceRename() }
                            .buttonStyle(.borderedProminent)
                            .keyboardShortcut(.defaultAction)
                            .disabled(!canConfirm)
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 460)
    }

    // MARK: 记忆转载提示

    @ViewBuilder private var migrationSection: some View {
        if let plan = session?.plan {
            if plan.hasAgentMemory {
                VStack(alignment: .leading, spacing: 8) {
                    Text("检测到旧路径下关联的助手记忆：")
                        .font(.callout.weight(.medium))
                    VStack(alignment: .leading, spacing: 5) {
                        if !plan.claude.isEmpty {
                            Label("Claude：\(plan.claude.memoryDocs) 篇记忆 · \(plan.claude.sessions) 个会话",
                                  systemImage: "brain.head.profile")
                                .foregroundStyle(Color.warmAmber)
                        }
                        if !plan.codex.isEmpty {
                            Label("Codex：\(plan.codex.sessions) 个会话",
                                  systemImage: "chevron.left.forwardslash.chevron.right")
                                .foregroundStyle(Color.lightBlue)
                        }
                    }
                    .font(.callout)
                    Toggle(isOn: Binding(
                        get: { session?.migrateMemory ?? true },
                        set: { state.setCodingSpaceRenameMigration($0) })) {
                        Text("一并转载到新路径（推荐）").font(.callout)
                    }
                    Text("不转载则记忆保留在原处，不再关联重命名后的空间")
                        .font(.caption)
                        .foregroundStyle(Color.textTertiary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.surface))
            } else {
                Text("未检测到旧路径下的 Claude / Codex 记忆")
                    .font(.caption)
                    .foregroundStyle(Color.textTertiary)
            }
        } else if session?.outcome == nil {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("正在检测关联记忆…")
                    .font(.caption)
                    .foregroundStyle(Color.textTertiary)
            }
        }
    }

    // MARK: 执行结果

    @ViewBuilder private var outcomeSection: some View {
        if let outcome = session?.outcome {
            if outcome.migrationFailures.isEmpty {
                Label("重命名完成，记忆已全部转载", systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(Color.lightBlue)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("重命名完成，\(outcome.migrationFailures.count) 项记忆转载失败：")
                        .font(.callout.weight(.medium))
                    ForEach(Array(outcome.migrationFailures.prefix(6))) { item in
                        Text("\(item.kind == .claude ? "Claude" : "Codex") · \(item.description) — \(item.error ?? "")")
                            .font(.caption)
                            .foregroundStyle(Color.warmAmber)
                            .lineLimit(2)
                    }
                    Button("重试转载") { state.retryCodingSpaceMemoryMigration() }
                        .controlSize(.small)
                        .disabled(session?.migrating == true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.surface))
            }
        }
    }
}
