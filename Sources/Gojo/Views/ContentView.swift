import SwiftUI
import GojoCore

struct ContentView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Group {
            switch state.route {
            case .shelf:
                Text("展示柜")                         // Task 7 替换
            case .publicSpace:
                Text("公共空间")                       // Task 10 替换
            case .codingSpace(let u):
                Text(u.lastPathComponent)             // Task 8 替换
            case .shelfDropping:
                Text("投放中")                         // Task 11 替换
            }
        }
        .frame(minWidth: 720, minHeight: 460)
        .alert("操作失败", isPresented: Binding(
            get: { state.errorMessage != nil },
            set: { if !$0 { state.errorMessage = nil } })) {
            Button("好") { state.errorMessage = nil }
        } message: { Text(state.errorMessage ?? "") }
    }
}
