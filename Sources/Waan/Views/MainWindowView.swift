import SwiftUI

private enum SidebarDestination: Hashable {
    case now
    case tasks(FilterType)
    case focusInsights
}

public struct MainWindowView: View {
    @ObservedObject var store: TaskStore
    @ObservedObject var pomodoro: PomodoroManager = .shared
    @ObservedObject var mcpServer: MCPServerManager = .shared
    @ObservedObject var langManager: LanguageManager = .shared
    @State private var showingAIGuide: Bool = false
    @State private var showingChat: Bool = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var destination: SidebarDestination = .now

    public var body: some View {
        Group {
            if pomodoro.state != .idle {
                FocusModeView(store: store, pomodoro: pomodoro)
            } else {
                NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack(alignment: .leading, spacing: 0) {
                List(selection: $destination) {
                    Label(langManager.text(.focusNow), systemImage: "scope")
                        .font(.system(size: 13))
                        .tag(SidebarDestination.now)
                        .padding(.vertical, 2)

                    Divider()
                        .padding(.vertical, 4)

                    ForEach(FilterType.allCases) { filter in
                        HStack {
                            Label(filter.localizedTitle(for: langManager.currentLanguage), systemImage: filter.iconName)
                                .font(.system(size: 13))
                            Spacer()
                            countLabel(for: filter)
                        }
                        .tag(SidebarDestination.tasks(filter))
                        .padding(.vertical, 2)
                    }

                    Divider()
                        .padding(.vertical, 4)

                    Label(langManager.text(.focusInsights), systemImage: "chart.bar.xaxis")
                        .font(.system(size: 13))
                        .tag(SidebarDestination.focusInsights)
                        .padding(.vertical, 2)
                }
                .listStyle(.sidebar)
                .onChange(of: destination) {
                    if case .tasks(let filter) = destination {
                        store.selectedFilter = filter
                    }
                }

                Divider()
                    .opacity(0.4)

                PomodoroControlCard(compact: true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                Divider()
                    .opacity(0.4)

                HStack(spacing: 6) {
                    Circle()
                        .fill(mcpServer.isRunning ? Color.green : Color.secondary.opacity(0.4))
                        .frame(width: 6, height: 6)
                    Text("MCP")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)

                    Button(action: { showingAIGuide.toggle() }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .help("MCP & AI Config")

                    Spacer()

                    Toggle("", isOn: Binding(
                        get: { mcpServer.isRunning },
                        set: { $0 ? mcpServer.start() : mcpServer.stop() }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .labelsHidden()
                    .help(mcpServer.isRunning ? "Stop MCP Server" : "Start MCP Server")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
            }
            .frame(minWidth: 180, idealWidth: 200, maxWidth: 230)
        } detail: {
            HStack(spacing: 0) {
                Group {
                    switch destination {
                    case .now:
                        FocusNowView(store: store)
                    case .focusInsights:
                        FocusAnalyticsView(store: store)
                    case .tasks:
                        taskListColumn
                            .searchable(text: $store.searchText, prompt: langManager.text(.searchPlaceholder))
                    }
                }
                .frame(minWidth: 280, maxWidth: .infinity)

                if showingChat {
                    Divider()
                    ChatAssistantView()
                        .frame(minWidth: 260, idealWidth: 310, maxWidth: 380)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    Button(action: { withAnimation(.easeInOut(duration: 0.2)) { langManager.toggle() } }) {
                        Text(langManager.currentLanguage == .th ? "TH" : "EN")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .help("Switch Language (ไทย / English)")

                    Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showingChat.toggle() } }) {
                        Label(langManager.text(.aiChat), systemImage: "sparkles")
                    }
                    .tint(showingChat ? .accentColor : .secondary)
                    .help(langManager.text(.aiChat))
                }
            }
            .sheet(isPresented: $showingAIGuide) {
                AIGuideSheetView(mcpServer: mcpServer)
            }
        }
        .navigationSplitViewStyle(.balanced)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: pomodoro.state == .idle)
        .frame(minWidth: 720, minHeight: 480)
    }

    private var taskListColumn: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(store.selectedFilter.localizedTitle(for: langManager.currentLanguage))
                    .font(.system(size: 20, weight: .bold))
                Text("\(store.filteredTasks.count)")
                    .font(.system(size: 13, weight: .medium))
                    .monospacedDigit()
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 8)

            QuickInputBar(store: store)
                .padding(.horizontal, 24)

            if store.filteredTasks.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Text(langManager.currentLanguage == .th ? "ไม่มีงานในรายการนี้" : "Nothing here yet")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    if store.selectedFilter == .completed {
                        LazyVStack(alignment: .leading, spacing: 18) {
                            ForEach(store.groupedCompletedTasks) { group in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 6) {
                                        Text(group.bucket.localizedTitle(for: langManager.currentLanguage))
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(.secondary)
                                        Text("\(group.tasks.count)")
                                            .font(.system(size: 11, weight: .medium))
                                            .monospacedDigit()
                                            .foregroundColor(.secondary.opacity(0.6))
                                        Spacer()
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.top, 4)

                                    LazyVStack(spacing: 0) {
                                        ForEach(group.tasks) { task in
                                            TaskRowView(store: store, task: task)
                                            Divider()
                                                .opacity(0.3)
                                                .padding(.leading, 32)
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(store.filteredTasks) { task in
                                TaskRowView(store: store, task: task)
                                Divider()
                                    .opacity(0.3)
                                    .padding(.leading, 32)
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 6)
            }
        }
    }

    @ViewBuilder
    private func countLabel(for filter: FilterType) -> some View {
        let count: Int = {
            switch filter {
            case .all: return store.tasks.count
            case .today: return store.todayTasksCount
            case .pending: return store.tasks.filter { !$0.isCompleted }.count
            case .highPriority: return store.tasks.filter { !$0.isCompleted && ($0.priority == .high || $0.priority == .urgent) }.count
            case .completed: return store.tasks.filter { $0.isCompleted }.count
            }
        }()

        if count > 0 {
            Text("\(count)")
                .font(.system(size: 11))
                .monospacedDigit()
                .foregroundColor(.secondary)
        }
    }
}

struct CopyButton: View {
    let text: String
    let label: String
    @State private var copied = false

    var body: some View {
        Button(action: {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
        }) {
            HStack(spacing: 4) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                Text(copied ? "Copied!" : label)
            }
            .font(.system(size: 11))
            .foregroundColor(copied ? .green : .accentColor)
        }
        .buttonStyle(.plain)
    }
}

struct AIGuideSheetView: View {
    @ObservedObject var mcpServer: MCPServerManager
    @Environment(\.dismiss) private var dismiss

