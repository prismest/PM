import SwiftUI
import Combine

public enum FilterType: String, CaseIterable, Identifiable {
    case all = "ทั้งหมด"
    case today = "วันนี้"
    case pending = "ที่ยังไม่เสร็จ"
    case highPriority = "สำคัญมาก"
    case completed = "เสร็จแล้ว"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .all: return "tray.full.fill"
        case .today: return "sun.max.fill"
        case .pending: return "circle"
        case .highPriority: return "exclamationmark.triangle.fill"
        case .completed: return "checkmark.circle.fill"
        }
    }
}

@MainActor
public final class TaskStore: ObservableObject {
    public static let shared = TaskStore()

    @Published public var tasks: [TaskItem] = []
    @Published public var selectedFilter: FilterType = .today
    @Published public var searchText: String = ""

    private let db = DatabaseManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var fileWatcher: FileWatcher?

    public init() {
        reloadTasks()

        // Listen for internal app changes
        NotificationCenter.default.publisher(for: .tasksDatabaseDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reloadTasks()
            }
            .store(in: &cancellables)

        // Watch for external AI Harness / CLI updates to tasks.db
        fileWatcher = FileWatcher(filePath: db.dbPath) { [weak self] in
            DispatchQueue.main.async {
                self?.reloadTasks()
            }
        }
    }

    public func reloadTasks() {
        self.tasks = db.fetchAllTasks()
    }

    public var filteredTasks: [TaskItem] {
        var result = tasks

        // Search text filter
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(query) ||
                $0.subtasks.contains(where: { $0.title.lowercased().contains(query) }) ||
                $0.tags.contains(where: { $0.lowercased().contains(query) })
            }
        }

        // Category filter
        switch selectedFilter {
        case .all:
            return result
        case .today:
            let todayStr = String(ISO8601DateFormatter().string(from: Date()).prefix(10))
            return result.filter { task in
                if task.isCompleted { return false }
                guard let due = task.dueDate else { return true } // Tasks without date count as today/inbox
                return due.starts(with: todayStr) || task.priority == .urgent
            }
        case .pending:
            return result.filter { !$0.isCompleted }
        case .highPriority:
            return result.filter { !$0.isCompleted && ($0.priority == .high || $0.priority == .urgent) }
        case .completed:
            return result.filter { $0.isCompleted }
        }
    }

    public var todayTasksCount: Int {
        let todayStr = String(ISO8601DateFormatter().string(from: Date()).prefix(10))
        return tasks.filter { task in
            !task.isCompleted && ((task.dueDate?.starts(with: todayStr) ?? true) || task.priority == .urgent)
        }.count
    }

    public func addTask(
        title: String,
        dueDate: String? = nil,
        priority: Priority = .normal,
        subtasks: [String] = [],
        tags: [String] = []
    ) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let subtaskItems = subtasks.map { SubtaskItem(title: $0) }
        let task = TaskItem(
            title: trimmed,
            dueDate: dueDate,
            priority: priority,
            subtasks: subtaskItems,
            tags: tags
        )
        db.insert(task: task)
        reloadTasks()
    }

    public func toggleTask(id: String) {
        db.toggleTask(id: id)
        reloadTasks()
    }

    public func toggleSubtask(taskId: String, subtaskId: String) {
        db.toggleSubtask(taskId: taskId, subtaskId: subtaskId)
        reloadTasks()
    }

    public func deleteTask(id: String) {
        db.delete(id: id)
        reloadTasks()
    }
}

