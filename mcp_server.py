#!/usr/bin/env python3
"""
Waan - MCP Server (Model Context Protocol)
Zero-dependency stdio server for Claude Desktop, Cursor, and any MCP-compatible AI Harness.
"""
import sys
import json
import os
import sqlite3
import uuid
from datetime import datetime, date

DB_DIR = os.path.expanduser("~/Library/Application Support/Waan")
DB_PATH = os.path.join(DB_DIR, "tasks.db")

def get_db():
    os.makedirs(DB_DIR, exist_ok=True)
    conn = sqlite3.connect(DB_PATH, timeout=5.0)
    conn.execute("PRAGMA journal_mode=WAL;")
    conn.execute("""
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
    """)
    conn.commit()
    return conn

TARGET_DESC = "Task ID or search keyword in title"

TOOLS = [
    {
        "name": "waan_add_task",
        "description": "Add a new task to Waan on macOS with optional due date, priority, subtasks, and tags.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "title": {"type": "string", "description": "Title of the task"},
                "due_date": {"type": "string", "description": "Due date: 'today', 'tomorrow', or 'YYYY-MM-DD'"},
                "priority": {"type": "string", "enum": ["low", "normal", "high", "urgent"], "description": "Priority level"},
                "subtasks": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "List of subtask titles"
                },
                "tags": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "Tags such as ['work', 'design']"
                }
            },
            "required": ["title"]
        }
    },
    {
        "name": "waan_list_tasks",
        "description": "List all tasks from Waan on macOS.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "status": {"type": "string", "enum": ["pending", "completed", "all"], "description": "Filter by status (default: pending)"}
            }
        }
    },
    {
        "name": "waan_complete_task",
        "description": "Mark a task as completed (done).",
        "inputSchema": {
            "type": "object",
            "properties": {
                "target": {"type": "string", "description": TARGET_DESC}
            },
            "required": ["target"]
        }
    },
    {
        "name": "waan_breakdown_task",
        "description": "Break down an existing task by adding subtasks.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "target": {"type": "string", "description": TARGET_DESC},
                "subtasks": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "List of subtask titles to add"
                }
            },
            "required": ["target", "subtasks"]
        }
    },
    {
        "name": "waan_delete_task",
        "description": "Delete a task from Waan.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "target": {"type": "string", "description": TARGET_DESC}
            },
            "required": ["target"]
        }
    }
]

def tool_add_task(cursor, args):
    title = args.get("title")
    today_val = date.today()
    due_map = {"today": today_val.isoformat(), "tomorrow": date.fromordinal(today_val.toordinal() + 1).isoformat()}
    due = due_map.get(args.get("due_date"), args.get("due_date"))

    priority = args.get("priority", "normal")
    subtasks_raw = args.get("subtasks", [])
    subtasks = [{"id": str(uuid.uuid4()), "title": s, "isDone": False} for s in subtasks_raw]
    tags = args.get("tags", [])

    task_id = str(uuid.uuid4())
    created_at = datetime.now().isoformat()

    cursor.execute("""
    INSERT INTO tasks (id, title, due_date, priority, status, subtasks_json, tags_json, created_at)
    VALUES (?, ?, ?, ?, 'pending', ?, ?, ?)
    """, (task_id, title, due, priority, json.dumps(subtasks, ensure_ascii=False), json.dumps(tags, ensure_ascii=False), created_at))
    return f"Task added: '{title}' (ID: {task_id[:8]}...)"

def tool_list_tasks(cursor, args):
    status = args.get("status", "pending")
    if status == "all":
        cursor.execute("SELECT id, title, due_date, priority, status, subtasks_json, tags_json FROM tasks ORDER BY created_at DESC")
    else:
        cursor.execute("SELECT id, title, due_date, priority, status, subtasks_json, tags_json FROM tasks WHERE status = ? ORDER BY created_at DESC", (status,))
    
    rows = cursor.fetchall()
    tasks = []
    for r in rows:
        tasks.append({
            "id": r[0],
            "title": r[1],
            "due_date": r[2],
            "priority": r[3],
            "status": r[4],
            "subtasks": json.loads(r[5] or "[]"),
            "tags": json.loads(r[6] or "[]")
        })
    return json.dumps(tasks, ensure_ascii=False, indent=2)

