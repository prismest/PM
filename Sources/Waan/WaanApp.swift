import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in sender.windows where window.canBecomeMain {
                window.makeKeyAndOrderFront(nil)
                return true
            }
        }
        return true
    }
}

@main
struct WaanApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var store = TaskStore.shared
    @StateObject private var mcpServer = MCPServerManager.shared
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window("Waan", id: "main-window") {
            MainWindowView(store: store, mcpServer: mcpServer)
                .frame(minWidth: 860, minHeight: 540)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)

        MenuBarExtra("Waan", systemImage: "sparkles.rectangle.stack") {
            MenuBarView(store: store, mcpServer: mcpServer) {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main-window")
            }
        }
        .menuBarExtraStyle(.window)
    }
}
