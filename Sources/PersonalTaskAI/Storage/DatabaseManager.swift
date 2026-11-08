import Foundation
import SQLite3

public extension Notification.Name {
    static let tasksDatabaseDidChange = Notification.Name("tasksDatabaseDidChange")
}

public final class DatabaseManager: @unchecked Sendable {
    public static let shared = DatabaseManager()

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.personaltaskai.database", qos: .userInitiated)

    public let dbPath: String

    private init() {
        // Prepare storage directory at ~/Library/Application Support/PersonalTaskAI
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("PersonalTaskAI", isDirectory: true)

        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileUrl = dir.appendingPathComponent("tasks.db")
        self.dbPath = fileUrl.path

        // Create symlink ~/.personaltaskai -> ~/Library/Application Support/PersonalTaskAI for easy CLI/AI access
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let dotPath = homeDir.appendingPathComponent(".personaltaskai")
        if !FileManager.default.fileExists(atPath: dotPath.path) {
            try? FileManager.default.createSymbolicLink(at: dotPath, withDestinationURL: dir)
        }

        openDatabase()
        createTable()
    }

    deinit {
        if db != nil {
            sqlite3_close(db)
        }
    }

    private func openDatabase() {
        if sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK {
            // Enable WAL mode for high concurrency between Native App and AI Harness
            sqlite3_exec(db, "PRAGMA journal_mode=WAL;", nil, nil, nil)
            sqlite3_exec(db, "PRAGMA busy_timeout=5000;", nil, nil, nil)
        } else {
            print("ZenTask Error: Failed to open SQLite database at \(dbPath)")
        }
    }

