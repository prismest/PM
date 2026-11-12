import Foundation

public enum SessionKind: String, Codable, CaseIterable {
    case focus
    case breakTime = "break"
}

public enum EstimationCalibration: String, Equatable {
    case underestimated
    case wellCalibrated
    case overestimated
}

public struct ActiveTimerSession: Equatable {
    public let id: String
    public let kind: SessionKind
    public let taskId: String?
    public let taskTitle: String?
    public let category: String
    public let priority: Priority
    public let plannedSeconds: Int
    public let originalStartDate: Date
    public var accumulatedSeconds: Int
    public var didNotifyTargetReached: Bool

    public init(
        id: String = UUID().uuidString,
        kind: SessionKind,
        taskId: String?,
        taskTitle: String?,
        category: String,
        priority: Priority,
        plannedSeconds: Int,
        originalStartDate: Date = Date(),
        accumulatedSeconds: Int = 0,
        didNotifyTargetReached: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.taskId = taskId
        self.taskTitle = taskTitle
        self.category = category
        self.priority = priority
        self.plannedSeconds = plannedSeconds
        self.originalStartDate = originalStartDate
        self.accumulatedSeconds = accumulatedSeconds
        self.didNotifyTargetReached = didNotifyTargetReached
    }
}

public enum TimerRunState: Equatable {
    case idle
    case running(ActiveTimerSession, resumedAt: Date)
    case paused(ActiveTimerSession)

    public var session: ActiveTimerSession? {
        switch self {
        case .idle: return nil
        case .running(let s, _), .paused(let s): return s
        }
    }

    public func elapsedSeconds(at now: Date = Date()) -> Int {
        switch self {
        case .idle:
            return 0
        case .running(let s, let resumedAt):
            return s.accumulatedSeconds + max(0, Int(now.timeIntervalSince(resumedAt)))
        case .paused(let s):
            return s.accumulatedSeconds
        }
    }
}

public struct FocusSessionRecord: Identifiable, Codable, Equatable {
    public let id: String
    public let taskId: String?
    public let taskTitle: String
    public let category: String
    public let priority: Priority
    public let kind: SessionKind
    public let plannedSeconds: Int
    public let actualSeconds: Int
    public let startedAt: String
    public let endedAt: String

    public init(
        id: String = UUID().uuidString,
        taskId: String?,
        taskTitle: String,
        category: String,
        priority: Priority = .normal,
        kind: SessionKind = .focus,
        plannedSeconds: Int,
        actualSeconds: Int,
        startedAt: String,
        endedAt: String
    ) {
        self.id = id
        self.taskId = taskId
        self.taskTitle = taskTitle
        self.category = category
        self.priority = priority
        self.kind = kind
        self.plannedSeconds = plannedSeconds
        self.actualSeconds = actualSeconds
        self.startedAt = startedAt
        self.endedAt = endedAt
    }
}

public struct TaskTimeSummary: Identifiable, Equatable {
    public let id: String
    public let taskTitle: String
    public let category: String
    public let totalActualSeconds: Int
    public let totalPlannedSeconds: Int
    public let sessionCount: Int
    public let calibration: EstimationCalibration
}

public struct CategoryTimeSummary: Identifiable, Equatable {
    public let id: String
    public let totalActualSeconds: Int
    public let totalPlannedSeconds: Int
    public let sessionCount: Int
    public let calibration: EstimationCalibration
    public let suggestedMinutes: Int
    public let tasks: [TaskTimeSummary]

    public var averageDeltaSeconds: Int {
        guard sessionCount > 0 else { return 0 }
        return (totalActualSeconds - totalPlannedSeconds) / sessionCount
    }

    public var averagePlannedMinutes: Int { avgMinutes(totalPlannedSeconds) }
    public var averageActualMinutes: Int { avgMinutes(totalActualSeconds) }

    private func avgMinutes(_ totalSeconds: Int) -> Int {
        guard sessionCount > 0 else { return 0 }
        return max(1, Int((Double(totalSeconds) / Double(sessionCount) / 60.0).rounded()))
    }
}

public enum FocusAnalytics {
    public static let presetCategories = ["dev", "design", "meeting", "study", "writing", "admin"]

    public static func primaryCategory(tags: [String]) -> String {
        tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.first(where: { !$0.isEmpty }) ?? ""
    }

