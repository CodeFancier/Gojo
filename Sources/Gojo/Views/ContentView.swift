import SwiftUI

struct ContentView: View {
    @EnvironmentObject var state: AppState
    var body: some View {
        NavigationSplitView {
            Text("侧边栏占位").frame(minWidth: 220)
        } detail: {
            Text("详情占位")
        }
        .alert("操作失败", isPresented: Binding(
            get: { state.errorMessage != nil },
            set: { if !$0 { state.errorMessage = nil } })) {
            Button("好") { state.errorMessage = nil }
        } message: { Text(state.errorMessage ?? "") }
    }
}
