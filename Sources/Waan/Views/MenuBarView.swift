import SwiftUI

public struct MenuBarView: View {
    @ObservedObject var store: TaskStore
    @ObservedObject var mcpServer: MCPServerManager = .shared
    @ObservedObject var langManager: LanguageManager = .shared
    let onOpenMainWindow: () -> Void

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.accentColor)
                    Text("Waan")
                        .font(.system(size: 14, weight: .bold))
                }

                Spacer()

                Text("\(store.todayTasksCount) \(langManager.currentLanguage == .th ? "วันนี้" : "today")")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundColor(.accentColor)
                    .cornerRadius(10)

                Button(action: onOpenMainWindow) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help(langManager.text(.openMainWindow))
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            PomodoroControlCard(compact: false)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            VStack {
                QuickInputBar(store: store)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            if store.filteredTasks.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text(langManager.currentLanguage == .th ? "ทำงานของวันนี้ครบหมดแล้ว!" : "All tasks completed for today!")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(height: 180)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(store.filteredTasks) { task in
                            TaskRowView(store: store, task: task)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .frame(maxHeight: 280)
            }

            Divider()

            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(mcpServer.isRunning ? Color.green : Color.secondary.opacity(0.4))
                        .frame(width: 6, height: 6)
                        .shadow(color: mcpServer.isRunning ? Color.green.opacity(0.4) : Color.clear, radius: 2)
                    Text(mcpServer.isRunning ? (langManager.currentLanguage == .th ? "เซิร์ฟเวอร์ MCP กำลังทำงาน" : "MCP Server Active") : (langManager.currentLanguage == .th ? "เซิร์ฟเวอร์ MCP ปิดอยู่" : "MCP Server Off"))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(mcpServer.isRunning ? .primary : .secondary)
                }
                .help(mcpServer.isRunning ? "MCP Server running on port \(String(mcpServer.port))" : "MCP Server stopped")

                Spacer()

                Toggle("", isOn: Binding(
                    get: { mcpServer.isRunning },
                    set: { $0 ? mcpServer.start() : mcpServer.stop() }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
                .help(mcpServer.isRunning ? "Turn off MCP Server" : "Turn on MCP Server")

                Divider()
                    .frame(height: 12)

                Button(langManager.text(.quit)) {
                    mcpServer.stop()
                    NSApplication.shared.terminate(nil)
                }
                .font(.system(size: 11))
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.5))
        }
        .frame(width: 360)
    }
}

