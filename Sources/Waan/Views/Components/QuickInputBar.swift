import SwiftUI

public struct QuickInputBar: View {
    @ObservedObject var store: TaskStore
    @ObservedObject var langManager: LanguageManager = .shared
    @State private var text: String = ""
    @State private var priority: Priority = .normal
    @State private var dueDateOption: String = "today"
    @State private var selectedCategory: String = ""

    public var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 15))

                TextField(langManager.currentLanguage == .th ? "เพิ่มงาน..." : "Add task...", text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .frame(minWidth: 50)
                    .help(langManager.currentLanguage == .th ? "กด Return เพื่อเพิ่ม (ใส่ #ประเภท ได้)" : "Press Return to add (supports #category)")
                    .onSubmit {
                        submit()
                    }

                Menu {
                    Button(langManager.currentLanguage == .th ? "ทั่วไป (ไม่ระบุ)" : "None") {
                        selectedCategory = ""
                    }
                    Divider()
                    ForEach(FocusAnalytics.presetCategories, id: \.self) { cat in
                        Button(action: { selectedCategory = cat }) {
                            HStack {
                                Text("#\(cat)")
                                if selectedCategory == cat {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "tag")
                            .font(.system(size: 10))
                        if !selectedCategory.isEmpty {
                            Text(selectedCategory)
                                .font(.system(size: 10, weight: .medium))
                        }
                    }
                    .foregroundColor(selectedCategory.isEmpty ? .secondary : .blue)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(selectedCategory.isEmpty ? Color.secondary.opacity(0.1) : Color.blue.opacity(0.12))
                    .cornerRadius(5)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help(langManager.currentLanguage == .th ? "เลือกประเภทงาน" : "Select category")

                Menu {
                    ForEach(Priority.allCases) { p in
                        Button(action: { priority = p }) {
                            HStack {
                                Text(p.localizedName(for: langManager.currentLanguage))
                                if priority == p {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text(priority.localizedName(for: langManager.currentLanguage))
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

                Menu {
                    Button(langManager.currentLanguage == .th ? "วันนี้" : "Today") { dueDateOption = "today" }
                    Button(langManager.currentLanguage == .th ? "พรุ่งนี้" : "Tomorrow") { dueDateOption = "tomorrow" }
                    Button(langManager.currentLanguage == .th ? "ไม่มีกำหนด" : "No Date") { dueDateOption = "none" }
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

                Button(action: submit) {
                    Text(langManager.text(.add))
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(text.trimmingCharacters(in: .whitespaces).isEmpty ? Color.secondary.opacity(0.2) : Color.accentColor)
                        .foregroundColor(text.trimmingCharacters(in: .whitespaces).isEmpty ? .secondary : .white)
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .fixedSize()
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 8)
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
        let isTh = langManager.currentLanguage == .th
        switch dueDateOption {
        case "today": return isTh ? "วันนี้" : "Today"
        case "tomorrow": return isTh ? "พรุ่งนี้" : "Tomorrow"
        default: return isTh ? "ไม่มี" : "None"
        }
    }

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var extractedTags: [String] = selectedCategory.isEmpty ? [] : [selectedCategory]
        var remainingWords: [String] = []
        for word in trimmed.split(separator: " ", omittingEmptySubsequences: true) {
            let s = String(word)
            if s.hasPrefix("#"), s.count > 1 {
                let candidate = String(s.dropFirst())
                if candidate.contains(where: \.isLetter) {
                    if !extractedTags.contains(candidate) {
                        extractedTags.append(candidate)
                    }
                    continue
                }
            }
            remainingWords.append(s)
        }

        let finalTitle = remainingWords.isEmpty ? trimmed : remainingWords.joined(separator: " ")
        let targetDate = dueDateOption == "today" ? Date() : (dueDateOption == "tomorrow" ? Calendar.current.date(byAdding: .day, value: 1, to: Date()) : nil)
        let calculatedDueDate = targetDate.map { ISO8601DateFormatter().string(from: $0) }

        store.addTask(
            title: finalTitle,
            dueDate: calculatedDueDate,
            priority: priority,
            subtasks: [],
            tags: extractedTags
        )

        text = ""
        priority = .normal
        selectedCategory = ""
    }
}

