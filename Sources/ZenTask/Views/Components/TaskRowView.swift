import SwiftUI

public struct TaskRowView: View {
    @ObservedObject var store: TaskStore
    let task: TaskItem
    @State private var isExpanded: Bool = false

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                // Checkbox
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

                // Title & Metadata
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .font(.system(size: 14, weight: task.isCompleted ? .regular : .medium))
                        .strikethrough(task.isCompleted, color: .secondary)
                        .foregroundColor(task.isCompleted ? .secondary : .primary)

                    HStack(spacing: 8) {
                        // Priority Badge
                        priorityBadge(task.priority)

                        // Due Date
                        if let due = task.dueDate, !due.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 10))
                                Text(formatDueDate(due))
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(.secondary)
                        }

                        // Subtasks Counter
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

                        // Tags
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

                // Delete Button
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
                .help("ลบงานนี้")
            }

            // Expanded Subtasks List
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
        let (color, text): (Color, String) = {
            switch priority {
            case .low: return (.gray, "ต่ำ")
            case .normal: return (.blue, "ปกติ")
            case .high: return (.orange, "สำคัญ")
            case .urgent: return (.red, "ด่วนมาก")
            }
        }()

        Text(text)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(4)
    }

    private func formatDueDate(_ raw: String) -> String {
        let todayStr = String(ISO8601DateFormatter().string(from: Date()).prefix(10))
        if raw.starts(with: todayStr) {
            return "วันนี้"
        }
        return raw.prefix(10).description
    }
}

