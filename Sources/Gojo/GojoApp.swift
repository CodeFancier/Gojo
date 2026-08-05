import SwiftUI

@main
struct GojoApp: App {
    @StateObject private var state = AppState()
    var body: some Scene {
        WindowGroup("Gojo") {
            ContentView().environmentObject(state)
        }
        // 隐藏系统标题栏，让深色渐变铺满整窗，消除标题栏与内容区的撞色接缝。
        // 顶部 ~28pt 仍是可拖拽区；红绿灯浮于左上，由 DomainTopBar 留出让位。
        .windowStyle(.hiddenTitleBar)
    }
}