    private var claudeConfigJson: String {
        let script = mcpServer.resolveScriptPath()
        return """
{
  "mcpServers": {
    "waan": {
      "command": "python3",
      "args": ["\(script)"]
    }
  }
}
"""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "cpu.fill")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 18))
                Text("AI Harness Connection Guide (MCP)")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(mcpServer.isRunning ? Color.green : Color.secondary.opacity(0.4))
                    .frame(width: 8, height: 8)
                Text(mcpServer.isRunning ? "MCP Server Active on port \(String(mcpServer.port))" : "MCP Server is Stopped (toggle ON in sidebar)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("1. Claude Desktop Config (Stdio):")
                                .font(.system(size: 12, weight: .semibold))
                            Spacer()
                            CopyButton(text: claudeConfigJson, label: "Copy Config")
                        }

                        Text("Add to ~/Library/Application Support/Claude/claude_desktop_config.json:")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)

                        Text(claudeConfigJson)
                            .font(.system(size: 10, design: .monospaced))
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.black.opacity(0.06))
                            .cornerRadius(6)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("2. Cursor / SSE Remote Integration:")
                                .font(.system(size: 12, weight: .semibold))
                            Spacer()
                            CopyButton(text: "http://127.0.0.1:\(mcpServer.port)/sse", label: "Copy SSE URL")
                        }

                        Text("SSE Endpoint: http://127.0.0.1:\(mcpServer.port)/sse")
                            .font(.system(size: 10, design: .monospaced))
                            .padding(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.black.opacity(0.06))
                            .cornerRadius(6)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("3. Terminal Control:")
                            .font(.system(size: 12, weight: .semibold))
                        Text("./bin/waan mcp start  |  ./bin/waan mcp stop  |  ./bin/waan mcp status")
                            .font(.system(size: 10, design: .monospaced))
                            .padding(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.black.opacity(0.06))
                            .cornerRadius(6)
                    }
                }
                .padding(.vertical, 4)
            }

            Spacer()
        }
        .padding(20)
        .frame(width: 540, height: 420)
    }
}
