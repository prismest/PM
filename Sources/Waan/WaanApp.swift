import SwiftUI

@main
struct WaanApp: App {
    @StateObject private var store = TaskStore.shared
    @StateObject private var mcpServer = MCPServerManager.shared
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra("Waan", systemImage: "sparkles.rectangle.stack") {
            MenuBarView(store: store, mcpServer: mcpServer) {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main-window")
            }
        }
        .menuBarExtraStyle(.window)

        Window("Waan", id: "main-window") {
            MainWindowView(store: store, mcpServer: mcpServer)
                .frame(minWidth: 860, minHeight: 540)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
    }
}
