#!/usr/bin/env python3
"""
ZenTask MCP Server (Model Context Protocol)
Zero-dependency stdio server for Claude Desktop, Cursor, and any MCP-compatible AI Harness.
"""
import sys
import json
import os
import sqlite3
import uuid
from datetime import datetime, date

DB_DIR = os.path.expanduser("~/Library/Application Support/ZenTask")
DB_PATH = os.path.join(DB_DIR, "tasks.db")

def get_db():
    os.makedirs(DB_DIR, exist_ok=True)
    conn = sqlite3.connect(DB_PATH, timeout=5.0)
    conn.execute("PRAGMA journal_mode=WAL;")
    return conn

TOOLS = [
    {
        "name": "zentask_add_task",
        "description": "เพิ่มงานใหม่ลงในแอป ZenTask บนเครื่อง Mac พร้อมกำหนดวันเวลา ความสำคัญ และข้อย่อย",
        "inputSchema": {
            "type": "object",
            "properties": {
                "title": {"type": "string", "description": "ชื่องาน"},
                "due_date": {"type": "string", "description": "วันกำหนดส่ง เช่น 'today', 'tomorrow', หรือ 'YYYY-MM-DD'"},
                "priority": {"type": "string", "enum": ["low", "normal", "high", "urgent"], "description": "ระดับความสำคัญ"},
                "subtasks": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "รายการขั้นตอนย่อย (subtasks)"
                },
                "tags": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "ป้ายกำกับ เช่น ['work', 'design']"
                }
            },
            "required": ["title"]
        }
    },
    {
        "name": "zentask_list_tasks",
        "description": "ดูรายการงานทั้งหมดใน ZenTask บนเครื่อง Mac",
        "inputSchema": {
            "type": "object",
            "properties": {
                "status": {"type": "string", "enum": ["pending", "completed", "all"], "description": "สถานะงานที่ต้องการดู (ค่าเริ่มต้น: pending)"}
            }
        }
    },
    {
        "name": "zentask_complete_task",
        "description": "ทำเครื่องหมายว่างานเสร็จสิ้นแล้ว (Done)",
        "inputSchema": {
            "type": "object",
            "properties": {
                "target": {"type": "string", "description": "ID ของงาน หรือคำค้นหาในชื่องาน"}
            },
            "required": ["target"]
        }
    },
    {
        "name": "zentask_breakdown_task",
        "description": "แตกงานที่มีอยู่ให้มีขั้นตอนย่อย (Subtasks)",
        "inputSchema": {
            "type": "object",
            "properties": {
                "target": {"type": "string", "description": "ID ของงาน หรือคำค้นหาในชื่องาน"},
                "subtasks": {
                    "type": "array",
                    "items": {"type": "string"},
                    "description": "ขั้นตอนย่อยที่ต้องการเพิ่ม"
                }
            },
            "required": ["target", "subtasks"]
        }
    },
    {
        "name": "zentask_delete_task",
        "description": "ลบงานออกจากระบบ",
        "inputSchema": {
            "type": "object",
            "properties": {
                "target": {"type": "string", "description": "ID ของงาน หรือคำค้นหาในชื่องาน"}
            },
            "required": ["target"]
        }
    }
]

def handle_tool_call(name, args):
    conn = get_db()
    cursor = conn.cursor()

    if name == "zentask_add_task":
        title = args.get("title")
        due = args.get("due_date")
        if due == "today":
            due = date.today().isoformat()
        elif due == "tomorrow":
            due = date.fromordinal(date.today().toordinal() + 1).isoformat()

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
        conn.commit()
        conn.close()
        return f"เพิ่มงาน '{title}' สำเร็จ (ID: {task_id[:8]}...)"

    elif name == "zentask_list_tasks":
        status = args.get("status", "pending")
        if status == "all":
            cursor.execute("SELECT id, title, due_date, priority, status, subtasks_json, tags_json FROM tasks ORDER BY created_at DESC")
        elif status == "completed":
            cursor.execute("SELECT id, title, due_date, priority, status, subtasks_json, tags_json FROM tasks WHERE status='completed' ORDER BY created_at DESC")
        else:
            cursor.execute("SELECT id, title, due_date, priority, status, subtasks_json, tags_json FROM tasks WHERE status='pending' ORDER BY created_at DESC")
        
        rows = cursor.fetchall()
        conn.close()
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

    elif name == "zentask_complete_task":
        target = args.get("target")
        cursor.execute("SELECT id, title FROM tasks WHERE id = ? OR title LIKE ? LIMIT 1", (target, f"%{target}%"))
        row = cursor.fetchone()
        if not row:
            conn.close()
            return f"ไม่พบงานที่ตรงกับ: {target}"
        task_id, title = row[0], row[1]
        completed_at = datetime.now().isoformat()
        cursor.execute("UPDATE tasks SET status='completed', completed_at=? WHERE id=?", (completed_at, task_id))
        conn.commit()
        conn.close()
        return f"งาน '{title}' ทำเครื่องหมายว่าเสร็จสิ้นแล้ว"

    elif name == "zentask_breakdown_task":
        target = args.get("target")
        new_subtasks = args.get("subtasks", [])
        cursor.execute("SELECT id, title, subtasks_json FROM tasks WHERE id = ? OR title LIKE ? LIMIT 1", (target, f"%{target}%"))
        row = cursor.fetchone()
        if not row:
            conn.close()
            return f"ไม่พบงาน: {target}"
        task_id, title, subtasks_json = row[0], row[1], row[2]
        current = json.loads(subtasks_json or "[]")
        for s in new_subtasks:
            current.append({"id": str(uuid.uuid4()), "title": s, "isDone": False})
        cursor.execute("UPDATE tasks SET subtasks_json=? WHERE id=?", (json.dumps(current, ensure_ascii=False), task_id))
        conn.commit()
        conn.close()
        return f"เพิ่มขั้นตอนย่อย {len(new_subtasks)} รายการลงในงาน '{title}' เรียบร้อย"

    elif name == "zentask_delete_task":
        target = args.get("target")
        cursor.execute("SELECT id, title FROM tasks WHERE id = ? OR title LIKE ? LIMIT 1", (target, f"%{target}%"))
        row = cursor.fetchone()
        if not row:
            conn.close()
            return f"ไม่พบงาน: {target}"
        task_id, title = row[0], row[1]
        cursor.execute("DELETE FROM tasks WHERE id=?", (task_id,))
        conn.commit()
        conn.close()
        return f"ลบงาน '{title}' เรียบร้อยแล้ว"

    conn.close()
    return "Unknown tool"

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

        if method == "initialize":
            resp = {
                "jsonrpc": "2.0",
                "id": msg_id,
                "result": {
                    "protocolVersion": "2024-11-05",
                    "capabilities": {"tools": {}},
                    "serverInfo": {"name": "zentask-mcp", "version": "1.0.0"}
                }
            }
            sys.stdout.write(json.dumps(resp) + "\n")
            sys.stdout.flush()

        elif method == "notifications/initialized":
            pass

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

