import SwiftUI

public enum AppLanguage: String, CaseIterable, Identifiable {
    case th, en

    public var id: String { rawValue }
    public var title: String { self == .th ? "ไทย" : "English" }
}

public enum L10nKey {
    case searchPlaceholder
    case aiChat
    case newChat
    case add
    case done
    case reset
    case inputPlaceholder
    case processing
    case emptyChatTitle
    case emptyChatDesc
    case promptChipToday
    case promptChipOverdue
    case promptChipAdd
    case settingsTitle
    case language
    case modelAndReasoning
    case roleHint
    case openMainWindow
    case quit
    case focusLabel
    case breakLabel
    case overtimeLabel
    case startFocus
    case takeBreak
    case resume
    case pause
    case finishSave
    case focusInsights
    case backToWork
}

@MainActor
public final class LanguageManager: ObservableObject {
    public static let shared = LanguageManager()

    @Published public var currentLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(currentLanguage.rawValue, forKey: "waan_app_language")
            AgyChatManager.shared.handleLanguageChange(currentLanguage)
        }
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: "waan_app_language") ?? "th"
        self.currentLanguage = AppLanguage(rawValue: saved) ?? .th
    }

    public func toggle() {
        currentLanguage = (currentLanguage == .th) ? .en : .th
    }

    public func text(_ key: L10nKey) -> String {
        let isTh = currentLanguage == .th
        switch key {
        case .searchPlaceholder: return isTh ? "ค้นหางาน..." : "Search tasks..."
        case .aiChat: return isTh ? "คุยกับ AI" : "AI Chat"
        case .newChat: return isTh ? "แชทใหม่" : "New Chat"
        case .add: return isTh ? "เพิ่ม" : "Add"
        case .done: return isTh ? "เสร็จสิ้น" : "Done"
        case .reset: return isTh ? "รีเซ็ต" : "Reset"
        case .inputPlaceholder: return isTh ? "พิมพ์สั่งงานหรือคุยกับ AI..." : "Type a message or instruction..."
        case .processing: return isTh ? "Antigravity กำลังประมวลผล..." : "Antigravity is thinking..."
        case .emptyChatTitle: return isTh ? "คุยกับ Antigravity CLI" : "Chat with Antigravity CLI"
        case .emptyChatDesc: return isTh ? "สั่งเพิ่ม เลื่อน แตกงาน หรือจัดการงานใน Waan ได้อย่างต่อเนื่อง" : "Plan, schedule, break down, and prioritize tasks directly in Waan"
        case .promptChipToday: return isTh ? "สรุปงานที่ต้องทำวันนี้ให้หน่อย" : "Summarize today's pending tasks"
        case .promptChipOverdue: return isTh ? "เลื่อนงานที่ค้างไปเป็นพรุ่งนี้" : "Move overdue tasks to tomorrow"
        case .promptChipAdd: return isTh ? "เพิ่มงาน: สรุปผลโปรเจกต์ (High priority)" : "Add task: Project sync meeting (High priority)"
        case .settingsTitle: return isTh ? "ตั้งค่า AI และภาษา" : "AI & Language Settings"
        case .language: return isTh ? "ภาษา (Language)" : "Language"
        case .modelAndReasoning: return isTh ? "โมเดลและการประมวลผล" : "Model & Reasoning"
        case .roleHint: return isTh ? "บทบาท บุคลิก และคำสั่งตั้งต้น (มีผลเมื่อเริ่มแชทใหม่)" : "Persona and instructions (Applies to new chats)"
        case .openMainWindow: return isTh ? "เปิดหน้าต่างหลัก" : "Open Main Window"
        case .quit: return isTh ? "ออกจากโปรแกรม" : "Quit Waan"
        case .focusLabel: return isTh ? "โฟกัส" : "Focus"
        case .breakLabel: return isTh ? "พัก" : "Break"
        case .overtimeLabel: return isTh ? "เลยเป้า" : "Overtime"
        case .startFocus: return isTh ? "เริ่มโฟกัส" : "Start Focus"
        case .takeBreak: return isTh ? "พัก" : "Break"
        case .resume: return isTh ? "ทำต่อ" : "Resume"
        case .pause: return isTh ? "หยุดชั่วคราว" : "Pause"
        case .finishSave: return isTh ? "จบ" : "Stop"
        case .focusInsights: return isTh ? "สถิติเวลา" : "Time Insights"
        case .backToWork: return isTh ? "เริ่มงานต่อ" : "Back to Work"
        }
    }
}

