import SwiftUI

@main
struct ZenTaskApp: App {
    @StateObject private var store = TaskStore.shared
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        // 1. Menu Bar Item (ข้างนาฬิกาบน Mac)
        MenuBarExtra("ZenTask", systemImage: "sparkles.rectangle.stack") {
            MenuBarView(store: store) {
                // Open full window
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main-window")
            }
        }
        .menuBarExtraStyle(.window)

        // 2. Main Window (หน้าต่างแอปหลัก)
        Window("ZenTask", id: "main-window") {
            MainWindowView(store: store)
                .frame(minWidth: 780, minHeight: 520)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
    }
}
