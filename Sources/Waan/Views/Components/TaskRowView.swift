import SwiftUI

public struct TaskRowView: View {
    @ObservedObject var store: TaskStore
    let task: TaskItem
    @State private var isExpanded: Bool = false

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        store.toggleTask(id: task.id)
                    }
                }) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(task.isCompleted ? .green : .secondary)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .font(.system(size: 14, weight: task.isCompleted ? .regular : .medium))
                        .strikethrough(task.isCompleted, color: .secondary)
                        .foregroundColor(task.isCompleted ? .secondary : .primary)

                    HStack(spacing: 8) {
                        priorityBadge(task.priority)

                        if let due = task.dueDate, !due.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 10))
                                Text(formatDueDate(due))
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(.secondary)
                        }

                        if !task.subtasks.isEmpty {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isExpanded.toggle()
                                }
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: isExpanded ? "chevron.down" : "checklist")
                                        .font(.system(size: 10))
                                    Text("\(task.subtaskProgress.done)/\(task.subtaskProgress.total)")
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.12))
                                .cornerRadius(5)
                                .foregroundColor(.primary)
                            }
                            .buttonStyle(.plain)
                        }

                        ForEach(task.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.system(size: 10))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                    }
                }

                Spacer()

                Button(action: {
                    withAnimation {
                        store.deleteTask(id: task.id)
                    }
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Delete task")
            }

            if isExpanded && !task.subtasks.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(task.subtasks) { subtask in
                        HStack(spacing: 8) {
                            Button(action: {
                                store.toggleSubtask(taskId: task.id, subtaskId: subtask.id)
                            }) {
                                Image(systemName: subtask.isDone ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 13))
                                    .foregroundColor(subtask.isDone ? .green : .secondary)
                            }
                            .buttonStyle(.plain)

                            Text(subtask.title)
                                .font(.system(size: 12))
                                .strikethrough(subtask.isDone, color: .secondary)
                                .foregroundColor(subtask.isDone ? .secondary : .primary)

                            Spacer()
                        }
                        .padding(.leading, 28)
                    }
                }
                .padding(.vertical, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        )
    }

    @ViewBuilder
    private func priorityBadge(_ priority: Priority) -> some View {
        let color: Color = {
            switch priority {
            case .low: return .gray
            case .normal: return .blue
            case .high: return .orange
            case .urgent: return .red
            }
        }()

        Text(priority.displayName)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(4)
    }

    private func formatDueDate(_ raw: String) -> String {
        let today = String(ISO8601DateFormatter().string(from: Date()).prefix(10))
        return raw.starts(with: today) ? "Today" : String(raw.prefix(10))
    }
}

