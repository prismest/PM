import Foundation

public enum CompletedTimeBucket: String, CaseIterable, Identifiable {
    case today
    case thisWeek
    case earlier

    public var id: String { rawValue }

    public func localizedTitle(for lang: AppLanguage) -> String {
        switch self {
        case .today: return lang == .th ? "วันนี้" : "Today"
        case .thisWeek: return lang == .th ? "สัปดาห์นี้" : "This Week"
        case .earlier: return lang == .th ? "ก่อนหน้านี้" : "Earlier"
        }
    }
}

public struct CompletedTaskGroup: Identifiable {
    public let bucket: CompletedTimeBucket
    public let tasks: [TaskItem]

    public var id: CompletedTimeBucket { bucket }
}

public struct CompletedTasksGrouper {
    public static func parseDate(_ dateStr: String?) -> Date? {
        guard let str = dateStr, !str.isEmpty else { return nil }
        let fracFormatter = ISO8601DateFormatter()
        fracFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fracFormatter.date(from: str) ?? ISO8601DateFormatter().date(from: str)
    }

    public static func bucket(for date: Date, now: Date = Date(), calendar: Calendar = .current) -> CompletedTimeBucket {
        if calendar.isDate(date, inSameDayAs: now) {
            return .today
        }

        let nowWeek = calendar.component(.weekOfYear, from: now)
        let dateWeek = calendar.component(.weekOfYear, from: date)
        let nowYear = calendar.component(.yearForWeekOfYear, from: now)
        let dateYear = calendar.component(.yearForWeekOfYear, from: date)

        if nowYear == dateYear && nowWeek == dateWeek && date <= now {
            return .thisWeek
        }

        return .earlier
    }

    public static func group(
        tasks: [TaskItem],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [CompletedTaskGroup] {
        let completed = tasks.filter(\.isCompleted)
        guard !completed.isEmpty else { return [] }

        var bucketMap: [CompletedTimeBucket: [(date: Date, task: TaskItem)]] = [
            .today: [],
            .thisWeek: [],
            .earlier: []
        ]

        for task in completed {
            let taskDate = parseDate(task.completedAt) ?? parseDate(task.createdAt) ?? .distantPast
            let b = bucket(for: taskDate, now: now, calendar: calendar)
            bucketMap[b, default: []].append((date: taskDate, task: task))
        }

        var groups: [CompletedTaskGroup] = []
        for b in CompletedTimeBucket.allCases {
            guard let items = bucketMap[b], !items.isEmpty else { continue }
            let sortedTasks = items
                .sorted { $0.date > $1.date }
                .map { $0.task }
            groups.append(CompletedTaskGroup(bucket: b, tasks: sortedTasks))
        }

        return groups
    }

    public static func formatCompletedTime(
        _ raw: String?,
        lang: AppLanguage,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String? {
        guard let date = parseDate(raw) else { return nil }
        let isTh = lang == .th

        if calendar.isDate(date, inSameDayAs: now) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return (isTh ? "เสร็จ " : "Done ") + formatter.string(from: date)
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isTh ? "th_TH" : "en_US")
        formatter.dateFormat = isTh ? "d MMM" : "MMM d"
        return (isTh ? "เสร็จ " : "Done ") + formatter.string(from: date)
    }
}
