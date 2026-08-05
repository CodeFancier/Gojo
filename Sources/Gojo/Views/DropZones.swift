import SwiftUI
import AppKit
import GojoCore

/// 拖起托盘胶囊时浮出的双落区：落 Git 区即克隆，落软链接区即建链。
/// 软链接区在项目未克隆时置灰。NSEvent 监听 leftMouseUp 兜底：
/// 拖到窗外或 Esc 取消不会触发任何区的 onDrop，靠松手事件收起落区。
struct DropZones: View {
    @EnvironmentObject var state: AppState
    let draggingProjectId: UUID
    let onDrop: (UUID, MemberMode) -> Void
    let onDismiss: () -> Void

    @State private var monitor: Any?
    @State private var hotZone: MemberMode?

    private var projectCloned: Bool {
        state.publicProjects.first { $0.id == draggingProjectId }?.cloned ?? false
    }

    var body: some View {
        HStack(spacing: 14) {
            zone(mode: .git, symbol: "arrow.triangle.branch", title: "Git 克隆",
                 desc: "独立 .git，可单独切分支改代码",
                 tint: .coreBlue, enabled: true)
            zone(mode: .symlink, symbol: "link", title: "软链接",
                 desc: projectCloned ? "指向公共空间，引用不占空间" : "需先在公共空间 Clone",
                 tint: .lightBlue, enabled: projectCloned)
        }
        .padding(20)
        .transition(.opacity)
        .onAppear {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { event in
                DispatchQueue.main.async { onDismiss() }
                return event
            }
        }
        .onDisappear {
            if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
        }
    }

    private func zone(mode: MemberMode, symbol: String, title: String, desc: String,
                      tint: Color, enabled: Bool) -> some View {
        let hot = hotZone == mode
        return VStack(spacing: 8) {
            Image(systemName: symbol).font(.system(size: 26)).foregroundStyle(tint)
            Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
            Text(desc).font(.system(size: 11)).foregroundStyle(Color.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 150)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(tint.opacity(hot ? 0.26 : 0.10)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
            .foregroundStyle(tint.opacity(0.6)))
        .scaleEffect(hot ? 1.015 : 1)
        .grayscale(enabled ? 0 : 1)
        .opacity(enabled ? 1 : 0.5)
        .allowsHitTesting(enabled)
        .animation(Motion.dropZone, value: hot)
        .onDrop(of: [.text], isTargeted: Binding(
            get: { hotZone == mode },
            set: { hovering in hotZone = hovering ? mode : (hotZone == mode ? nil : hotZone) })) { providers in
            handleDrop(providers, mode: mode)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider], mode: MemberMode) -> Bool {
        guard let p = providers.first else { return false }
        _ = p.loadObject(ofClass: NSString.self) { obj, _ in
            guard let s = obj as? String, let id = DragPayload.parsePublicProject(s) else { return }
            DispatchQueue.main.async {
                hotZone = nil
                onDrop(id, mode)
            }
        }
        return true
    }
}
