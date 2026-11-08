import SwiftUI

public struct MainWindowView: View {
    @ObservedObject var store: TaskStore
    @State private var showingAIGuide: Bool = false

    public var body: some View {
        NavigationSplitView {
            // Sidebar
            VStack(alignment: .leading, spacing: 12) {
                // App Brand
                HStack(spacing: 8) {
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Personal Task AI")
                            .font(.system(size: 15, weight: .bold))
                        Text("macOS & AI Assistant")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)

                Divider()

                // Filter Categories
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

                // AI Harness Status Box
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("AI Harness Active")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.primary)
                    }

                    Text("~/.personaltaskai/tasks.db พร้อมเชื่อมต่อกับ Claude, Cursor, MCP")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(2)

                    Button(action: { showingAIGuide.toggle() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "terminal.fill")
                                .font(.system(size: 9))
                            Text("วิธีให้ AI สั่งงาน")
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
            // Main Content Area
            VStack(spacing: 0) {
                // Header Bar
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.selectedFilter.rawValue)
                            .font(.system(size: 20, weight: .bold))
                        Text("\(store.filteredTasks.count) รายการ")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Search Field
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                        TextField("ค้นหางาน...", text: $store.searchText)
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

                // Quick Input Area
                VStack {
                    QuickInputBar(store: store)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 12)

                // Task List or Empty State
                if store.filteredTasks.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "sparkles")
                            .font(.system(size: 40))
                            .foregroundColor(.accentColor.opacity(0.5))
                        Text("ไม่มีงานในหมวดนี้")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                        Text("พิมพ์งานใหม่ด้านบน หรือให้ AI Harness เพิ่มงานเข้ามาได้ทันที")
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

// AI Harness Connection Guide Modal
struct AIGuideSheetView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "cpu.fill")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 18))
                Text("การเชื่อมต่อกับ AI Harness (Claude / Cursor / CLI)")
                    .font(.system(size: 15, weight: .bold))
                Spacer()
                Button("ปิด") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }

            Divider()

            Text("Personal Task AI เก็บข้อมูลลงใน SQLite ที่ **~/.personaltaskai/tasks.db** ทำให้ AI Harness ทุกตัวสามารถอ่านและสั่งงานเข้ามาได้ทันที:")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("1. สั่งงานผ่าน CLI Command (เร็วที่สุด):")
                    .font(.system(size: 12, weight: .semibold))
                Text("`./bin/taskai add \"เตรียมสไลด์นำเสนอ\" --due today --priority high`")
                    .font(.system(size: 11, design: .monospaced))
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.black.opacity(0.06))
                    .cornerRadius(6)

                Text("2. เชื่อมต่อ Claude Desktop / Cursor ผ่าน MCP:")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.top, 4)
                Text("เรียกใช้ `mcp_server.py` ในโฟลเดอร์นี้ เพื่อให้ Claude เรียกใช้งาน Tool `taskai_add_task`, `taskai_list_tasks` ได้ด้วย subscription ของคุณ")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(20)
        .frame(width: 520, height: 320)
    }
}

