import SwiftUI

public struct MainWindowView: View {
    @ObservedObject var store: TaskStore
    @State private var showingAIGuide: Bool = false

    public var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 12) {
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

                List(FilterType.allCases, selection: Binding(
                    get: { store.selectedFilter },
                    set: { store.selectedFilter = $0 }
                )) { filter in
                    HStack {
                        Label(filter.rawValue, systemImage: filter.iconName)
                            .font(.system(size: 13))
                        Spacer()
                        countBadge(for: filter)
                    }
                    .tag(filter)
                    .padding(.vertical, 2)
                }
                .listStyle(.sidebar)

                Spacer()

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("AI Harness Active")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.primary)
                    }

                    Text("~/.waan/tasks.db ready for Claude, Cursor, MCP")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(2)

                    Button(action: { showingAIGuide.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "terminal.fill")
                                .font(.system(size: 9))
                            Text("AI Integration Guide")
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
            .frame(minWidth: 200, idealWidth: 220)
        } detail: {
            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.selectedFilter.rawValue)
                            .font(.system(size: 20, weight: .bold))
                        Text("\(store.filteredTasks.count) tasks")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                        TextField("Search tasks...", text: $store.searchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12))
                        if !store.searchText.isEmpty {
                            Button(action: { store.searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(7)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                    )
                    .frame(width: 200)
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 14)

                Divider()

                VStack {
                    QuickInputBar(store: store)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)

                if store.filteredTasks.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "sparkles")
                            .font(.system(size: 40))
                            .foregroundColor(.accentColor.opacity(0.5))
                        Text("No tasks in this category")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                        Text("Add a task above or let your AI harness schedule tasks.")
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
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                    }
                }
            }
            .sheet(isPresented: $showingAIGuide) {
                AIGuideSheetView()
            }
        }
        .frame(minWidth: 780, minHeight: 520)
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

struct AIGuideSheetView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "cpu.fill")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 18))
                Text("AI Harness Connection Guide (Claude / Cursor / CLI)")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            Divider()

            Text("Waan stores data in SQLite at **~/.waan/tasks.db**, allowing external AI harnesses to read and create tasks directly:")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("1. CLI Command (Fast & Scriptable):")
                    .font(.system(size: 12, weight: .semibold))
                Text("`./bin/waan add \"Prepare slide deck\" --due today --priority high`")
                    .font(.system(size: 11, design: .monospaced))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.06))
                    .cornerRadius(6)

                Text("2. Claude Desktop / Cursor via MCP:")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.top, 4)
                Text("Use `mcp_server.py` in this folder to let Claude call tools like `waan_add_task` and `waan_list_tasks` using your existing subscription.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(20)
        .frame(width: 520, height: 320)
    }
}

