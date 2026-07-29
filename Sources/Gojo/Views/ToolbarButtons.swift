import SwiftUI
import GojoCore

struct ToolbarButtons: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        HStack {
            Menu {
                ForEach(TerminalApp.allCases, id: \.self) { term in
                    Button(label(term)) { state.terminalPreference = term; state.openInTerminal() }
                }
            } label: { Label("终端", systemImage: "terminal") }
            Button { state.openInFinder() } label: { Label("访达", systemImage: "folder") }
        }
    }
    private func label(_ t: TerminalApp) -> String {
        switch t { case .terminal: return "Terminal"; case .iterm2: return "iTerm2"; case .warp: return "Warp" }
    }
}
