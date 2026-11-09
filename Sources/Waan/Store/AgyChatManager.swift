import Foundation
import SwiftUI

public enum ChatRole {
    case user
    case assistant
}

public struct ChatMessage: Identifiable, Equatable {
    public let id: UUID
    public let role: ChatRole
    public let content: String

    public init(id: UUID = UUID(), role: ChatRole, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }
}

@MainActor
public final class AgyChatManager: ObservableObject {
    public static let shared = AgyChatManager()

    public struct ModelOption: Identifiable, Hashable {
        public let id: String
        public let name: String
        public let detail: String
    }

    public static let availableModels: [ModelOption] = [
        ModelOption(id: "gemini-3.8-flash-high", name: "Gemini 3.8 Flash (High)", detail: "High reasoning (Default)"),
        ModelOption(id: "gemini-3.8-flash-medium", name: "Gemini 3.8 Flash (Medium)", detail: "Balanced speed & reasoning"),
        ModelOption(id: "gemini-3.8-flash-low", name: "Gemini 3.8 Flash (Low)", detail: "Fastest response, zero thinking delay"),
        ModelOption(id: "claude-sonnet-4-6", name: "Claude Sonnet 4.6", detail: "Anthropic Claude thinking model"),
        ModelOption(id: "claude-opus-4-6-thinking", name: "Claude Opus 4.6", detail: "Deepest reasoning, highest quality"),
        ModelOption(id: "gpt-oss-120b-medium", name: "GPT-OSS 120B", detail: "Open-source 120B model")
    ]

    public static let defaultInstructions: String = """
คุณคือ Waan AI เลขาส่วนตัวอัจฉริยะ (Personal Executive Assistant) สำหรับจัดการงานบน macOS
- หน้าที่: ช่วยวางแผนงาน จัดลำดับความสำคัญ แตกงานย่อย (Subtasks) และเลื่อนกำหนดส่งงาน
- การทำงาน: เรียกใช้ MCP Tools ของ Waan อัตโนมัติเมื่อผู้ใช้ต้องการ ดู/เพิ่ม/เลื่อน/ลบ/ติ๊กเสร็จ
- สไตล์การตอบ: สุภาพ กระชับ ชัดเจน สรุปผลสั้นๆ ไม่เวิ่นเว้อ
"""

    @Published public var messages: [ChatMessage] = []
    @Published public var isSending: Bool = false
    @Published public var conversationId: String? = nil
    @Published public var selectedModel: String {
        didSet {
            UserDefaults.standard.set(selectedModel, forKey: "waan_agy_selected_model")
        }
    }
    @Published public var customInstructions: String {
        didSet {
            UserDefaults.standard.set(customInstructions, forKey: "waan_agy_custom_instructions")
        }
    }

    public var currentModelName: String {
        Self.availableModels.first(where: { $0.id == selectedModel })?.name ?? selectedModel
    }

    private init() {
        self.conversationId = UserDefaults.standard.string(forKey: "waan_agy_conversation_id")
        self.customInstructions = UserDefaults.standard.string(forKey: "waan_agy_custom_instructions") ?? Self.defaultInstructions
        self.selectedModel = UserDefaults.standard.string(forKey: "waan_agy_selected_model") ?? "gemini-3.8-flash-high"
    }

    public func resetInstructions() {
        self.customInstructions = Self.defaultInstructions
    }

    public func newChat() {
        self.conversationId = nil
        self.messages.removeAll()
        UserDefaults.standard.removeObject(forKey: "waan_agy_conversation_id")
    }

    public func resolveAgyPath() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = ["\(home)/.local/bin/agy", "\(home)/.gemini/bin/agy", "/usr/local/bin/agy", "/opt/homebrew/bin/agy"]
        return candidates.first(where: { FileManager.default.fileExists(atPath: $0) }) ?? "/usr/local/bin/agy"
    }

    public func sendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }

        let userMsg = ChatMessage(role: .user, content: trimmed)
        messages.append(userMsg)
        isSending = true

        let currentConvId = self.conversationId
        let agyPath = resolveAgyPath()
        let instructions = self.customInstructions.trimmingCharacters(in: .whitespacesAndNewlines)
        let modelToUse = self.selectedModel
        let appSupportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?.appendingPathComponent("Waan")

        let promptToSend = (currentConvId?.isEmpty ?? true) ? "[System Instructions:\n\(instructions)]\n\n\(trimmed)" : trimmed

        Task.detached(priority: .userInitiated) { [weak self] in
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: agyPath)
            proc.currentDirectoryURL = appSupportDir ?? FileManager.default.homeDirectoryForCurrentUser

            var args: [String] = []
            if let cid = currentConvId, !cid.isEmpty {
                args += ["--conversation", cid]
            }
            if !modelToUse.isEmpty {
                args += ["--model", modelToUse]
            }
            args += ["-p", promptToSend, "--output-format", "json", "--dangerously-skip-permissions"]
            proc.arguments = args

            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = FileHandle.nullDevice

            var responseText = "ไม่สามารถเชื่อมต่อกับ Antigravity CLI ได้"
            var returnedConvId: String? = currentConvId

            do {
                try proc.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                proc.waitUntilExit()

                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let resp = json["response"] as? String {
                        responseText = resp.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                    if let cid = json["conversation_id"] as? String {
                        returnedConvId = cid
                    }
                } else if let rawOutput = String(data: data, encoding: .utf8), !rawOutput.isEmpty {
                    responseText = rawOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            } catch {
                responseText = "เกิดข้อผิดพลาด: \(error.localizedDescription)"
            }

            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.messages.append(ChatMessage(role: .assistant, content: responseText))
                self.conversationId = returnedConvId
                if let cid = returnedConvId {
                    UserDefaults.standard.set(cid, forKey: "waan_agy_conversation_id")
                }
                self.isSending = false
                TaskStore.shared.reloadTasks()
            }
        }
    }
}
