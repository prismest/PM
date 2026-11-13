import SwiftUI

public struct TaskRowView: View {
    @ObservedObject var store: TaskStore
    @ObservedObject var langManager: LanguageManager = .shared
    let task: TaskItem
    @State private var isExpanded: Bool = false
    @State private var isHovering: Bool = false

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                Button(action: {
                    if !task.isCompleted {
                        PomodoroManager.shared.detachTask(id: task.id)
                    }
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        store.toggleTask(id: task.id)
                    }
                }) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(task.isCompleted ? .green : priorityColor(task.priority))
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.system(size: 13.5, weight: task.isCompleted ? .regular : .medium))
                        .strikethrough(task.isCompleted, color: .secondary)
                        .foregroundColor(task.isCompleted ? .secondary : .primary)

                    if hasMetadata {
                        HStack(spacing: 8) {
                            if task.isCompleted,
                               let timeText = CompletedTasksGrouper.formatCompletedTime(task.completedAt, lang: langManager.currentLanguage) {
                                Text(timeText)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            } else if let due = task.dueDate, !due.isEmpty {
                                Text(formatDueDate(due))
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }

                            categoryMenu

                            if !task.subtasks.isEmpty {
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                                }) {
                                    Text("\(task.subtaskProgress.done)/\(task.subtaskProgress.total)")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Spacer()

                TaskLoggedDurationLabel(taskId: task.id)

                if isHovering && !task.isCompleted {
                    Button(action: { PomodoroManager.shared.startFocus(task: task) }) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.7))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 3)
                    }
                    .buttonStyle(.plain)
                    .help(langManager.currentLanguage == .th ? "เริ่มจับเวลาโฟกัสงานนี้" : "Focus on this task")
                }

                if isHovering {
                    Button(action: {
                        PomodoroManager.shared.detachTask(id: task.id)
                        withAnimation { store.deleteTask(id: task.id) }
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.65))
                    }
                    .buttonStyle(.plain)
                    .help(langManager.currentLanguage == .th ? "ลบงาน" : "Delete task")
                }
            }

            if isExpanded && !task.subtasks.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(task.subtasks) { subtask in
                        HStack(spacing: 8) {
                            Button(action: {
                                store.toggleSubtask(taskId: task.id, subtaskId: subtask.id)
                            }) {
                                Image(systemName: subtask.isDone ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 12))
                                    .foregroundColor(subtask.isDone ? .green : .secondary)
                            }
                            .buttonStyle(.plain)

                            Text(subtask.title)
                                .font(.system(size: 12))
                                .strikethrough(subtask.isDone, color: .secondary)
                                .foregroundColor(subtask.isDone ? .secondary : .primary)

                            Spacer()
                        }
                        .padding(.leading, 26)
                    }
                }
                .padding(.vertical, 2)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(isHovering ? Color.secondary.opacity(0.06) : .clear, in: RoundedRectangle(cornerRadius: 6))
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private var hasMetadata: Bool {
        let hasDue = !(task.dueDate ?? "").isEmpty
        let hasTag = !FocusAnalytics.primaryCategory(tags: task.tags).isEmpty
        let hasCompletion = task.isCompleted && task.completedAt != nil
        return hasDue || hasTag || !task.subtasks.isEmpty || hasCompletion || isHovering
    }

    @ViewBuilder
    private var categoryMenu: some View {
        let currentTag = FocusAnalytics.primaryCategory(tags: task.tags)
        let isTh = langManager.currentLanguage == .th
        if !currentTag.isEmpty || isHovering {
            Menu {
                ForEach(FocusAnalytics.presetCategories, id: \.self) { cat in
                    Button(action: { store.updateTags(id: task.id, tags: [cat]) }) {
                        HStack {
                            Text("#\(cat)")
                            if currentTag == cat { Image(systemName: "checkmark") }
                        }
                    }
                }
                if !currentTag.isEmpty {
                    Divider()
                    Button(isTh ? "ล้างประเภท" : "Clear category") {
                        store.updateTags(id: task.id, tags: [])
                    }
                }
            } label: {
                Text(currentTag.isEmpty ? (isTh ? "+ ประเภท" : "+ tag") : "#\(currentTag)")
                    .font(.system(size: 11))
                    .foregroundColor(currentTag.isEmpty ? .secondary.opacity(0.6) : .accentColor.opacity(0.85))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
    }

    private func priorityColor(_ priority: Priority) -> Color {
        switch priority {
        case .low: return .secondary.opacity(0.4)
        case .normal: return .secondary.opacity(0.7)
        case .high: return .orange.opacity(0.85)
        case .urgent: return .red.opacity(0.9)
        }
    }

    private func formatDueDate(_ raw: String) -> String {
        let today = String(ISO8601DateFormatter().string(from: Date()).prefix(10))
        if raw.starts(with: today) {
            return langManager.currentLanguage == .th ? "วันนี้" : "Today"
        }
        return String(raw.prefix(10))
    }
}

private struct TaskLoggedDurationLabel: View {
    @ObservedObject var pomodoro: PomodoroManager = .shared
    @ObservedObject var langManager: LanguageManager = .shared
    let taskId: String

    var body: some View {
        let total = pomodoro.sessions
            .filter { $0.kind == .focus && $0.taskId == taskId }
            .reduce(0) { $0 + $1.actualSeconds }
        if total > 0 {
            Text(FocusDurationFormat.human(total, lang: langManager.currentLanguage))
                .font(.system(size: 11))
                .monospacedDigit()
                .foregroundColor(.secondary)
        }
    }
}
