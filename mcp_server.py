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
import signal
import argparse
import time
import urllib.parse
import http.server
from datetime import datetime, date

DB_DIR = os.path.expanduser("~/Library/Application Support/Waan")
DB_PATH = os.path.join(DB_DIR, "tasks.db")
STATUS_FILE = os.path.join(DB_DIR, "mcp_status.json")
JSON_CONTENT_TYPE = "application/json"

def get_mcp_status():
    if os.path.exists(STATUS_FILE):
        try:
            with open(STATUS_FILE, "r") as f:
                return json.load(f)
        except Exception:
            pass
    return {"enabled": True, "running": False, "port": 8765}

def set_mcp_status(enabled=True, running=False, port=8765, pid=None):
    os.makedirs(DB_DIR, exist_ok=True)
    status = {
        "enabled": bool(enabled),
        "running": bool(running),
        "port": int(port),
        "pid": pid,
        "updated_at": datetime.now().isoformat()
    }
    with open(STATUS_FILE, "w") as f:
        json.dump(status, f, indent=2)
    return status

def is_mcp_enabled():
    return get_mcp_status().get("enabled", True)

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

def process_jsonrpc_request(req):
    method = req.get("method")
    msg_id = req.get("id")

    if method == "notifications/initialized":
        return None

    if method == "ping":
        return {"jsonrpc": "2.0", "id": msg_id, "result": {}}

    if method == "initialize":
        return {
            "jsonrpc": "2.0",
            "id": msg_id,
            "result": {
                "protocolVersion": "2024-11-05",
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "waan-mcp", "version": "1.0.0"}
            }
        }

    if method == "tools/list":
        return {
            "jsonrpc": "2.0",
            "id": msg_id,
            "result": {"tools": TOOLS}
        }

    if method == "tools/call":
        if not is_mcp_enabled():
            return {
                "jsonrpc": "2.0",
                "id": msg_id,
                "result": {
                    "content": [{"type": "text", "text": "Waan MCP Server is currently turned OFF. Please toggle it ON in Waan."}],
                    "isError": True
                }
            }

        params = req.get("params", {})
        name = params.get("name")
        args = params.get("arguments", {})
        result_text = handle_tool_call(name, args)
        return {
            "jsonrpc": "2.0",
            "id": msg_id,
            "result": {
                "content": [{"type": "text", "text": result_text}]
            }
        }

    return {
        "jsonrpc": "2.0",
        "id": msg_id,
        "error": {"code": -32601, "message": f"Method not found: {method}"}
    }

class McpRequestHandler(http.server.BaseHTTPRequestHandler):
    def send_cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_cors_headers()
        self.end_headers()

    def do_HEAD(self):
        self.do_GET()

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path in ["/", "/status", "/health"]:
            status_data = {
                "status": "running" if is_mcp_enabled() else "disabled",
                "enabled": is_mcp_enabled(),
                "name": "waan-mcp",
                "version": "1.0.0",
                "tools_count": len(TOOLS),
                "tools": [t["name"] for t in TOOLS]
            }
            body = json.dumps(status_data, indent=2).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", JSON_CONTENT_TYPE)
            self.send_header("Content-Length", str(len(body)))
            self.send_cors_headers()
            self.end_headers()
            self.wfile.write(body)
        elif parsed.path == "/sse":
            session_id = str(uuid.uuid4())
            self.send_response(200)
            self.send_header("Content-Type", "text/event-stream")
            self.send_header("Cache-Control", "no-cache")
            self.send_header("Connection", "keep-alive")
            self.send_cors_headers()
            self.end_headers()

            host = self.headers.get("Host", "127.0.0.1:8765")
            proto = "https" if "ngrok" in host or self.headers.get("X-Forwarded-Proto") == "https" else "http"
            endpoint_url = f"{proto}://{host}/message?sessionId={session_id}"
            endpoint_msg = f"event: endpoint\r\ndata: {endpoint_url}\r\n\r\n"
            self.wfile.write(endpoint_msg.encode("utf-8"))
            self.wfile.flush()

            try:
                while True:
                    time.sleep(15)
                    self.wfile.write(b": keepalive\r\n\r\n")
                    self.wfile.flush()
            except Exception:
                pass
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        content_length = int(self.headers.get("Content-Length", 0))
        raw_body = self.rfile.read(content_length).decode("utf-8")
        try:
            req = json.loads(raw_body)
        except Exception:
            err_resp = {"jsonrpc": "2.0", "id": None, "error": {"code": -32700, "message": "Parse error"}}
            body = json.dumps(err_resp).encode("utf-8")
            self.send_response(400)
            self.send_header("Content-Type", JSON_CONTENT_TYPE)
            self.send_cors_headers()
            self.end_headers()
            self.wfile.write(body)
            return

        resp = process_jsonrpc_request(req)
        if resp is None:
            self.send_response(204)
            self.send_cors_headers()
            self.end_headers()
            return

        body = json.dumps(resp, ensure_ascii=False).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", JSON_CONTENT_TYPE)
        self.send_header("Content-Length", str(len(body)))
        self.send_cors_headers()
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, format, *args):
        # Silence default request logs to prevent cluttering stdio JSON-RPC stream
        pass

def run_http_server(port=8765):
    pid = os.getpid()
    set_mcp_status(enabled=True, running=True, port=port, pid=pid)

    server = http.server.ThreadingHTTPServer(("127.0.0.1", port), McpRequestHandler)
    server.daemon_threads = True
    print(f"Waan MCP Server started on port {port} (PID: {pid})", file=sys.stderr)

    signal.signal(signal.SIGINT, lambda *_: sys.exit(0))
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))

    try:
        server.serve_forever()  # NOSONAR python:S5332
    finally:
        set_mcp_status(enabled=False, running=False, port=port, pid=None)

def main():
    parser = argparse.ArgumentParser(description="Waan MCP Server")
    parser.add_argument("--port", type=int, help="Run HTTP/SSE server on specified port")
    parser.add_argument("--status", action="store_true", help="Print MCP Server status")

    args, _ = parser.parse_known_args()

    if args.status:
        print(json.dumps(get_mcp_status(), indent=2))
        return

    if args.port:
        run_http_server(args.port)
        return

    # Default to stdio JSON-RPC loop
    while True:
        line = sys.stdin.readline()
        if not line:
            break
        try:
            req = json.loads(line)
        except Exception:
            continue

        resp = process_jsonrpc_request(req)
        if resp is not None:
            sys.stdout.write(json.dumps(resp) + "\n")
            sys.stdout.flush()

if __name__ == "__main__":
    main()
