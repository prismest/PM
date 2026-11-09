#!/usr/bin/env python3
import os
import sys
import json
import sqlite3
import tempfile
import unittest
from datetime import date
from unittest.mock import patch

from importlib.machinery import SourceFileLoader
import importlib.util

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, BASE_DIR)

waan_path = os.path.join(BASE_DIR, "bin", "waan")
loader = SourceFileLoader("waan", waan_path)
spec = importlib.util.spec_from_loader("waan", loader)
waan = importlib.util.module_from_spec(spec)
sys.modules["waan"] = waan
loader.exec_module(waan)

import mcp_server


class WaanBaseTestCase(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.db_path = os.path.join(self.temp_dir.name, "tasks.db")
        self.dot_dir = os.path.join(self.temp_dir.name, ".waan")

        self.patch_waan_db = patch("waan.DB_DIR", self.temp_dir.name)
        self.patch_waan_path = patch("waan.DB_PATH", self.db_path)
        self.patch_waan_dot = patch("waan.DOT_DIR", self.dot_dir)

        self.patch_mcp_db = patch("mcp_server.DB_DIR", self.temp_dir.name)
        self.patch_mcp_path = patch("mcp_server.DB_PATH", self.db_path)

        self.patch_waan_db.start()
        self.patch_waan_path.start()
        self.patch_waan_dot.start()
        self.patch_mcp_db.start()
        self.patch_mcp_path.start()

    def tearDown(self):
        self.patch_waan_db.stop()
        self.patch_waan_path.stop()
        self.patch_waan_dot.stop()
        self.patch_mcp_db.stop()
        self.patch_mcp_path.stop()
        self.temp_dir.cleanup()


class TestDatabaseSchema(WaanBaseTestCase):
    def test_schema_creation_and_wal_mode(self):
        conn = waan.init_db()
        cursor = conn.cursor()

        cursor.execute("PRAGMA journal_mode;")
        mode = cursor.fetchone()[0]
        self.assertEqual(mode.lower(), "wal")

        cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='tasks';")
        self.assertIsNotNone(cursor.fetchone())

        cursor.execute("PRAGMA table_info(tasks);")
        columns = [row[1] for row in cursor.fetchall()]
        expected = ["id", "title", "due_date", "priority", "status", "subtasks_json", "tags_json", "created_at", "completed_at"]
        for col in expected:
            self.assertIn(col, columns)
        conn.close()


class TestCliOperations(WaanBaseTestCase):
    def test_add_and_list_tasks(self):
        task_id = waan.add_task(
            title="Deploy release",
            due="today",
            priority="urgent",
            subtasks=["Run tests", "Build bundle"],
            tags=["devops", "v1"]
        )
        self.assertTrue(bool(task_id))

        pending = waan.list_tasks(status="pending")
        self.assertEqual(len(pending), 1)
        self.assertEqual(pending[0]["title"], "Deploy release")
        self.assertEqual(pending[0]["priority"], "urgent")
        self.assertEqual(len(pending[0]["subtasks"]), 2)
        self.assertEqual(pending[0]["tags"], ["devops", "v1"])

    def test_complete_and_delete_task(self):
        task_id = waan.add_task(title="Refactor core")
        res_done = waan.complete_task("Refactor")
        self.assertIsNotNone(res_done)
        self.assertEqual(res_done[0], task_id)

        completed = waan.list_tasks(status="completed")
        self.assertEqual(len(completed), 1)
        self.assertEqual(completed[0]["status"], "completed")

        res_del = waan.delete_task(task_id)
        self.assertIsNotNone(res_del)
        self.assertEqual(len(waan.list_tasks(status="all")), 0)

    def test_breakdown_task(self):
        task_id = waan.add_task(title="Prepare Demo")
        res_bd = waan.add_subtasks_to_task("Demo", ["Step 1", "Step 2"])
        self.assertIsNotNone(res_bd)
        self.assertEqual(res_bd[2], 2)

        tasks = waan.list_tasks()
        self.assertEqual(len(tasks[0]["subtasks"]), 2)
        self.assertEqual(tasks[0]["subtasks"][0]["title"], "Step 1")

    def test_resolve_due_date(self):
        self.assertIsNone(waan.resolve_due_date(None))
        self.assertEqual(waan.resolve_due_date("today"), date.today().isoformat())
        self.assertEqual(waan.resolve_due_date("2026-12-31"), "2026-12-31")


class TestMcpServerProtocol(WaanBaseTestCase):
    def test_tool_definitions(self):
        tools = mcp_server.TOOLS
        tool_names = [t["name"] for t in tools]
        expected_tools = [
            "waan_add_task",
            "waan_list_tasks",
            "waan_complete_task",
            "waan_breakdown_task",
            "waan_delete_task",
        ]
        for name in expected_tools:
            self.assertIn(name, tool_names)

    def test_tool_call_add_and_list(self):
        conn = mcp_server.get_db()
        cursor = conn.cursor()

        add_res = mcp_server.tool_add_task(cursor, {
            "title": "MCP Task",
            "due_date": "tomorrow",
            "priority": "high",
            "subtasks": ["Sub 1"]
        })
        conn.commit()
        self.assertIn("Task added", add_res)

        list_json = mcp_server.tool_list_tasks(cursor, {"status": "pending"})
        tasks = json.loads(list_json)
        self.assertEqual(len(tasks), 1)
        self.assertEqual(tasks[0]["title"], "MCP Task")
        self.assertEqual(tasks[0]["priority"], "high")

        done_res = mcp_server.tool_complete_task(cursor, {"target": "MCP Task"})
        conn.commit()
        self.assertIn("marked as completed", done_res)

        del_res = mcp_server.tool_delete_task(cursor, {"target": "MCP Task"})
        conn.commit()
        self.assertIn("deleted", del_res)
        conn.close()

    def test_unknown_tool_call(self):
        res = mcp_server.handle_tool_call("unknown_tool", {})
        self.assertEqual(res, "Unknown tool")

    def test_mcp_status_toggle(self):
        status = mcp_server.set_mcp_status(enabled=False)
        self.assertFalse(status["enabled"])
        self.assertFalse(mcp_server.is_mcp_enabled())

        status_on = mcp_server.set_mcp_status(enabled=True)
        self.assertTrue(status_on["enabled"])
        self.assertTrue(mcp_server.is_mcp_enabled())

    def test_mcp_tool_when_disabled(self):
        mcp_server.set_mcp_status(enabled=False)
        req = {
            "jsonrpc": "2.0",
            "id": "test-1",
            "method": "tools/call",
            "params": {"name": "waan_list_tasks", "arguments": {}}
        }
        resp = mcp_server.process_jsonrpc_request(req)
        self.assertTrue(resp.get("result", {}).get("isError", False))
        self.assertIn("turned OFF", resp["result"]["content"][0]["text"])

        # Re-enable
        mcp_server.set_mcp_status(enabled=True)
        resp_enabled = mcp_server.process_jsonrpc_request(req)
        self.assertNotIn("isError", resp_enabled.get("result", {}))


if __name__ == "__main__":
    unittest.main()
