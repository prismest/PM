<p align="center">
  <h1 align="center">Waan</h1>
  <p align="center">
    <strong>A high-performance, distraction-free macOS task manager built natively in SwiftUI.</strong><br>
    <em>Engineered to connect with desktop AI harnesses (Claude Desktop, Cursor, local agents) using your existing flat subscription with zero per-token API costs.</em>
  </p>
  <p align="center">
    <img src="https://img.shields.io/badge/macOS-14.0%2B%20Sonoma-blue?logo=apple&style=flat-square" alt="macOS 14+">
    <img src="https://img.shields.io/badge/Swift-6.0%20%2F%20SwiftUI-orange?logo=swift&style=flat-square" alt="SwiftUI">
    <img src="https://img.shields.io/badge/Storage-SQLite3%20WAL-success?logo=sqlite&style=flat-square" alt="SQLite WAL">
    <img src="https://img.shields.io/badge/AI%20Protocol-MCP%20Compliant-purple?style=flat-square" alt="MCP Compliant">
    <img src="https://img.shields.io/badge/Dependencies-0%20Third--Party-brightgreen?style=flat-square" alt="Zero Dependencies">
    <img src="https://img.shields.io/badge/License-MIT-black?style=flat-square" alt="MIT License">
  </p>
</p>

---

## Overview

Most modern task management applications rely on heavy web wrappers (Electron), mandatory cloud synchronization, or metered per-token API billing to provide AI capabilities.

**Waan** takes a fundamentally different engineering approach:
* **100% Native macOS Hybrid UI:** Built purely with **SwiftUI** featuring both a persistent **Menu Bar Extra** and a full **SplitView Main Window**.
* **Zero External Dependencies:** No CocoaPods, no Swift Package dependencies, no Python pip wheels. It runs directly on stock macOS.
* **Flat-Subscription AI Harnessing:** Exposes an embedded **Model Context Protocol (MCP)** stdio server and scriptable CLI that allows desktop tools like **Claude Desktop** and **Cursor** to manage your schedule directly on your local machine with no metered API keys.
* **Real-time Reactive Sync:** Changes made by external AI harnesses or terminal scripts update the macOS GUI instantaneously using kernel-level GCD file events—**zero polling, zero battery drain**.

---

## System Architecture

```
                   ┌─────────────────────────────────────────┐
                   │          External AI Harnesses          │
                   │  Claude Desktop (MCP)   Cursor / Agents │
                   └───────────────┬─────────────────┬───────┘
                                   │ (stdio JSON-RPC)│ (subprocess)
                                   ▼                 ▼
                        ┌──────────────────┐  ┌─────────────┐
                        │  mcp_server.py   │  │  bin/waan   │
                        │ (Zero-Dep Python)│  │ (Python CLI)│
                        └─────────┬────────┘  └──────┬──────┘
                                  │                  │
                                  │ SQL Insert/Update│
                                  ▼                  ▼
                        ┌───────────────────────────────────┐
                        │     Shared SQLite WAL Database    │
                        │   ~/.waan/tasks.db (Multi-Process)│
                        └─────────────────┬─────────────────┘
                                          │
                                          │ DispatchSourceFileSystemObject
                                          ▼ (Kernel Event - No Polling)
                        ┌───────────────────────────────────┐
                        │       Waan Native macOS App       │
                        │    (SwiftUI + Swift 6 Runtime)    │
                        ├─────────────────┬─────────────────┤
                        │  MenuBar Extra  │   Main Window   │
                        │  (Quick Capture)│ (Task Analytics)│
                        └─────────────────┴─────────────────┘
```

---

## Architectural Decisions & Engineering Highlights

### 1. Parameterized SQLite over ORMs (Why No CoreData / SwiftData?)
* **Cross-Language Safety:** Waan is read and written concurrently by **Swift** (`Waan.app`) and **Python** (`bin/waan`, `mcp_server.py`). CoreData and SwiftData inject proprietary metadata and journal locks that break cross-language concurrency.
* **Concurrent WAL Mode:** `PRAGMA journal_mode=WAL;` and `PRAGMA busy_timeout=5000;` allow readers (UI) to never block writers (AI/CLI) and vice-versa.
* **Sub-20ms Cold Boot:** Raw SQLite eliminates the heavy initialization overhead of ORMs, enabling instantaneous CLI and MCP responses.

### 2. Kernel-Level File Watching (`DispatchSourceFileSystemObject`)
* Instead of running background timer polling that exhausts laptop battery, Waan listens directly to kernel file system notifications using `DispatchSource.makeFileSystemObjectSource` with `.write` and `.extend` event masks.
* When Claude Desktop inserts a task through MCP, the native SwiftUI interface reloads in under 5 milliseconds.

---

## Quick Start

### Prerequisites
* macOS 14.0 (Sonoma) or newer
* Xcode Command Line Tools (`xcode-select --install`)
* Python 3.9+ (built-in macOS Python)

### 1-Line Build & Run
```bash
git clone https://github.com/prismest/waan.git
cd waan
make build
make run
```

---

## AI Harness Integration

### 1. Instant Start/Stop MCP Server Toggle

