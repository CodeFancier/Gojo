import SwiftUI
import AppKit
import GojoCore

struct ToolbarButtons: View {
    @EnvironmentObject var state: AppState
    /// 已安装的终端集合；默认全部可选，探测完成后把未安装的置灰。
    @State private var installedTerminals: Set<TerminalApp> = Set(TerminalApp.allCases)

    var body: some View {
        HStack {
            Menu {
                ForEach(TerminalApp.allCases, id: \.self) { term in
                    let installed = installedTerminals.contains(term)
                    Button(installed ? term.displayName : "\(term.displayName)（未安装）") {
                        state.terminalPreference = term
                        state.openInTerminal()
                    }
                    .disabled(!installed)
                }
            } label: { Label("终端", systemImage: "terminal") }
            Button { state.openInFinder() } label: { Label("访达", systemImage: "folder") }
        }
        .task { installedTerminals = Self.detectInstalledTerminals() }
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
