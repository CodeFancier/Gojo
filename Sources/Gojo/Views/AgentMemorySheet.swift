import SwiftUI
import GojoCore

/// 助手记忆大窗：Claude 左记忆右会话，Codex 只会话。点会话即在终端 resume。
struct AgentMemorySheet: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss

    let projectURL: URL
    let displayName: String
    let kind: AgentKind

    @State private var snapshot: AgentMemorySnapshot?
    @State private var selectedDoc: MemoryDoc?

    private var accent: Color { kind == .claude ? Color.warmAmber : Color.lightBlue }
    private var title: String { kind == .claude ? "Claude 记忆" : "Codex 会话" }
    private var symbol: String { kind == .claude ? "brain.head.profile" : "chevron.left.forwardslash.chevron.right" }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Color.hairline)
            content
        }
        .frame(minWidth: 720, idealWidth: 860, minHeight: 460, idealHeight: 560)
        .background(Color.chrome)
        .onAppear(perform: load)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 15, weight: .semibold))
                .foregroundStyle(accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                Text(displayName).font(.system(size: 11)).foregroundStyle(Color.textTertiary)
            }
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.borderless).keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    @ViewBuilder private var content: some View {
        if let snap = snapshot {
            if !snap.available {
                empty("在这个项目里还没用过 \(kind == .claude ? "Claude" : "Codex")")
            } else if kind == .claude {
                HStack(spacing: 0) {
                    memoryPane(snap.memoryDocs)
                    Divider().overlay(Color.hairline)
                    sessionPane(snap.sessions).frame(width: 320)
                }
            } else {
                sessionPane(snap.sessions)
            }
        } else {
            VStack { ProgressView().controlSize(.small) }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: 记忆栏（Claude）

    private func memoryPane(_ docs: [MemoryDoc]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            paneTitle("项目记忆")
            if docs.isEmpty {
                empty("没有 memory 文件")
            } else {
                HStack(spacing: 0) {
                    // 文件名列表
                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(docs) { doc in
                                docRow(doc)
                            }
                        }
                        .padding(8)
                    }
                    .frame(width: 180)
                    Divider().overlay(Color.hairline)
                    // 选中文档全文
                    ScrollView {
                        Text((selectedDoc ?? docs.first)?.content ?? "")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Color.textSecondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func docRow(_ doc: MemoryDoc) -> some View {
        let active = (selectedDoc ?? snapshot?.memoryDocs.first)?.id == doc.id
        return Button { selectedDoc = doc } label: {
            HStack(spacing: 6) {
                Image(systemName: "doc.text").font(.system(size: 10))
                Text(doc.name).font(.system(size: 11.5)).lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(active ? .white : Color.textTertiary)
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 6)
                .fill(active ? accent.opacity(0.18) : .clear))
        }
        .buttonStyle(.plain)
    }

    // MARK: 会话栏

    private func sessionPane(_ sessions: [AgentSession]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            paneTitle("最近会话")
            if sessions.isEmpty {
                empty("没有历史会话")
            } else {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(sessions) { s in sessionRow(s) }
                    }
                    .padding(8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func sessionRow(_ s: AgentSession) -> some View {
        Button {
            state.resumeSession(projectURL: projectURL, kind: kind, sessionId: s.id)
            dismiss()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.forward.app").font(.system(size: 11))
                    .foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.title).font(.system(size: 12)).foregroundStyle(.white)
                        .lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                    Text(Self.relative(s.modifiedAt)).font(.system(size: 10))
                        .foregroundStyle(Color.textMuted)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.surface))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.cardStroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help("在终端里 resume 这个会话")
    }

    // MARK: 小工具

    private func paneTitle(_ t: String) -> some View {
        Text(t).font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 6)
    }

    private func empty(_ t: String) -> some View {
        Text(t).font(.system(size: 12)).foregroundStyle(Color.textMuted)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func load() {
        state.loadAgentMemory(projectURL: projectURL, kind: kind) { snap in
            snapshot = snap
            selectedDoc = snap.memoryDocs.first
        }
    }

    private static func relative(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    }
}

/// Claude / Codex 记忆入口按钮组：自带 sheet，成员卡与编码空间顶栏共用。
/// projectURL 传成员目录或编码空间根目录均可。
struct AgentMemoryButtons: View {
    @EnvironmentObject var state: AppState
    let projectURL: URL
    let displayName: String
    /// 顶栏用带文字的胶囊，卡片用紧凑圆点。
    var compact: Bool = true

    @State private var memoryKind: AgentKind?

    var body: some View {
        HStack(spacing: compact ? 6 : 8) {
            button(.claude, "brain.head.profile", Color.warmAmber, "Claude 记忆")
            button(.codex, "chevron.left.forwardslash.chevron.right", Color.lightBlue, "Codex 会话")
        }
        .sheet(item: $memoryKind) { kind in
            AgentMemorySheet(projectURL: projectURL, displayName: displayName, kind: kind)
                .environmentObject(state)
        }
    }

    @ViewBuilder private func button(_ kind: AgentKind, _ symbol: String,
                                     _ tint: Color, _ help: String) -> some View {
        Button { memoryKind = kind } label: {
            if compact {
                Image(systemName: symbol).font(.system(size: 11, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(tint.opacity(0.14)))
            } else {
                HStack(spacing: 5) {
                    Image(systemName: symbol).font(.system(size: 11, weight: .medium))
                    Text(kind == .claude ? "Claude" : "Codex").font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(tint)
                .padding(.horizontal, 9).padding(.vertical, 5)
                .background(Capsule().fill(tint.opacity(0.14)))
            }
        }
        .buttonStyle(.borderless).help(help)
    }
}
