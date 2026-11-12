import SwiftUI

public struct TaskRowView: View {
    @ObservedObject var store: TaskStore
    @ObservedObject var langManager: LanguageManager = .shared
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

                    HStack(spacing: 6) {
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

                        categoryMenu

                        TaskLoggedDurationBadge(taskId: task.id)
                    }
                }

                Spacer()

                if !task.isCompleted {
                    TaskFocusButton(task: task)
                }

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
    private var categoryMenu: some View {
        let currentTag = FocusAnalytics.primaryCategory(tags: task.tags)
        let isTh = langManager.currentLanguage == .th
        Menu {
            ForEach(FocusAnalytics.presetCategories, id: \.self) { cat in
                Button(action: { store.updateTags(id: task.id, tags: [cat]) }) {
                    HStack {
                        Text("#\(cat)")
                        if currentTag == cat {
                            Image(systemName: "checkmark")
                        }
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
            if currentTag.isEmpty {
                Image(systemName: "tag")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary.opacity(0.6))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(4)
            } else {
                Text("#\(currentTag)")
                    .font(.system(size: 10))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(isTh ? "ตั้งประเภทงาน" : "Assign task category")
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

        Text(priority.localizedName(for: langManager.currentLanguage))
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(4)
    }

    private func formatDueDate(_ raw: String) -> String {
        let today = String(ISO8601DateFormatter().string(from: Date()).prefix(10))
        if raw.starts(with: today) {
            return langManager.currentLanguage == .th ? "วันนี้" : "Today"
        }
        return String(raw.prefix(10))
    }
}

private struct TaskLoggedDurationBadge: View {
    @ObservedObject var pomodoro: PomodoroManager = .shared
    @ObservedObject var langManager: LanguageManager = .shared
    let taskId: String

    var body: some View {
        let total = pomodoro.sessions
            .filter { $0.kind == .focus && $0.taskId == taskId }
            .reduce(0) { $0 + $1.actualSeconds }
        if total > 0 {
            HStack(spacing: 2) {
                Image(systemName: "timer")
                    .font(.system(size: 9))
                Text(FocusDurationFormat.human(total, lang: langManager.currentLanguage))
                    .font(.system(size: 10, weight: .medium))
                    .monospacedDigit()
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Color.purple.opacity(0.12))
            .foregroundColor(.purple)
            .cornerRadius(4)
        }
    }
}

private struct TaskFocusButton: View {
    @ObservedObject var pomodoro: PomodoroManager = .shared
    @ObservedObject var langManager: LanguageManager = .shared
    let task: TaskItem

    var body: some View {
        let active = pomodoro.isFocusing(on: task.id)
        let color: Color = active ? (pomodoro.isOvertime ? .orange : .accentColor) : .secondary.opacity(0.75)

        Button(action: { pomodoro.startFocus(task: task) }) {
            HStack(spacing: 3) {
                Image(systemName: active && pomodoro.isRunning ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 14))
                if active, let clock = pomodoro.menuBarText {
                    Text(clock)
                        .font(.system(size: 10, weight: .semibold))
                        .monospacedDigit()
                }
            }
            .foregroundColor(color)
        }
        .buttonStyle(.plain)
        .help(langManager.currentLanguage == .th
              ? (active ? "หยุดชั่วคราว / ทำต่อ" : "เริ่มจับเวลาโฟกัสงานนี้")
              : (active ? "Pause / Resume" : "Focus on this task"))
    }
}

