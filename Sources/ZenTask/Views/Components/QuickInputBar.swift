import SwiftUI

public struct QuickInputBar: View {
    @ObservedObject var store: TaskStore
    @State private var text: String = ""
    @State private var priority: Priority = .normal
    @State private var dueDateOption: String = "today" // "today", "tomorrow", "none"

    public var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 16))

                TextField("พิมพ์งานที่ต้องทำ... (กด Enter เพื่อเพิ่ม)", text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .onSubmit {
                        submit()
                    }

                // Priority Picker Menu
                Menu {
                    ForEach(Priority.allCases) { p in
                        Button(action: { priority = p }) {
                            HStack {
                                Text(p.displayName)
                                if priority == p {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text(priority.displayName.prefix(4))
                            .font(.system(size: 11))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(5)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                // Due Date Menu
                Menu {
                    Button("วันนี้") { dueDateOption = "today" }
                    Button("พรุ่งนี้") { dueDateOption = "tomorrow" }
                    Button("ไม่ระบุวัน") { dueDateOption = "none" }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "calendar")
                            .font(.system(size: 10))
                        Text(dueDateLabel)
                            .font(.system(size: 11))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(5)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                // Submit Button
                Button(action: submit) {
                    Text("เพิ่ม")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(text.trimmingCharacters(in: .whitespaces).isEmpty ? Color.secondary.opacity(0.2) : Color.accentColor)
                        .foregroundColor(text.trimmingCharacters(in: .whitespaces).isEmpty ? .secondary : .white)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: .black.opacity(0.04), radius: 2, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
        }
    }

    private var dueDateLabel: String {
        switch dueDateOption {
        case "today": return "วันนี้"
        case "tomorrow": return "พรุ่งนี้"
        default: return "ไม่ระบุ"
        }
    }

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var calculatedDueDate: String? = nil
        let calendar = Calendar.current
        let formatter = ISO8601DateFormatter()

        if dueDateOption == "today" {
            calculatedDueDate = formatter.string(from: Date())
        } else if dueDateOption == "tomorrow" {
            if let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) {
                calculatedDueDate = formatter.string(from: tomorrow)
            }
        }

        store.addTask(
            title: trimmed,
            dueDate: calculatedDueDate,
            priority: priority,
            subtasks: [],
            tags: []
        )

        // Reset
        text = ""
        priority = .normal
    }
}

