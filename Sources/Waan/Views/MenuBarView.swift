import SwiftUI

public struct MenuBarView: View {
    @ObservedObject var store: TaskStore
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

                Text("\(store.todayTasksCount) today")
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
                .help("Open Main Window")
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

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
                    Text("All tasks completed for today!")
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

            HStack {
                HStack(spacing: 5) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("AI Harness Bridge Ready")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .help("Database at ~/.waan/tasks.db ready for AI connection")

                Spacer()

                Button("Quit") {
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

