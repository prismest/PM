import SwiftUI

@main
struct WaanApp: App {
    @StateObject private var store = TaskStore.shared
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra("Waan", systemImage: "sparkles.rectangle.stack") {
            MenuBarView(store: store) {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main-window")
            }
        }
        .menuBarExtraStyle(.window)

        Window("Waan", id: "main-window") {
            MainWindowView(store: store)
                .frame(minWidth: 780, minHeight: 520)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
    }
}