def tool_complete_task(cursor, args):
    target = args.get("target")
    cursor.execute("SELECT id, title FROM tasks WHERE id = ? OR title LIKE ? LIMIT 1", (target, f"%{target}%"))
    row = cursor.fetchone()
    if not row:
        return f"Task not found matching: {target}"
    task_id, title = row[0], row[1]
    completed_at = datetime.now().isoformat()
    cursor.execute("UPDATE tasks SET status='completed', completed_at=? WHERE id=?", (completed_at, task_id))
    return f"Task '{title}' marked as completed."

def tool_breakdown_task(cursor, args):
    target = args.get("target")
    new_subtasks = args.get("subtasks", [])
    cursor.execute("SELECT id, title, subtasks_json FROM tasks WHERE id = ? OR title LIKE ? LIMIT 1", (target, f"%{target}%"))
    row = cursor.fetchone()
    if not row:
        return f"Task not found matching: {target}"
    task_id, title, subtasks_json = row[0], row[1], row[2]
    current = json.loads(subtasks_json or "[]")
    current.extend({"id": str(uuid.uuid4()), "title": s, "isDone": False} for s in new_subtasks)
    cursor.execute("UPDATE tasks SET subtasks_json=? WHERE id=?", (json.dumps(current, ensure_ascii=False), task_id))
    return f"Added {len(new_subtasks)} subtasks to '{title}'."

def tool_delete_task(cursor, args):
    target = args.get("target")
    cursor.execute("SELECT id, title FROM tasks WHERE id = ? OR title LIKE ? LIMIT 1", (target, f"%{target}%"))
    row = cursor.fetchone()
    if not row:
        return f"Task not found matching: {target}"
    task_id, title = row[0], row[1]
    cursor.execute("DELETE FROM tasks WHERE id=?", (task_id,))
    return f"Task '{title}' deleted."

TOOL_HANDLERS = {
    "waan_add_task": tool_add_task,
    "waan_list_tasks": tool_list_tasks,
    "waan_complete_task": tool_complete_task,
    "waan_breakdown_task": tool_breakdown_task,
    "waan_delete_task": tool_delete_task,
}

def handle_tool_call(name, args):
    handler = TOOL_HANDLERS.get(name)
    if not handler:
        return "Unknown tool"

    conn = get_db()
    cursor = conn.cursor()
    try:
        result = handler(cursor, args)
        conn.commit()
        return result
    finally:
        conn.close()

def main():
    while True:
        line = sys.stdin.readline()
        if not line:
            break
        try:
            req = json.loads(line)
        except Exception:
            continue

        method = req.get("method")
        msg_id = req.get("id")

        if method == "notifications/initialized":
            continue

        if method == "initialize":
            resp = {
                "jsonrpc": "2.0",
                "id": msg_id,
                "result": {
                    "protocolVersion": "2024-11-05",
                    "capabilities": {"tools": {}},
                    "serverInfo": {"name": "waan-mcp", "version": "1.0.0"}
                }
            }
            sys.stdout.write(json.dumps(resp) + "\n")
            sys.stdout.flush()

        elif method == "tools/list":
            resp = {
                "jsonrpc": "2.0",
                "id": msg_id,
                "result": {"tools": TOOLS}
            }
            sys.stdout.write(json.dumps(resp) + "\n")
            sys.stdout.flush()

        elif method == "tools/call":
            params = req.get("params", {})
            name = params.get("name")
            args = params.get("arguments", {})
            result_text = handle_tool_call(name, args)
            resp = {
                "jsonrpc": "2.0",
                "id": msg_id,
                "result": {
                    "content": [{"type": "text", "text": result_text}]
                }
            }
            sys.stdout.write(json.dumps(resp) + "\n")
            sys.stdout.flush()

if __name__ == "__main__":
    main()