    private func createTable() {
        let sql = """
        CREATE TABLE IF NOT EXISTS tasks (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            due_date TEXT,
            priority TEXT DEFAULT 'normal',
            status TEXT DEFAULT 'pending',
            subtasks_json TEXT DEFAULT '[]',
            tags_json TEXT DEFAULT '[]',
            created_at TEXT NOT NULL,
            completed_at TEXT
        );
        """
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    public func fetchAllTasks() -> [TaskItem] {
        return queue.sync {
            var tasks: [TaskItem] = []
            let sql = "SELECT id, title, due_date, priority, status, subtasks_json, tags_json, created_at, completed_at FROM tasks ORDER BY created_at DESC;"
            var stmt: OpaquePointer?

            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let id = String(cString: sqlite3_column_text(stmt, 0))
                    let title = String(cString: sqlite3_column_text(stmt, 1))

                    var dueDate: String? = nil
                    if let cStr = sqlite3_column_text(stmt, 2) {
                        dueDate = String(cString: cStr)
                    }

                    let priorityStr = String(cString: sqlite3_column_text(stmt, 3))
                    let priority = Priority(rawValue: priorityStr) ?? .normal

                    let statusStr = String(cString: sqlite3_column_text(stmt, 4))
                    let status = TaskStatus(rawValue: statusStr) ?? .pending

                    let subtasksJson = String(cString: sqlite3_column_text(stmt, 5))
                    var subtasks: [SubtaskItem] = []
                    if let data = subtasksJson.data(using: .utf8) {
                        subtasks = (try? JSONDecoder().decode([SubtaskItem].self, from: data)) ?? []
                    }

                    let tagsJson = String(cString: sqlite3_column_text(stmt, 6))
                    var tags: [String] = []
                    if let data = tagsJson.data(using: .utf8) {
                        tags = (try? JSONDecoder().decode([String].self, from: data)) ?? []
                    }

                    let createdAt = String(cString: sqlite3_column_text(stmt, 7))

                    var completedAt: String? = nil
                    if let cStr = sqlite3_column_text(stmt, 8) {
                        completedAt = String(cString: cStr)
                    }

                    let task = TaskItem(
                        id: id,
                        title: title,
                        dueDate: dueDate,
                        priority: priority,
                        status: status,
                        subtasks: subtasks,
                        tags: tags,
                        createdAt: createdAt,
                        completedAt: completedAt
                    )
                    tasks.append(task)
                }
            }
            sqlite3_finalize(stmt)
            return tasks
        }
    }

    public func insert(task: TaskItem) {
        queue.sync {
            let sql = """
            INSERT OR REPLACE INTO tasks (id, title, due_date, priority, status, subtasks_json, tags_json, created_at, completed_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
            var stmt: OpaquePointer?

            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (task.id as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (task.title as NSString).utf8String, -1, nil)

                if let due = task.dueDate {
                    sqlite3_bind_text(stmt, 3, (due as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 3)
                }

                sqlite3_bind_text(stmt, 4, (task.priority.rawValue as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 5, (task.status.rawValue as NSString).utf8String, -1, nil)

                let subtasksData = (try? JSONEncoder().encode(task.subtasks)) ?? Data("[]".utf8)
                let subtasksStr = String(data: subtasksData, encoding: .utf8) ?? "[]"
                sqlite3_bind_text(stmt, 6, (subtasksStr as NSString).utf8String, -1, nil)

                let tagsData = (try? JSONEncoder().encode(task.tags)) ?? Data("[]".utf8)
                let tagsStr = String(data: tagsData, encoding: .utf8) ?? "[]"
                sqlite3_bind_text(stmt, 7, (tagsStr as NSString).utf8String, -1, nil)

                sqlite3_bind_text(stmt, 8, (task.createdAt as NSString).utf8String, -1, nil)

                if let comp = task.completedAt {
                    sqlite3_bind_text(stmt, 9, (comp as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 9)
                }

                if sqlite3_step(stmt) != SQLITE_DONE {
                    print("ZenTask Error: Failed to insert task")
                }
            }
            sqlite3_finalize(stmt)
        }
        notifyChange()
    }

    public func toggleTask(id: String) {
        queue.sync {
            var currentStatus = TaskStatus.pending
            var currentCompletedAt: String? = nil

            let selectSql = "SELECT status FROM tasks WHERE id = ? LIMIT 1;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, selectSql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)
                if sqlite3_step(stmt) == SQLITE_ROW {
                    let str = String(cString: sqlite3_column_text(stmt, 0))
                    currentStatus = TaskStatus(rawValue: str) ?? .pending
                }
            }
            sqlite3_finalize(stmt)

            let newStatus: TaskStatus = (currentStatus == .pending) ? .completed : .pending
            if newStatus == .completed {
                currentCompletedAt = ISO8601DateFormatter().string(from: Date())
            }

            let updateSql = "UPDATE tasks SET status = ?, completed_at = ? WHERE id = ?;"
            if sqlite3_prepare_v2(db, updateSql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (newStatus.rawValue as NSString).utf8String, -1, nil)
                if let comp = currentCompletedAt {
                    sqlite3_bind_text(stmt, 2, (comp as NSString).utf8String, -1, nil)
                } else {
                    sqlite3_bind_null(stmt, 2)
                }
                sqlite3_bind_text(stmt, 3, (id as NSString).utf8String, -1, nil)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
        notifyChange()
    }

    public func toggleSubtask(taskId: String, subtaskId: String) {
        queue.sync {
            let selectSql = "SELECT subtasks_json FROM tasks WHERE id = ? LIMIT 1;"
            var stmt: OpaquePointer?
            var subtasks: [SubtaskItem] = []

            if sqlite3_prepare_v2(db, selectSql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (taskId as NSString).utf8String, -1, nil)
                if sqlite3_step(stmt) == SQLITE_ROW {
                    let json = String(cString: sqlite3_column_text(stmt, 0))
                    if let data = json.data(using: .utf8) {
                        subtasks = (try? JSONDecoder().decode([SubtaskItem].self, from: data)) ?? []
                    }
                }
            }
            sqlite3_finalize(stmt)

            for i in 0..<subtasks.count {
                if subtasks[i].id == subtaskId {
                    subtasks[i].isDone.toggle()
                    break
                }
            }

            let subtasksData = (try? JSONEncoder().encode(subtasks)) ?? Data("[]".utf8)
            let subtasksStr = String(data: subtasksData, encoding: .utf8) ?? "[]"

            let updateSql = "UPDATE tasks SET subtasks_json = ? WHERE id = ?;"
            if sqlite3_prepare_v2(db, updateSql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (subtasksStr as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (taskId as NSString).utf8String, -1, nil)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
        notifyChange()
    }

    public func delete(id: String) {
        queue.sync {
            let sql = "DELETE FROM tasks WHERE id = ?;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
        notifyChange()
    }

    private func notifyChange() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .tasksDatabaseDidChange, object: nil)
        }
    }
}

