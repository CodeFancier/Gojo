import SwiftUI
import AppKit
import GojoCore

/// 顶栏「终端」按钮：单击 = 用已固定终端直接打开当前空间；
/// 长按（0.4s）= 弹出转轮 popover，拨选终端后「固定并打开」。
///
/// 不用 Button：Button 会吞手势事件（参见 HoldToDeleteModifier 的经验），
/// tap / longPress 两个手势同属 SwiftUI 手势系统，由它仲裁互斥——
/// 快抬 tap 胜出，按满 0.4s 长按胜出、tap 自动判负。
struct TerminalPickerButton: View {
    @EnvironmentObject var state: AppState
    /// 已安装的终端集合；默认全部可选，探测完成后把未安装的置灰。
    @State private var installedTerminals: Set<TerminalApp> = Set(TerminalApp.allCases)
    @State private var showingWheel = false
    /// 转轮选中项：@State 跨 popover 呈现存活，每次弹出前必须重置为当前偏好。
    @State private var wheelSelection: TerminalApp = .terminal
    /// 长按已触发标志：吞掉长按后可能残留的 tap，避免「弹转轮 + 直接打开」双动作。
    @State private var longPressConsumed = false
    @State private var hovering = false

    var body: some View {
        label
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 7)
                .fill(hovering ? Color.surface : Color.clear))
            .contentShape(Rectangle())
            .onTapGesture {
                guard !longPressConsumed else { return }
                state.openInTerminal()
            }
            .onLongPressGesture(minimumDuration: 0.4, maximumDistance: 40) {
                longPressConsumed = true
                wheelSelection = state.terminalPreference
                showingWheel = true
            } onPressingChanged: { pressing in
                if pressing { hovering = true }
            }
            .onHover { hovering = $0 }
            .popover(isPresented: $showingWheel, arrowEdge: .bottom,
                     onDismiss: { longPressConsumed = false }) {
                TerminalWheelPopover(installed: installedTerminals,
                                     selection: $wheelSelection) { term in
                    state.terminalPreference = term
                    showingWheel = false
                    state.openInTerminal()
                } onCancel: {
                    showingWheel = false
                }
                // popover 是独立呈现，不继承 ContentView 的深色外观与 tint，显式补上。
                .preferredColorScheme(.dark)
                .tint(.lightBlue)
            }
            .task { installedTerminals = Self.detectInstalledTerminals() }
            .help("单击：用固定终端打开当前空间；长按：选择并固定终端")
            .accessibilityLabel("终端")
            .accessibilityHint("单击用固定终端打开；长按选择终端")
    }

    /// 视觉对齐相邻「访达」按钮的 Label。
    private var label: some View {
        Label("终端", systemImage: "terminal")
    }

    /// 用 LaunchServices 按候选 bundle id 探测本机装了哪些终端。
    static func detectInstalledTerminals() -> Set<TerminalApp> {
        var installed = Set<TerminalApp>()
        for term in TerminalApp.allCases {
            if term.bundleIDs.contains(where: {
                NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil
            }) {
                installed.insert(term)
            }
        }
        return installed
    }
}

/// 转轮选终端。未安装项：置灰 + 「未安装」后缀，且拨到该项时「固定并打开」禁用
/// （wheel 样式对行级 disabled 的渲染不可靠，用行为约束代替）。
struct TerminalWheelPopover: View {
    let installed: Set<TerminalApp>
    @Binding var selection: TerminalApp
    let onConfirm: (TerminalApp) -> Void
    let onCancel: () -> Void

    private var selectedInstalled: Bool { installed.contains(selection) }

    var body: some View {
        VStack(spacing: 12) {
            Text("选择终端")
                .font(.headline)
            Picker("终端", selection: $selection) {
                ForEach(TerminalApp.allCases, id: \.self) { term in
                    let isInstalled = installed.contains(term)
                    Text(isInstalled ? term.displayName : "\(term.displayName)（未安装）")
                        .foregroundColor(isInstalled ? Color.textPrimary : Color.textMuted)
                        .tag(term)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            // macOS 上转轮不给定 frame 会塌陷成 0 高。
            .frame(width: 220, height: 132)

            if !selectedInstalled {
                Text("\(selection.displayName) 未安装，无法固定")
                    .font(.caption)
                    .foregroundStyle(Color.textTertiary)
            }

            HStack {
                Button("取消", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("固定并打开") { onConfirm(selection) }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!selectedInstalled)
            }
        }
        .padding(16)
        .frame(width: 280)
    }
}
