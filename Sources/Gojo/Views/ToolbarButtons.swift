import SwiftUI

/// 领域顶栏右侧操作区：终端（含转轮切换）+ 访达。
struct ToolbarButtons: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        HStack {
            TerminalPickerButton()
            Button { state.openInFinder() } label: { Label("访达", systemImage: "folder") }
        }
    }
}