Waan includes a built-in **MCP Server Controller** accessible right from the UI:
* **Menu Bar Extra Toggle:** Switch MCP Server ON/OFF in 1 click from your menu bar without opening windows.
* **Main Window Sidebar:** Real-time green/gray status indicator with immediate On/Off toggle switch.
* **HTTP / SSE Transport (`http://127.0.0.1:8765/sse`):** Allows remote MCP clients (Cursor, web dashboards, local scripts) to connect over Server-Sent Events.
* **Zero-Dep Stdio Mode:** Standard stdio bridge for Claude Desktop, with automatic enforcement of the On/Off switch state.

---

### 2. Claude Desktop & Cursor (Model Context Protocol)

Connect Waan to **Claude Desktop** or **Cursor** to turn AI into an autonomous executive assistant.

#### Claude Desktop Stdio Config:
Add this entry to your Claude Desktop configuration (`~/Library/Application Support/Claude/claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "waan": {
      "command": "python3",
      "args": ["/Users/YOUR_USER/.waan/mcp_server.py"]
    }
  }
}
```

#### Cursor / SSE Config:
In Cursor Settings > Features > MCP, add:
* **Name:** Waan
* **Type:** `sse`
* **URL:** `http://127.0.0.1:8765/sse`

#### Example Prompts:
* *"What pending tasks do I have scheduled for today?"*
* *"Add a high-priority task 'Ship Q4 Feature' due tomorrow with 3 subtasks."*
* *"Break down my task 'Prepare Demo' into 4 actionable checklist items."*
* *"Mark the task 'Ship Q4 Feature' as done."*

---

### 3. Terminal CLI (`bin/waan`)

Manage tasks and MCP Server directly from your shell, cron jobs, or local automation scripts:

```bash
# MCP Server Controls
./bin/waan mcp status      # Check if MCP server is active or stopped
./bin/waan mcp start       # Start MCP background server on port 8765
./bin/waan mcp stop        # Stop MCP server

# Add a task
./bin/waan add "Finish security audit" --due today --priority urgent

# Add a task with subtasks and tags
./bin/waan add "Plan Product Launch" --subtasks "Review deck, Sync with marketing, Press release" --tags "product,launch"

# List tasks (human-readable or JSON)
./bin/waan list
./bin/waan list --all
./bin/waan list --completed
./bin/waan list --json

# Complete a task (matches ID prefix or title keyword)
./bin/waan done "audit"

# Break down an existing task with additional subtasks
./bin/waan breakdown "Launch" "Prepare staging server" "Conduct load testing"

# Delete a task
./bin/waan delete "audit"
```

---

## Automated Testing

Waan includes an automated test suite verifying database schema integrity, WAL mode concurrency, CLI commands, and the MCP JSON-RPC protocol:

```bash
make test
```

```text
test_add_and_list_tasks (test_waan.TestCliOperations) ... ok
test_breakdown_task (test_waan.TestCliOperations) ... ok
test_complete_and_delete_task (test_waan.TestCliOperations) ... ok
test_resolve_due_date (test_waan.TestCliOperations) ... ok
test_schema_creation_and_wal_mode (test_waan.TestDatabaseSchema) ... ok
test_mcp_status_toggle (test_waan.TestMcpServerProtocol) ... ok
test_mcp_tool_when_disabled (test_waan.TestMcpServerProtocol) ... ok
test_tool_call_add_and_list (test_waan.TestMcpServerProtocol) ... ok
test_tool_definitions (test_waan.TestMcpServerProtocol) ... ok
test_unknown_tool_call (test_waan.TestMcpServerProtocol) ... ok

Ran 10 tests in 0.014s
OK
```

---

## Project Structure

```text
PM/
├── .github/workflows/ci.yml # Automated CI pipeline (macOS-14 runner)
├── Makefile                 # Developer ergonomics (build, test, run, clean)
├── Package.swift            # Swift Package Manager definition
├── README.md                # Comprehensive documentation & architectural specification
├── LICENSE                  # MIT License
├── build_app.sh             # Release compilation & .app bundle packaging script
├── mcp_server.py            # Zero-dependency Model Context Protocol stdio server
├── bin/
│   └── waan                 # Zero-dependency CLI executable
├── tests/
│   └── test_waan.py         # Automated test suite (SQLite, CLI, MCP Protocol)
└── Sources/
    └── Waan/
        ├── WaanApp.swift    # App entry point (MenuBarExtra + Window scenes)
        ├── Model/
        │   └── TaskItem.swift        # Task, Subtask, Priority data structures
        ├── Storage/
        │   ├── DatabaseManager.swift # Raw SQLite C API engine (WAL mode)
        │   └── FileWatcher.swift     # Kernel GCD filesystem notification engine
        ├── Store/
        │   └── TaskStore.swift       # MainActor observable state store
        └── Views/
            ├── MenuBarView.swift     # Persistent dropdown quick-access UI
            ├── MainWindowView.swift  # SplitView category sidebar & dashboard
            └── Components/
                ├── QuickInputBar.swift # Natural keyboard-first task capture
                └── TaskRowView.swift   # Interactive task cards with checklists
```

---

## License

This project is licensed under the [MIT License](LICENSE).
