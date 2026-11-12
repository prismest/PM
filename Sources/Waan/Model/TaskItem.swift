import Foundation

public enum Priority: String, Codable, CaseIterable, Identifiable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    case urgent = "urgent"

    public var id: String { rawValue }

    public var displayName: String { rawValue.capitalized }

    public func localizedName(for lang: AppLanguage) -> String {
        switch self {
        case .low: return lang == .th ? "ต่ำ" : "Low"
        case .normal: return lang == .th ? "ปกติ" : "Normal"
        case .high: return lang == .th ? "สูง" : "High"
        case .urgent: return lang == .th ? "ด่วนมาก" : "Urgent"
        }
    }

}

public enum TaskStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case completed = "completed"
}

public struct SubtaskItem: Identifiable, Codable, Equatable {
    public var id: String
    public var title: String
    public var isDone: Bool

    public init(id: String = UUID().uuidString, title: String, isDone: Bool = false) {
        self.id = id
        self.title = title
        self.isDone = isDone
    }
}

public struct TaskItem: Identifiable, Codable, Equatable {
    public var id: String
    public var title: String
    public var dueDate: String?
    public var priority: Priority
    public var status: TaskStatus
    public var subtasks: [SubtaskItem]
    public var tags: [String]
    public var createdAt: String
    public var completedAt: String?

    public init(
        id: String = UUID().uuidString,
        title: String,
        dueDate: String? = nil,
        priority: Priority = .normal,
        status: TaskStatus = .pending,
        subtasks: [SubtaskItem] = [],
        tags: [String] = [],
        createdAt: String = ISO8601DateFormatter().string(from: Date()),
        completedAt: String? = nil
    ) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.priority = priority
        self.status = status
        self.subtasks = subtasks
        self.tags = tags
        self.createdAt = createdAt
        self.completedAt = completedAt
    }

    public var isCompleted: Bool { status == .completed }

    public var subtaskProgress: (done: Int, total: Int) {
        (subtasks.filter(\.isDone).count, subtasks.count)
    }
}

public enum TaskUrgencyReason: Equatable {
    case overdue(days: Int)
    case urgent
    case dueToday
    case highPriority
    case nextUp

    public func localizedLabel(for lang: AppLanguage) -> String {
        let isTh = lang == .th
        switch self {
        case .overdue(let days):
            if days <= 0 { return isTh ? "เลยกำหนด" : "Overdue" }
            return isTh ? "เลยกำหนด \(days) วัน" : "\(days)d overdue"
        case .urgent: return isTh ? "ด่วนมาก" : "Urgent"
        case .dueToday: return isTh ? "ครบกำหนดวันนี้" : "Due today"
        case .highPriority: return isTh ? "สำคัญสูง" : "High priority"
        case .nextUp: return isTh ? "งานที่ควรทำตอนนี้" : "Do next"
        }
    }
}

public struct RecommendedTask: Equatable {
    public let task: TaskItem
    public let reason: TaskUrgencyReason
}

public enum NextTaskRecommender {
    public static func recommend(
        from tasks: [TaskItem],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> RecommendedTask? {
        let pending = tasks.filter { !$0.isCompleted }
        guard !pending.isEmpty else { return nil }

        let todayStart = calendar.startOfDay(for: now)
        let ranked = pending.map { (task: $0, eval: evaluate($0, todayStart: todayStart, calendar: calendar)) }

        guard let best = ranked.max(by: { lhs, rhs in
            if lhs.eval.actionable != rhs.eval.actionable {
                return !lhs.eval.actionable && rhs.eval.actionable
            }
            if lhs.eval.score != rhs.eval.score {
                return lhs.eval.score < rhs.eval.score
            }
            let lDue = lhs.eval.dueStart ?? .distantFuture
            let rDue = rhs.eval.dueStart ?? .distantFuture
            return lDue != rDue ? lDue > rDue : lhs.task.createdAt > rhs.task.createdAt
        }) else {
            return nil
        }

        return RecommendedTask(task: best.task, reason: best.eval.reason)
    }

    private static func evaluate(
        _ task: TaskItem,
        todayStart: Date,
        calendar: Calendar
    ) -> (actionable: Bool, score: Int, reason: TaskUrgencyReason, dueStart: Date?) {
        let priorityScore: Int
        switch task.priority {
        case .urgent: priorityScore = 30
        case .high: priorityScore = 20
        case .normal: priorityScore = 10
        case .low: priorityScore = 0
        }

        let dueStart = parseDayStart(task.dueDate, calendar: calendar)
        let dayDelta = dueStart.flatMap { calendar.dateComponents([.day], from: $0, to: todayStart).day }

        let dueScore: Int
        let actionable: Bool
        if let delta = dayDelta {
            if delta > 0 {
                dueScore = 15 + min(delta, 5)
                actionable = true
            } else if delta == 0 {
                dueScore = 8
                actionable = true
            } else {
                dueScore = -15
                actionable = false
            }
        } else {
            dueScore = 4
            actionable = true
        }

        let reason: TaskUrgencyReason
        if task.priority == .urgent {
            reason = .urgent
        } else if let delta = dayDelta, delta > 0 {
            reason = .overdue(days: delta)
        } else if dayDelta == 0 {
            reason = .dueToday
        } else if task.priority == .high {
            reason = .highPriority
        } else {
            reason = .nextUp
        }

        return (actionable, priorityScore + dueScore, reason, dueStart)
    }

    private static func parseDayStart(_ raw: String?, calendar: Calendar) -> Date? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        if raw.count > 10 {
            let isoFrac = ISO8601DateFormatter()
            isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = isoFrac.date(from: raw) ?? ISO8601DateFormatter().date(from: raw) {
                return calendar.startOfDay(for: d)
            }
        }
        let prefix = String(raw.prefix(10))
        let df = DateFormatter()
        df.calendar = Calendar(identifier: .gregorian)
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = calendar.timeZone
        df.dateFormat = "yyyy-MM-dd"
        return df.date(from: prefix).map { calendar.startOfDay(for: $0) }
    }
}

