import SwiftUI

private enum SidebarDestination: Hashable {
    case tasks(FilterType)
    case focusInsights
}

public struct MainWindowView: View {
    @ObservedObject var store: TaskStore
    @ObservedObject var mcpServer: MCPServerManager = .shared
    @ObservedObject var langManager: LanguageManager = .shared
    @State private var showingAIGuide: Bool = false
    @State private var showingChat: Bool = true
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var destination: SidebarDestination = .tasks(.today)

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Waan")
                            .font(.system(size: 16, weight: .bold))
                        Text("Personal Task Manager")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)

                Divider()

                List(selection: $destination) {
                    ForEach(FilterType.allCases) { filter in
                        HStack {
                            Label(filter.localizedTitle(for: langManager.currentLanguage), systemImage: filter.iconName)
                                .font(.system(size: 13))
                            Spacer()
                            countBadge(for: filter)
                        }
                        .tag(SidebarDestination.tasks(filter))
                        .padding(.vertical, 2)
                    }

                    Divider()

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

                PomodoroControlCard(compact: true)
                    .padding(.horizontal, 12)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(mcpServer.isRunning ? Color.green : Color.secondary.opacity(0.4))
                                .frame(width: 8, height: 8)
                                .shadow(color: mcpServer.isRunning ? Color.green.opacity(0.4) : Color.clear, radius: 3)
                            Text("MCP Server")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.primary)
                        }

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { mcpServer.isRunning },
                            set: { $0 ? mcpServer.start() : mcpServer.stop() }
                        ))
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                        .help(mcpServer.isRunning ? "Stop MCP Server" : "Start MCP Server")
                    }

                    Text(mcpServer.isRunning ? "Port \(String(mcpServer.port)) • Ready for AI" : "Turn ON to enable AI bridge")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(2)

                    Button(action: { showingAIGuide.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 10))
                            Text("MCP & AI Config")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
                .padding(10)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(8)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .frame(minWidth: 180, idealWidth: 200, maxWidth: 240)
        } detail: {
            HStack(spacing: 0) {
                Group {
                    switch destination {
                    case .focusInsights:
                        FocusAnalyticsView(store: store)
                    case .tasks:
                        taskListColumn
                    }
                }
                .frame(minWidth: 300, maxWidth: .infinity)

                if showingChat {
                    Divider()
                    ChatAssistantView()
                        .frame(minWidth: 280, idealWidth: 320, maxWidth: 400)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
            .sheet(isPresented: $showingAIGuide) {
                AIGuideSheetView(mcpServer: mcpServer)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 780, minHeight: 540)
    }

    private var taskListColumn: some View {
        VStack(spacing: 0) {
                    HStack(alignment: .center, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.selectedFilter.localizedTitle(for: langManager.currentLanguage))
                                .font(.system(size: 18, weight: .bold))
                                .lineLimit(1)
                            Text(langManager.text(.taskCount(store.filteredTasks.count)))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        Spacer(minLength: 8)

                        HStack(spacing: 6) {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 11))
                                TextField(langManager.text(.searchPlaceholder), text: $store.searchText)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 11))
                                if !store.searchText.isEmpty {
                                    Button(action: { store.searchText = "" }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                            .font(.system(size: 11))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                            )
                            .frame(minWidth: 90, idealWidth: 130, maxWidth: 160)

                            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { langManager.toggle() } }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "globe")
                                        .font(.system(size: 10))
                                    Text(langManager.currentLanguage.title)
                                        .font(.system(size: 10, weight: .medium))
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(Color.secondary.opacity(0.08))
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .help("Switch Language (ไทย / English)")

                            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showingChat.toggle() } }) {
                                HStack(spacing: 3) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 10))
                                    Text(langManager.text(.aiChat))
                                        .font(.system(size: 10, weight: .medium))
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(showingChat ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.08))
                                .foregroundColor(showingChat ? .accentColor : .primary)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                            .help("Toggle Antigravity AI Assistant Panel")
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 10)

                    Divider()

                    VStack {
                        QuickInputBar(store: store)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    if store.filteredTasks.isEmpty {
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: "sparkles")
                                .font(.system(size: 40))
                                .foregroundColor(.accentColor.opacity(0.5))
                            Text("No tasks in this category")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                            Text("Add a task above or chat with Antigravity AI to schedule tasks.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(store.filteredTasks) { task in
                                    TaskRowView(store: store, task: task)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                    }
                }
    }

    @ViewBuilder
    private func countBadge(for filter: FilterType) -> some View {
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
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Color.secondary.opacity(0.12))
                .cornerRadius(8)
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

