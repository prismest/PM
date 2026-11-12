import Foundation
import AppKit
import UserNotifications

@MainActor
public final class PomodoroManager: ObservableObject {
    public static let shared = PomodoroManager()

    @Published public var focusMinutes: Int {
        didSet {
            let clamped = min(max(focusMinutes, 1), 180)
            if focusMinutes != clamped { focusMinutes = clamped; return }
            defaults.set(clamped, forKey: "waan_pomodoro_focus_minutes")
        }
    }

    @Published public var breakMinutes: Int {
        didSet {
            let clamped = min(max(breakMinutes, 1), 60)
            if breakMinutes != clamped { breakMinutes = clamped; return }
            defaults.set(clamped, forKey: "waan_pomodoro_break_minutes")
        }
    }

    @Published public private(set) var state: TimerRunState = .idle
    @Published public private(set) var now: Date = Date()
    @Published public private(set) var sessions: [FocusSessionRecord] = []
    @Published public var selectedTask: TaskItem? = nil

    public var minimumRecordedSeconds: Int = 5

    private let db: DatabaseManager
    private let defaults: UserDefaults
    private let enableNotifications: Bool
    private var timer: Timer?
    private var requestedNotificationAuth = false

    private let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.timeZone = .current
        return f
    }()

    public init(
        db: DatabaseManager = .shared,
        defaults: UserDefaults = .standard,
        enableNotifications: Bool = true
    ) {
        self.db = db
        self.defaults = defaults
        self.enableNotifications = enableNotifications

        let savedFocus = defaults.integer(forKey: "waan_pomodoro_focus_minutes")
        let savedBreak = defaults.integer(forKey: "waan_pomodoro_break_minutes")
        self.focusMinutes = savedFocus > 0 ? min(savedFocus, 180) : 25
        self.breakMinutes = savedBreak > 0 ? min(savedBreak, 60) : 5
        self.sessions = db.fetchFocusSessions()
    }

    public var isRunning: Bool {
        if case .running = state { return true }
        return false
    }

    public var isPaused: Bool {
        if case .paused = state { return true }
        return false
    }

    public var activeKind: SessionKind? { state.session?.kind }
    public var elapsedSeconds: Int { state.elapsedSeconds(at: now) }
    public var plannedSeconds: Int { state.session?.plannedSeconds ?? (focusMinutes * 60) }
    public var remainingSeconds: Int { max(0, plannedSeconds - elapsedSeconds) }
    public var overtimeSeconds: Int { max(0, elapsedSeconds - plannedSeconds) }
    public var isOvertime: Bool { state != .idle && elapsedSeconds > plannedSeconds }

    public var progress: Double {
        guard state != .idle, plannedSeconds > 0 else { return 0 }
        return min(1.0, Double(elapsedSeconds) / Double(plannedSeconds))
    }

    public var primaryClockDisplay: String {
        guard state != .idle else {
            return FocusDurationFormat.clock(focusMinutes * 60)
        }
        return isOvertime
            ? "+\(FocusDurationFormat.clock(overtimeSeconds))"
            : FocusDurationFormat.clock(remainingSeconds)
    }

    public var menuBarText: String? {
        state == .idle ? nil : primaryClockDisplay
    }

    public var menuBarIconName: String {
        if case .paused = state {
            return "pause.circle.fill"
        }
        switch state.session?.kind {
        case .focus:
            return isOvertime ? "exclamationmark.circle.fill" : "timer"
        case .breakTime:
            return "cup.and.saucer.fill"
        case nil:
            return "sparkles.rectangle.stack"
        }
    }

    public var todayFocusSeconds: Int {
        let todayPrefix = String(isoFormatter.string(from: Date()).prefix(10))
        return sessions
            .filter { $0.kind == .focus && $0.endedAt.hasPrefix(todayPrefix) }
            .reduce(0) { $0 + $1.actualSeconds }
    }

    public func isFocusing(on taskId: String) -> Bool {
        guard let session = state.session, session.kind == .focus else { return false }
        return session.taskId == taskId
    }

    public func canFocus(on taskId: String) -> Bool {
        switch state {
        case .idle:
            return true
        case .running(let session, _), .paused(let session):
            if session.kind == .focus {
                return session.taskId == taskId
            }
            return session.taskId == nil || session.taskId == taskId
        }
    }

    public func startFocus(task: TaskItem? = nil, at currentTime: Date = Date()) {
        if let task {
            guard canFocus(on: task.id) else { return }
            if isFocusing(on: task.id) {
                togglePause(at: currentTime)
                return
            }
        } else if activeKind == .focus {
            return
        }

        let target = task ?? selectedTask
        if let target {
            selectedTask = target
        }
        beginSession(kind: .focus, target: target, plannedMinutes: focusMinutes, at: currentTime)
    }

    public func clearSelectedTask() {
        selectedTask = nil
    }

    public func detachTask(id: String) {
        if isFocusing(on: id) {
            stopAndSave()
        }
        if state == .idle && selectedTask?.id == id {
            clearSelectedTask()
        }
    }

    public func togglePause(at currentTime: Date = Date()) {
        switch state {
        case .idle:
            return
        case .running(var session, let resumedAt):
            session.accumulatedSeconds += max(0, Int(currentTime.timeIntervalSince(resumedAt)))
            state = .paused(session)
            now = currentTime
            stopTicker()
        case .paused(let session):
            state = .running(session, resumedAt: currentTime)
            now = currentTime
            startTicker()
        }
    }

    public func startBreak(at currentTime: Date = Date()) {
        beginSession(kind: .breakTime, target: selectedTask, plannedMinutes: breakMinutes, at: currentTime)
    }

    private func beginSession(kind: SessionKind, target: TaskItem?, plannedMinutes: Int, at currentTime: Date) {
        if state != .idle {
            persistActiveSessionIfNeeded(at: currentTime, minSeconds: minimumRecordedSeconds)
        }
        let session = ActiveTimerSession(
            kind: kind,
            taskId: target?.id,
            taskTitle: target?.title,
            category: target.map { FocusAnalytics.primaryCategory(tags: $0.tags) } ?? "",
            priority: target?.priority ?? .normal,
            plannedSeconds: plannedMinutes * 60,
            originalStartDate: currentTime
        )
        state = .running(session, resumedAt: currentTime)
        now = currentTime
        ensureNotificationPermission()
        startTicker()
    }

    public func stopAndSave(minSeconds: Int? = nil, at currentTime: Date = Date()) {
        persistActiveSessionIfNeeded(at: currentTime, minSeconds: minSeconds ?? minimumRecordedSeconds)
        state = .idle
        stopTicker()
    }

    public func reloadSessions() {
        sessions = db.fetchFocusSessions()
    }

    public func categorySummaries(tasks: [TaskItem]) -> [CategoryTimeSummary] {
        FocusAnalytics.summarize(sessions: sessions, tasks: tasks)
    }

    public func tick(at currentTime: Date = Date()) {
        now = currentTime
        guard case .running(var session, let resumedAt) = state else { return }
        let elapsed = session.accumulatedSeconds + max(0, Int(currentTime.timeIntervalSince(resumedAt)))
        if !session.didNotifyTargetReached && elapsed >= session.plannedSeconds {
            session.didNotifyTargetReached = true
            state = .running(session, resumedAt: resumedAt)
            notifyTargetReached(session: session)
        }
    }

    private func persistActiveSessionIfNeeded(at currentTime: Date, minSeconds: Int) {
        guard let session = state.session else { return }
        let actual = state.elapsedSeconds(at: currentTime)
        guard actual >= minSeconds else { return }

        let fallbackTitle = LanguageManager.shared.currentLanguage == .th ? "โฟกัสอิสระ" : "Free Focus"
        let record = FocusSessionRecord(
            id: session.id,
            taskId: session.taskId,
            taskTitle: session.taskTitle ?? fallbackTitle,
            category: session.category,
            priority: session.priority,
            kind: session.kind,
            plannedSeconds: session.plannedSeconds,
            actualSeconds: actual,
            startedAt: isoFormatter.string(from: session.originalStartDate),
            endedAt: isoFormatter.string(from: currentTime)
        )
        db.insertFocusSession(record)
        reloadSessions()
    }

    private func startTicker() {
        stopTicker()
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick(at: Date())
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopTicker() {
        timer?.invalidate()
        timer = nil
    }

    private var isAppBundle: Bool {
        Bundle.main.bundleURL.pathExtension == "app" && Bundle.main.bundleIdentifier != nil
    }

    private func ensureNotificationPermission() {
        guard enableNotifications, !requestedNotificationAuth, isAppBundle else { return }
        requestedNotificationAuth = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func notifyTargetReached(session: ActiveTimerSession) {
        guard enableNotifications else { return }
        NSSound(named: NSSound.Name("Glass"))?.play()
        guard isAppBundle else { return }

        let isTh = LanguageManager.shared.currentLanguage == .th
        let mins = session.plannedSeconds / 60
        let content = UNMutableNotificationContent()
        if session.kind == .focus {
            content.title = isTh ? "ครบเวลาโฟกัส \(mins) นาทีแล้ว!" : "\(mins)m Focus Target Reached!"
            let taskPart = session.taskTitle.map { " (\($0))" } ?? ""
            content.body = isTh
                ? "กำลังจับเวลาต่อเนื่อง\(taskPart) กดพักได้เลยเมื่อพร้อม"
                : "Timer is still running\(taskPart). Take a break when ready."
        } else {
            content.title = isTh ? "หมดเวลาพัก \(mins) นาทีแล้ว" : "\(mins)m Break Finished"
            content.body = isTh ? "พร้อมกลับมาโฟกัสงานต่อแล้ว" : "Ready to jump back into focus."
        }
        content.sound = .default

        let req = UNNotificationRequest(identifier: "waan-timer-\(session.id)-\(session.kind.rawValue)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }
}
