<p align="center">
  <h1 align="center">Waan (วาน)</h1>
  <p align="center">
    <strong>A fast, distraction-free macOS task manager with a built-in local AI assistant.</strong>
  </p>
  <p align="center">
    <img src="https://img.shields.io/badge/macOS-14.0%2B%20Sonoma-blue?logo=apple&style=flat-square" alt="macOS 14+">
    <img src="https://img.shields.io/badge/SwiftUI-Native-orange?logo=swift&style=flat-square" alt="SwiftUI">
    <img src="https://img.shields.io/badge/License-MIT-black?style=flat-square" alt="MIT License">
  </p>
</p>

---

## What is Waan?

Waan is a lightweight, keyboard-friendly task manager for macOS. It stays out of your way in the Menu Bar for instant capture, opens into a clean dashboard when you need to plan, and connects with your local AI to organize your day.

No web wrappers. No cloud accounts. No monthly per-token API bills. Everything stays fast and private on your Mac.

---

## Key Features

- **Menu Bar Quick Capture:** Capture ideas and to-dos instantly from your menu bar without interrupting your current window.
- **Clean Split View Dashboard:** Organize tasks by Today, Upcoming, and Priorities with clear subtask checklists.
- **Built-in AI Assistant:** Chat naturally with an executive assistant powered by your local Antigravity CLI. Plan schedules, break down large projects, or reschedule overdue work in seconds.
- **Customizable AI Persona:** Tailor system instructions and assistant personality directly from the settings popover.
- **AI Harness Support:** Connect Claude Desktop, Cursor, or terminal scripts to your tasks through an embedded Model Context Protocol (MCP) server.
- **Fast and Battery Friendly:** Pure native SwiftUI. Launches instantly and uses negligible system memory.

---

## Quick Start

### Build and Launch

Clone the repository and run:

```bash
git clone https://github.com/prismest/waan.git
cd waan
make run
```

This compiles the release binary and launches `Waan.app` directly on your Mac.

---

## Using the AI Assistant

Click the **AI Chat** button in the main window toolbar to open the assistant panel.

You can ask Waan to manage your tasks using everyday language:

- *"What do I have to finish today?"*
- *"Add a high-priority task 'Launch new landing page' due tomorrow with 3 subtasks."*
- *"Break down 'Quarterly Review' into actionable checklist items."*
- *"Move all overdue tasks to tomorrow."*
- *"Mark 'Design Review' as completed."*

To adjust the assistant personality or instructions, click the slider icon at the top of the chat panel.

---

## Connecting Claude Desktop & Cursor

Waan includes an embedded MCP server that allows desktop tools to read and edit your tasks.

### Turn on MCP Server

Toggle the switch in the Menu Bar extra or the main window sidebar. You can also run:

```bash
./bin/waan mcp start
```

### Configuration

#### Claude Desktop
Add this entry to `~/Library/Application Support/Claude/claude_desktop_config.json`:

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

#### Cursor
In Cursor Settings > Features > MCP, add:
- **Name:** Waan
- **Type:** `sse`
- **URL:** `http://127.0.0.1:8765/sse`

---

## Terminal CLI (`bin/waan`)

Prefer the command line? Manage tasks directly from your shell:

```bash
# Add tasks
./bin/waan add "Send contract" --due today --priority urgent
./bin/waan add "Product Launch" --subtasks "Review deck, Press release"

# View and update
./bin/waan list
./bin/waan done "contract"
./bin/waan delete "contract"
```

---

## License

This project is licensed under the [MIT License](LICENSE).
