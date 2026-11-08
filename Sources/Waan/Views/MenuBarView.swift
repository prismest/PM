import SwiftUI

public struct MenuBarView: View {
    @ObservedObject var store: TaskStore
    let onOpenMainWindow: () -> Void

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.accentColor)
                    Text("Waan")
                        .font(.system(size: 14, weight: .bold))
                }

                Spacer()

                // Pending task count badge
                Text("\(store.todayTasksCount) งานวันนี้")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundColor(.accentColor)
                    .cornerRadius(10)

                // Open Main Window Button
                Button(action: onOpenMainWindow) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("เปิดหน้าต่างหลัก")
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            // Quick Input
            VStack {
                QuickInputBar(store: store)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // Tasks List
            if store.filteredTasks.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "checkmark.seal")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("ไม่มีงานค้างสำหรับวันนี้!")
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

            // Footer with AI Harness status & Quit
            HStack {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("AI Harness Bridge Ready")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .help("ฐานข้อมูลอยู่ที่ ~/.waan/tasks.db พร้อมให้ AI เชื่อมต่อ")

                Spacer()

                Button("ออกจากแอป") {
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

