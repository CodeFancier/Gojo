import SwiftUI
import AppKit
import GojoCore

/// 顶栏「终端」按钮：单击 = 用已固定终端直接打开当前空间；
/// 长按（0.4s）= 弹出转轮 popover，拨选终端后「固定并打开」；
/// 右键 = 菜单快捷切换（长按在部分环境可能不识别，右键兜底）。
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
            .contextMenu {
                ForEach(TerminalApp.allCases, id: \.self) { term in
                    let installed = installedTerminals.contains(term)
                    Button(installed ? term.displayName : "\(term.displayName)（未安装）") {
                        state.terminalPreference = term
                        state.openInTerminal()
                    }
                    .disabled(!installed)
                }
            }
            .popover(isPresented: $showingWheel, arrowEdge: .bottom) {
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
            .onChange(of: showingWheel) { shown in
                if !shown { longPressConsumed = false }
            }
            .task { installedTerminals = Self.detectInstalledTerminals() }
            .help("单击：用固定终端打开当前空间；长按或右键：选择并固定终端")
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

/// 转轮选终端。macOS 没有系统 wheel picker（.pickerStyle(.wheel) 被标记不可用），
/// 自绘拨轮：中间高亮当前选中、上下露出相邻项；点击行、上下拖动、方向按钮均可换选。
/// 未安装项置灰 + 「未安装」后缀，且选中该项时「固定并打开」禁用。
struct TerminalWheelPopover: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let installed: Set<TerminalApp>
    @Binding var selection: TerminalApp
    let onConfirm: (TerminalApp) -> Void
    let onCancel: () -> Void

    private var all: [TerminalApp] { TerminalApp.allCases }
    private var selectedIndex: Int { all.firstIndex(of: selection) ?? 0 }
    private var selectedInstalled: Bool { installed.contains(selection) }

    /// 拨一格对应的拖动距离（pt）。
    private static let stepDistance: CGFloat = 44
    private static let rowSpacing: CGFloat = 27

    /// 拖动过程中已换算成换选的格数（相对按下时刻），松手归零。
    @State private var appliedSteps = 0

    var body: some View {
        VStack(spacing: 12) {
            Text("选择终端")
                .font(.headline)
            HStack(spacing: 8) {
                wheel
                    .frame(width: 196, height: 136)
                    .clipped()
                VStack(spacing: 10) {
                    Button {
                        rotate(by: -1)
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .buttonStyle(.borderless)
                    .disabled(selectedIndex == 0)
                    Spacer()
                    Button {
                        rotate(by: 1)
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .buttonStyle(.borderless)
                    .disabled(selectedIndex == all.count - 1)
                }
            }
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

    // MARK: 拨轮

    private var wheel: some View {
        ZStack {
            Capsule()
                .fill(Color.surface)
                .overlay(Capsule().strokeBorder(Color.cardStroke))
                .frame(width: 192, height: 30)
            ForEach(-2...2, id: \.self) { offset in
                row(at: selectedIndex + offset)
                    .offset(y: CGFloat(offset) * Self.rowSpacing)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 6)
                .onChanged { value in
                    let steps = Int(round(value.translation.height / Self.stepDistance))
                    let delta = steps - appliedSteps
                    if delta != 0 {
                        appliedSteps = steps
                        rotate(by: -delta)   // 上拖 → 下一项进中心
                    }
                }
                .onEnded { _ in appliedSteps = 0 }
        )
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8),
                   value: selection)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("终端转轮，当前 \(selection.displayName)")
        .accessibilityAdjustableAction { direction in
            rotate(by: direction == .increment ? 1 : -1)
        }
    }

    @ViewBuilder
    private func row(at index: Int) -> some View {
        if all.indices.contains(index) {
            let term = all[index]
            let distance = abs(index - selectedIndex)
            let isInstalled = installed.contains(term)
            Text(isInstalled ? term.displayName : "\(term.displayName)（未安装）")
                .font(distance == 0 ? .system(size: 15, weight: .semibold) : .system(size: 12))
                .foregroundStyle(distance == 0
                    ? (isInstalled ? Color.lightBlue : Color.textMuted)
                    : (isInstalled ? Color.textSecondary : Color.textMuted))
                .opacity(distance == 0 ? 1 : (distance == 1 ? 0.72 : 0.38))
                .frame(width: 192, height: 26)
                .contentShape(Rectangle())
                .onTapGesture { selection = term }
        }
    }

    /// 越界钳制后换选。
    private func rotate(by delta: Int) {
        let index = min(max(selectedIndex + delta, 0), all.count - 1)
        selection = all[index]
    }
}
