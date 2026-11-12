import SwiftUI
import AppKit

extension Notification.Name {
    static let waanOpenMainWindow = Notification.Name("waan.openMainWindow")
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if !NSApp.windows.contains(where: { $0.canBecomeMain && $0.isVisible }) {
                NotificationCenter.default.post(name: .waanOpenMainWindow, object: nil)
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            NotificationCenter.default.post(name: .waanOpenMainWindow, object: nil)
        }
        return true
    }
}

private struct MenuBarStatusHost: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        MenuBarLabelView()
            .onReceive(NotificationCenter.default.publisher(for: .waanOpenMainWindow)) { _ in
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
                if let win = NSApp.windows.first(where: { $0.canBecomeMain }) {
                    win.makeKeyAndOrderFront(nil)
                } else {
                    openWindow(id: "main-window")
                }
            }
    }
}

@main
struct WaanApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var store = TaskStore.shared
    @StateObject private var mcpServer = MCPServerManager.shared

    var body: some Scene {
        Window("Waan", id: "main-window") {
            MainWindowView(store: store, mcpServer: mcpServer)
                .frame(minWidth: 780, minHeight: 540)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)

        MenuBarExtra {
            MenuBarView(store: store, mcpServer: mcpServer) {
                NotificationCenter.default.post(name: .waanOpenMainWindow, object: nil)
            }
        } label: {
            MenuBarStatusHost()
        }
        .menuBarExtraStyle(.window)
    }
}
