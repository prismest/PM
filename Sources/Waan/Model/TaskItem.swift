import Foundation

public enum Priority: String, Codable, CaseIterable, Identifiable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    case urgent = "urgent"

    public var id: String { rawValue }

    public var displayName: String { rawValue.capitalized }

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

