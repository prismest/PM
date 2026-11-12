import SwiftUI

public struct MenuBarView: View {
    @ObservedObject var store: TaskStore
    @ObservedObject var mcpServer: MCPServerManager = .shared
    @ObservedObject var langManager: LanguageManager = .shared
    let onOpenMainWindow: () -> Void

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("Waan")
                    .font(.system(size: 13, weight: .semibold))
                Text("· \(store.todayTasksCount)")
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .foregroundColor(.secondary)

                Spacer()

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
                .opacity(0.4)

            PomodoroControlCard(compact: false)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)

            Divider()
                .opacity(0.4)

            QuickInputBar(store: store)
                .padding(.horizontal, 14)
                .padding(.top, 4)

            if store.filteredTasks.isEmpty {
                VStack(spacing: 6) {
                    Spacer()
                    Text(langManager.currentLanguage == .th ? "ทำงานของวันนี้ครบแล้ว" : "All clear for today")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(height: 150)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.filteredTasks) { task in
                            TaskRowView(store: store, task: task)
                            Divider()
                                .opacity(0.25)
                                .padding(.leading, 30)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 260)
            }

            Divider()
                .opacity(0.4)

            HStack(spacing: 8) {
                Circle()
                    .fill(mcpServer.isRunning ? Color.green : Color.secondary.opacity(0.4))
                    .frame(width: 6, height: 6)
                Text("MCP")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(.secondary)

                Toggle("", isOn: Binding(
                    get: { mcpServer.isRunning },
                    set: { $0 ? mcpServer.start() : mcpServer.stop() }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()

                Spacer()

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
        }
        .frame(width: 320)
    }
}
