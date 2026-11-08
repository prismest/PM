# ✦ ZenTask - Native macOS AI Task Manager

แอปจัดการงานส่วนตัว (Personal Task Management) แบบ **Native macOS (SwiftUI)** ออกแบบมาให้ทำงานร่วมกับ **AI Harness (เช่น Claude Desktop, Cursor, หรือ AI Agent อื่นๆ)** ผ่าน **Subscription** โดยตรง ไม่ต้องเสียค่า API Token รายครั้ง

---

## 🌟 ฟีเจอร์หลัก

1. **Native macOS Hybrid Design (SwiftUI 100%):**
   * **Menu Bar Extra:** ไอคอนบนแถบเมนูด้านบนข้างนาฬิกา กดคลิกเดียวดูงานวันนี้ และมี Quick Input พิมพ์งานด่วนได้ทันที
   * **Main Window:** หน้าต่างแอปเต็ม มีแถบด้านข้าง (Sidebar) แยกหมวดหมู่งาน (*วันนี้, ทั้งหมด, ยังไม่เสร็จ, สำคัญมาก, เสร็จแล้ว*), ช่องค้นหา, และการ์ดแสดงขั้นตอนย่อย (Subtasks)
2. **SQLite Database พร้อมโหมด WAL:**
   * ฐานข้อมูลเก็บอยู่ในเครื่องที่ `~/Library/Application Support/ZenTask/tasks.db` (มี Shortcut อยู่ที่ `~/.zentask/tasks.db`)
   * ปลอดภัย 100%, รวดเร็วระดับเสี้ยววินาที, รองรับการเขียนพร้อมกันระหว่างแอป Mac และ AI Harness
3. **Real-time Live Sync (File Watcher):**
   * เมื่อ AI สั่งเพิ่มหรือแก้งาน หน้าต่างแอปจะอัปเดตงานใหม่ขึ้นมาให้เห็นทันทีโดยไม่ต้องกดรีเฟรช

---

## 🚀 วิธีเปิดใช้งานแอป

เปิดแอปบน Mac ด้วยคำสั่ง:
```bash
open ZenTask.app
```
*(ไอคอนจะปรากฏบนแถบเมนูด้านบนข้างนาฬิกา และคุณสามารถกดเปิดหน้าต่างเต็มได้ตลอดเวลา)*

---

## 🤖 การเชื่อมต่อกับ AI Harness (ผ่าน Subscription)

### วิธีที่ 1: เชื่อมต่อผ่าน MCP Server (Claude Desktop / Cursor)
ในโฟลเดอร์นี้มีไฟล์ `mcp_server.py` พร้อมใช้งานทันที

#### ตัวอย่างการตั้งค่าใน Claude Desktop (`~/Library/Application Support/Claude/claude_desktop_config.json`):
```json
{
  "mcpServers": {
    "zentask": {
      "command": "python3",
      "args": ["/Users/hqit52mb/Documents/PM/mcp_server.py"]
    }
  }
}
```

เมื่อเชื่อมต่อแล้ว คุณสามารถสั่ง Claude ใน Claude Desktop ได้ทันที เช่น:
* *"ช่วยดูงานค้างใน ZenTask ให้หน่อย"*
* *"พรุ่งนี้บ่ายสองมีนัดตรวจงานดีไซน์ ช่วยเพิ่มลงใน ZenTask แบบสำคัญมาก"*
* *"ช่วยแตกขั้นตอนย่อยของงานวางแผนโปรเจกต์ให้หน่อย"*

---

### วิธีที่ 2: สั่งผ่าน CLI Command (`bin/zentask`)

คำสั่ง Terminal ที่คุณหรือ AI Script สามารถเรียกใช้ได้ทันที:

```bash
# เพิ่มงานใหม่
./bin/zentask add "เตรียมสไลด์นำเสนอ" --due today --priority high

# เพิ่มงานพร้อมขั้นตอนย่อย (Subtasks)
./bin/zentask add "วางแผนท่องเที่ยวญี่ปุ่น" --subtasks "จองตั๋วเครื่องบิน, จองโรงแรม, แลกเงินเยน"

# ดูรายการงาน
./bin/zentask list
./bin/zentask list --json

# ติ๊กงานว่าเสร็จแล้ว
./bin/zentask done "สไลด์"

# แตกขั้นตอนย่อยในงานที่มีอยู่
./bin/zentask breakdown "สไลด์" "หาข้อมูลคู่แข่ง" "ร่างโครงสร้าง 5 สไลด์" "ออกแบบกราฟิก"

# ลบงาน
./bin/zentask delete "สไลด์"
```

---

## 🔨 การคอมไพล์ใหม่ (Build from Source)

หากมีการแก้ไขโค้ด Swift สามารถรันสคริปต์บิลด์ใหม่ได้ด้วย:
```bash
./build_app.sh
```