    public static func displayCategory(_ raw: String, lang: AppLanguage) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return lang == .th ? "ทั่วไป" : "General"
        }
        return "#\(trimmed)"
    }

    public static func classify(plannedSeconds: Int, actualSeconds: Int, sessionCount: Int) -> EstimationCalibration {
        guard plannedSeconds > 0, sessionCount > 0 else { return .wellCalibrated }
        let delta = actualSeconds - plannedSeconds
        let avgDelta = delta / sessionCount
        let ratio = Double(actualSeconds) / Double(plannedSeconds)
        if (ratio >= 1.15 && delta >= 60) || avgDelta >= 180 {
            return .underestimated
        }
        if (ratio <= 0.85 && delta <= -60) || avgDelta <= -180 {
            return .overestimated
        }
        return .wellCalibrated
    }

    public static func suggestedMinutes(totalActualSeconds: Int, sessionCount: Int) -> Int {
        guard sessionCount > 0 else { return 25 }
        let avgMin = Double(totalActualSeconds) / Double(sessionCount) / 60.0
        if avgMin >= 5 {
            return max(5, Int((avgMin / 5.0).rounded()) * 5)
        }
        return max(1, Int(avgMin.rounded()))
    }

    public static func summarize(sessions: [FocusSessionRecord], tasks: [TaskItem]) -> [CategoryTimeSummary] {
        let tasksById = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
        let focusSessions = sessions.filter { $0.kind == .focus && $0.actualSeconds > 0 }

        struct TaskAcc {
            var title: String
            var actual = 0
            var planned = 0
            var count = 0
        }

        struct CategoryAcc {
            var actual = 0
            var planned = 0
            var count = 0
            var tasks: [String: TaskAcc] = [:]
        }

        var byCategory: [String: CategoryAcc] = [:]

        for s in focusSessions {
            let liveTask = s.taskId.flatMap { tasksById[$0] }
            let category = liveTask.map { primaryCategory(tags: $0.tags) } ?? s.category
            let title = liveTask?.title ?? s.taskTitle
            let taskKey = s.taskId ?? "free:\(title)"

            var catAcc = byCategory[category, default: CategoryAcc()]
            catAcc.actual += s.actualSeconds
            catAcc.planned += s.plannedSeconds
            catAcc.count += 1

            var tAcc = catAcc.tasks[taskKey, default: TaskAcc(title: title)]
            tAcc.actual += s.actualSeconds
            tAcc.planned += s.plannedSeconds
            tAcc.count += 1
            catAcc.tasks[taskKey] = tAcc

            byCategory[category] = catAcc
        }

        return byCategory.map { category, acc in
            let taskSummaries = acc.tasks.map { key, t in
                TaskTimeSummary(
                    id: key,
                    taskTitle: t.title,
                    category: category,
                    totalActualSeconds: t.actual,
                    totalPlannedSeconds: t.planned,
                    sessionCount: t.count,
                    calibration: classify(plannedSeconds: t.planned, actualSeconds: t.actual, sessionCount: t.count)
                )
            }.sorted { $0.totalActualSeconds > $1.totalActualSeconds }

            return CategoryTimeSummary(
                id: category,
                totalActualSeconds: acc.actual,
                totalPlannedSeconds: acc.planned,
                sessionCount: acc.count,
                calibration: classify(plannedSeconds: acc.planned, actualSeconds: acc.actual, sessionCount: acc.count),
                suggestedMinutes: suggestedMinutes(totalActualSeconds: acc.actual, sessionCount: acc.count),
                tasks: taskSummaries
            )
        }.sorted { $0.totalActualSeconds > $1.totalActualSeconds }
    }
}

public enum FocusDurationFormat {
    public static func clock(_ totalSeconds: Int) -> String {
        let s = max(0, totalSeconds)
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, sec)
        }
        return String(format: "%02d:%02d", m, sec)
    }

    public static func human(_ totalSeconds: Int, lang: AppLanguage) -> String {
        let s = max(0, totalSeconds)
        if s < 60 {
            return lang == .th ? "\(s) วิ" : "\(s)s"
        }
        let mins = s / 60
        let h = mins / 60
        let m = mins % 60
        if h > 0 {
            if m == 0 {
                return lang == .th ? "\(h) ชม." : "\(h)h"
            }
            return lang == .th ? "\(h) ชม. \(m) น." : "\(h)h \(m)m"
        }
        return lang == .th ? "\(m) น." : "\(m)m"
    }

    public static func signedDelta(_ deltaSeconds: Int, lang: AppLanguage) -> String {
        let sign = deltaSeconds >= 0 ? "+" : "-"
        return "\(sign)\(human(abs(deltaSeconds), lang: lang))"
    }
}

