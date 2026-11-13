import SwiftUI

private struct TaskSubtaskChecklist: View {
    @ObservedObject var store: TaskStore
    let task: TaskItem
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 5 : 7) {
            ForEach(task.subtasks) { subtask in
                Button(action: { store.toggleSubtask(taskId: task.id, subtaskId: subtask.id) }) {
                    HStack(spacing: 8) {
                        Image(systemName: subtask.isDone ? "checkmark.square.fill" : "square")
                            .font(.system(size: compact ? 11.5 : 13))
                            .foregroundColor(subtask.isDone ? .green : .secondary)
                        Text(subtask.title)
                            .font(.system(size: compact ? 11.5 : 13))
                            .strikethrough(subtask.isDone, color: .secondary)
                            .foregroundColor(subtask.isDone ? .secondary : .primary.opacity(0.9))
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

public struct FocusNowView: View {
    @ObservedObject var store: TaskStore
    @ObservedObject var pomodoro: PomodoroManager
    @ObservedObject var langManager: LanguageManager = .shared
    let compact: Bool

    public init(store: TaskStore, pomodoro: PomodoroManager? = nil, compact: Bool = false) {
        self.store = store
        self.pomodoro = pomodoro ?? .shared
        self.compact = compact
    }

    private var lang: AppLanguage { langManager.currentLanguage }
    private var isTh: Bool { lang == .th }

    private var recommendation: RecommendedTask? {
        store.recommendedTask()
    }

    public var body: some View {
        if let rec = recommendation {
            let content = taskStage(rec)
            if compact {
                content
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
            } else {
                VStack {
                    Spacer()
                    content
                        .frame(maxWidth: 440, alignment: .leading)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 36)
                .padding(.vertical, 24)
            }
        } else {
            emptyStage
        }
    }

    @ViewBuilder
    private func taskStage(_ rec: RecommendedTask) -> some View {
        let task = rec.task
        let category = FocusAnalytics.primaryCategory(tags: task.tags)
        let loggedSeconds = pomodoro.sessions
            .filter { $0.kind == .focus && $0.taskId == task.id }
            .reduce(0) { $0 + $1.actualSeconds }
        let categorySuggestion = suggestedMinutes(for: category)

        VStack(alignment: .leading, spacing: compact ? 10 : 16) {
            HStack(spacing: 6) {
                Circle()
                    .fill(reasonColor(rec.reason))
                    .frame(width: 6, height: 6)

                Text(rec.reason.localizedLabel(for: lang))
                    .font(.system(size: compact ? 10.5 : 12, weight: .semibold))
                    .foregroundColor(reasonColor(rec.reason))

                if !category.isEmpty {
                    Text("· #\(category)")
                        .font(.system(size: compact ? 10.5 : 12))
                        .foregroundColor(.secondary)
                }

                if loggedSeconds > 0 {
                    Text("· \(FocusDurationFormat.human(loggedSeconds, lang: lang))")
                        .font(.system(size: compact ? 10.5 : 12))
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            Text(task.title)
                .font(.system(size: compact ? 15 : 22, weight: .semibold))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if let due = task.dueDate, !due.isEmpty, case .highPriority = rec.reason {
                Text(String(due.prefix(10)))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            if !task.subtasks.isEmpty {
                TaskSubtaskChecklist(store: store, task: task, compact: compact)
                    .padding(.top, 2)
            }

            if let suggested = categorySuggestion, !category.isEmpty {
                Button(action: { pomodoro.focusMinutes = suggested }) {
                    Text(isTh
                         ? "สถิติ #\(category) แนะนำ \(suggested) น. · ใช้เลย"
                         : "#\(category) insights suggest \(suggested)m · Apply")
                        .font(.system(size: 11))
                        .foregroundColor(.accentColor.opacity(0.9))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: compact ? 8 : 10) {
                Button(action: { pomodoro.startFocus(task: task) }) {
                    HStack(spacing: 5) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                        Text(isTh ? "เริ่มทำ" : "Start")
                            .font(.system(size: compact ? 11.5 : 12.5, weight: .semibold))
                    }
                    .padding(.horizontal, compact ? 9 : 12)
                    .padding(.vertical, compact ? 5 : 7)
                    .background(Color.accentColor.opacity(0.14))
                    .foregroundColor(.accentColor)
                    .cornerRadius(7)
                }
                .buttonStyle(.plain)

                Button(action: {
                    pomodoro.detachTask(id: task.id)
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        store.toggleTask(id: task.id)
                    }
                }) {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10.5, weight: .semibold))
                        Text(isTh ? "เสร็จแล้ว" : "Done")
                            .font(.system(size: compact ? 11.5 : 12.5, weight: .medium))
                    }
                    .padding(.horizontal, compact ? 9 : 12)
                    .padding(.vertical, compact ? 5 : 7)
                    .background(Color.green.opacity(0.14))
                    .foregroundColor(.green)
                    .cornerRadius(7)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, compact ? 2 : 6)
        }
    }

    private var emptyStage: some View {
        VStack(spacing: compact ? 8 : 12) {
            if !compact { Spacer() }

            Image(systemName: "checkmark.circle")
                .font(.system(size: compact ? 22 : 28, weight: .light))
                .foregroundColor(.secondary.opacity(0.5))

            Text(isTh ? "ไม่มีงานค้างแล้ว" : "All caught up")
                .font(.system(size: compact ? 13 : 16, weight: .medium))
                .foregroundColor(.primary.opacity(0.85))

            Text(isTh ? "เพิ่มงานใหม่เมื่อพร้อมลุยต่อ" : "Add a task whenever you are ready")
                .font(.system(size: compact ? 11 : 12))
                .foregroundColor(.secondary)

            QuickInputBar(store: store)
                .frame(maxWidth: compact ? .infinity : 360)
                .padding(.top, compact ? 4 : 8)

            if !compact { Spacer() }
        }
        .padding(.horizontal, compact ? 14 : 36)
        .padding(.vertical, compact ? 16 : 24)
        .frame(maxWidth: .infinity, maxHeight: compact ? nil : .infinity)
    }

    private func suggestedMinutes(for category: String) -> Int? {
        guard !category.isEmpty else { return nil }
        guard let summary = pomodoro.categorySummaries(tasks: store.tasks).first(where: { $0.id == category }),
              summary.calibration != .wellCalibrated,
              summary.suggestedMinutes != pomodoro.focusMinutes else {
            return nil
        }
        return summary.suggestedMinutes
    }

    private func reasonColor(_ reason: TaskUrgencyReason) -> Color {
        switch reason {
        case .urgent, .overdue: return .orange
        case .highPriority: return .orange.opacity(0.85)
        case .dueToday, .nextUp: return .secondary
        }
    }
}

public struct FocusModeView: View {
    @ObservedObject var store: TaskStore
    @ObservedObject var pomodoro: PomodoroManager
    @ObservedObject var langManager: LanguageManager = .shared
    let compact: Bool
    let onOpenMainWindow: (() -> Void)?

    public init(
        store: TaskStore,
        pomodoro: PomodoroManager? = nil,
        compact: Bool = false,
        onOpenMainWindow: (() -> Void)? = nil
    ) {
        self.store = store
        self.pomodoro = pomodoro ?? .shared
        self.compact = compact
        self.onOpenMainWindow = onOpenMainWindow
    }

    private var isTh: Bool { langManager.currentLanguage == .th }
    private var isBreak: Bool { pomodoro.activeKind == .breakTime }

    private var statusColor: Color {
        if pomodoro.isOvertime { return .orange }
        return isBreak ? .green : .accentColor
    }

    private var phaseLabel: String {
        if isBreak { return langManager.text(.breakLabel) }
        return pomodoro.isOvertime ? langManager.text(.overtimeLabel) : langManager.text(.focusLabel)
    }

    private var boundTask: TaskItem? {
        guard let id = pomodoro.state.session?.taskId else { return nil }
        return store.tasks.first { $0.id == id && !$0.isCompleted }
    }

    public var body: some View {
        if compact {
            compactBody
                .padding(16)
        } else {
            VStack {
                Spacer()
                expandedBody
                    .frame(maxWidth: 460)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(36)
        }
    }

    private var expandedBody: some View {
        VStack(spacing: 22) {
            VStack(spacing: 14) {
                TimerClockFace(
                    progress: pomodoro.progress,
                    elapsedSeconds: pomodoro.elapsedSeconds,
                    color: statusColor,
                    size: 96,
                    isPaused: pomodoro.isPaused
                )

                Text(pomodoro.primaryClockDisplay)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(pomodoro.isOvertime ? .orange : .primary)

                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    Text(phaseLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(pomodoro.isOvertime ? .orange : .secondary)
                    if pomodoro.isPaused {
                        Text("· \(langManager.text(.pause))")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }

            if isBreak {
                VStack(spacing: 6) {
                    Text(isTh ? "พักสายตาสักครู่" : "Take a short breather")
                        .font(.system(size: 20, weight: .semibold))
                    if let title = pomodoro.state.session?.taskTitle {
                        Text(isTh ? "งานถัดไป · \(title)" : "Next · \(title)")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .multilineTextAlignment(.center)
            } else {
                VStack(spacing: 12) {
                    Text(boundTask?.title ?? pomodoro.state.session?.taskTitle ?? (isTh ? "โฟกัสอิสระ" : "Free Focus"))
                        .font(.system(size: 22, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    if let task = boundTask {
                        let cat = FocusAnalytics.primaryCategory(tags: task.tags)
                        if !cat.isEmpty {
                            Text("#\(cat)")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        if !task.subtasks.isEmpty {
                            TaskSubtaskChecklist(store: store, task: task, compact: false)
                                .frame(maxWidth: 360)
                                .padding(.top, 4)
                        }
                    }
                }
            }

            controlsRow(compact: false)
                .padding(.top, 4)
        }
    }

    private var compactBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                Text(phaseLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(pomodoro.isOvertime ? .orange : .secondary)
                Spacer()
                if let onOpenMainWindow {
                    Button(action: onOpenMainWindow) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(langManager.text(.openMainWindow))
                }
            }

            HStack(spacing: 12) {
                TimerClockFace(
                    progress: pomodoro.progress,
                    elapsedSeconds: pomodoro.elapsedSeconds,
                    color: statusColor,
                    size: 46,
                    isPaused: pomodoro.isPaused
                )

                Text(pomodoro.primaryClockDisplay)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(pomodoro.isOvertime ? .orange : .primary)

                Spacer()
            }

            if isBreak {
                Text(isTh ? "พักสายตาสักครู่" : "Take a short breather")
                    .font(.system(size: 14, weight: .semibold))
            } else {
                Text(boundTask?.title ?? pomodoro.state.session?.taskTitle ?? (isTh ? "โฟกัสอิสระ" : "Free Focus"))
                    .font(.system(size: 14.5, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)

                if let task = boundTask, !task.subtasks.isEmpty {
                    TaskSubtaskChecklist(store: store, task: task, compact: true)
                }
            }

            controlsRow(compact: true)
        }
    }

    @ViewBuilder
    private func controlsRow(compact: Bool) -> some View {
        HStack(spacing: compact ? 8 : 10) {
            Button(action: { pomodoro.togglePause() }) {
                HStack(spacing: 4) {
                    Image(systemName: pomodoro.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 10))
                    if !compact {
                        Text(pomodoro.isPaused ? langManager.text(.resume) : langManager.text(.pause))
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .padding(.horizontal, compact ? 9 : 12)
                .padding(.vertical, compact ? 6 : 7)
                .background(Color.secondary.opacity(0.14))
                .foregroundColor(.primary)
                .cornerRadius(7)
            }
            .buttonStyle(.plain)
            .help(pomodoro.isPaused ? langManager.text(.resume) : langManager.text(.pause))

            Button(action: { isBreak ? pomodoro.startFocus() : pomodoro.startBreak() }) {
                Text(langManager.text(isBreak ? .backToWork : .takeBreak))
                    .font(.system(size: compact ? 11.5 : 12, weight: .semibold))
                    .padding(.horizontal, compact ? 10 : 13)
                    .padding(.vertical, compact ? 6 : 7)
                    .background((isBreak ? Color.accentColor : Color.orange).opacity(0.15))
                    .foregroundColor(isBreak ? .accentColor : .orange)
                    .cornerRadius(7)
            }
            .buttonStyle(.plain)

            if !isBreak, let task = boundTask {
                Button(action: {
                    pomodoro.detachTask(id: task.id)
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        store.toggleTask(id: task.id)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .semibold))
                        Text(isTh ? "เสร็จแล้ว" : "Done")
                            .font(.system(size: compact ? 11.5 : 12, weight: .medium))
                    }
                    .padding(.horizontal, compact ? 10 : 13)
                    .padding(.vertical, compact ? 6 : 7)
                    .background(Color.green.opacity(0.15))
                    .foregroundColor(.green)
                    .cornerRadius(7)
                }
                .buttonStyle(.plain)
            }

            Button(action: { pomodoro.stopAndSave() }) {
                HStack(spacing: 4) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 9))
                    Text(langManager.text(.finishSave))
                        .font(.system(size: compact ? 11.5 : 12, weight: .medium))
                }
                .padding(.horizontal, compact ? 9 : 12)
                .padding(.vertical, compact ? 6 : 7)
                .background(Color.secondary.opacity(0.1))
                .foregroundColor(.secondary)
                .cornerRadius(7)
            }
            .buttonStyle(.plain)
        }
    }
}
