import Foundation
import SQLite3

public final class DatabaseManager: @unchecked Sendable {
    public static let shared = DatabaseManager()

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.waan.database", qos: .userInitiated)

    public let dbPath: String

    public convenience init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("Waan", isDirectory: true)

        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let fileUrl = dir.appendingPathComponent("tasks.db")

        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let dotPath = homeDir.appendingPathComponent(".waan")
        if !FileManager.default.fileExists(atPath: dotPath.path) {
            try? FileManager.default.createSymbolicLink(at: dotPath, withDestinationURL: dir)
        }

        self.init(dbPath: fileUrl.path)
    }

    public init(dbPath: String) {
        self.dbPath = dbPath
        openDatabase()
        createTable()
    }

    deinit {
        sqlite3_close(db)
    }

    private func openDatabase() {
        if sqlite3_open_v2(dbPath, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK {
            sqlite3_exec(db, "PRAGMA journal_mode=WAL;", nil, nil, nil)
            sqlite3_exec(db, "PRAGMA busy_timeout=5000;", nil, nil, nil)
        } else {
            print("Waan Error: Failed to open SQLite database at \(dbPath)")
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
        CREATE TABLE IF NOT EXISTS focus_sessions (
            id TEXT PRIMARY KEY,
            task_id TEXT,
            task_title TEXT NOT NULL,
            category TEXT DEFAULT '',
            priority TEXT DEFAULT 'normal',
            kind TEXT DEFAULT 'focus',
            planned_seconds INTEGER NOT NULL,
            actual_seconds INTEGER NOT NULL,
            started_at TEXT NOT NULL,
            ended_at TEXT NOT NULL
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

                    let dueDate = sqlite3_column_text(stmt, 2).map { String(cString: $0) }
                    let priority = Priority(rawValue: String(cString: sqlite3_column_text(stmt, 3))) ?? .normal
                    let status = TaskStatus(rawValue: String(cString: sqlite3_column_text(stmt, 4))) ?? .pending
                    let subtasksJson = String(cString: sqlite3_column_text(stmt, 5))
                    let subtasks = subtasksJson.data(using: .utf8).flatMap { try? JSONDecoder().decode([SubtaskItem].self, from: $0) } ?? []
                    let tagsJson = String(cString: sqlite3_column_text(stmt, 6))
                    let tags = tagsJson.data(using: .utf8).flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? []
                    let createdAt = String(cString: sqlite3_column_text(stmt, 7))
                    let completedAt = sqlite3_column_text(stmt, 8).map { String(cString: $0) }

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
                    print("Waan Error: Failed to insert task")
                }
            }
            sqlite3_finalize(stmt)
        }
    }

    public func toggleTask(id: String) {
        queue.sync {
            let sql = """
            UPDATE tasks
            SET status = CASE WHEN status = 'completed' THEN 'pending' ELSE 'completed' END,
                completed_at = CASE WHEN status = 'pending' THEN strftime('%Y-%m-%dT%H:%M:%SZ', 'now') ELSE NULL END
            WHERE id = ?;
            """
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (id as NSString).utf8String, -1, nil)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
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
            if let idx = subtasks.firstIndex(where: { $0.id == subtaskId }) {
                subtasks[idx].isDone.toggle()
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
    }

    private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    public func updateTaskTags(id: String, tags: [String]) {
        queue.sync {
            let tagsData = (try? JSONEncoder().encode(tags)) ?? Data("[]".utf8)
            let tagsStr = String(data: tagsData, encoding: .utf8) ?? "[]"
            let sql = "UPDATE tasks SET tags_json = ? WHERE id = ?;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, tagsStr, -1, sqliteTransient)
                sqlite3_bind_text(stmt, 2, id, -1, sqliteTransient)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }

    public func insertFocusSession(_ session: FocusSessionRecord) {
        queue.sync {
            let sql = """
            INSERT OR REPLACE INTO focus_sessions (id, task_id, task_title, category, priority, kind, planned_seconds, actual_seconds, started_at, ended_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, session.id, -1, sqliteTransient)
                if let taskId = session.taskId {
                    sqlite3_bind_text(stmt, 2, taskId, -1, sqliteTransient)
                } else {
                    sqlite3_bind_null(stmt, 2)
                }
                sqlite3_bind_text(stmt, 3, session.taskTitle, -1, sqliteTransient)
                sqlite3_bind_text(stmt, 4, session.category, -1, sqliteTransient)
                sqlite3_bind_text(stmt, 5, session.priority.rawValue, -1, sqliteTransient)
                sqlite3_bind_text(stmt, 6, session.kind.rawValue, -1, sqliteTransient)
                sqlite3_bind_int(stmt, 7, Int32(session.plannedSeconds))
                sqlite3_bind_int(stmt, 8, Int32(session.actualSeconds))
                sqlite3_bind_text(stmt, 9, session.startedAt, -1, sqliteTransient)
                sqlite3_bind_text(stmt, 10, session.endedAt, -1, sqliteTransient)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }

    public func fetchFocusSessions() -> [FocusSessionRecord] {
        return queue.sync {
            var records: [FocusSessionRecord] = []
            let sql = "SELECT id, task_id, task_title, category, priority, kind, planned_seconds, actual_seconds, started_at, ended_at FROM focus_sessions ORDER BY ended_at DESC;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                while sqlite3_step(stmt) == SQLITE_ROW {
                    let id = String(cString: sqlite3_column_text(stmt, 0))
                    let taskId = sqlite3_column_text(stmt, 1).map { String(cString: $0) }
                    let taskTitle = String(cString: sqlite3_column_text(stmt, 2))
                    let category = sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? ""
                    let priorityRaw = sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? "normal"
                    let kindRaw = sqlite3_column_text(stmt, 5).map { String(cString: $0) } ?? "focus"
                    let planned = Int(sqlite3_column_int(stmt, 6))
                    let actual = Int(sqlite3_column_int(stmt, 7))
                    let startedAt = String(cString: sqlite3_column_text(stmt, 8))
                    let endedAt = String(cString: sqlite3_column_text(stmt, 9))

                    records.append(FocusSessionRecord(
                        id: id,
                        taskId: taskId,
                        taskTitle: taskTitle,
                        category: category,
                        priority: Priority(rawValue: priorityRaw) ?? .normal,
                        kind: SessionKind(rawValue: kindRaw) ?? .focus,
                        plannedSeconds: planned,
                        actualSeconds: actual,
                        startedAt: startedAt,
                        endedAt: endedAt
                    ))
                }
            }
            sqlite3_finalize(stmt)
            return records
        }
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
    }
}

