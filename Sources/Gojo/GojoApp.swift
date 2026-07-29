import SwiftUI

@main
struct GojoApp: App {
    @StateObject private var state = AppState()
    var body: some Scene {
        WindowGroup("Gojo") {
            ContentView().environmentObject(state)
        }
        .windowStyle(.titleBar)
    }
}
