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
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 13, weight: .semibold))

                TextField(langManager.currentLanguage == .th ? "เพิ่มงาน..." : "Add task...", text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .frame(minWidth: 60)
                    .onSubmit {
                        submit()
                    }

                Menu {
                    Picker("", selection: $selectedCategory) {
                        Text(langManager.currentLanguage == .th ? "ทั่วไป (ไม่ระบุ)" : "None").tag("")
                        Divider()
                        ForEach(FocusAnalytics.presetCategories, id: \.self) { Text("#\($0)").tag($0) }
                    }
                    .pickerStyle(.inline)
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "tag")
                            .font(.system(size: 11))
                        if !selectedCategory.isEmpty {
                            Text(selectedCategory)
                                .font(.system(size: 10, weight: .medium))
                        }
                    }
                    .foregroundColor(selectedCategory.isEmpty ? .secondary.opacity(0.65) : .accentColor)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help(langManager.currentLanguage == .th ? "ประเภทงาน" : "Category")

                Menu {
                    Picker("", selection: $priority) {
                        ForEach(Priority.allCases) { Text($0.localizedName(for: langManager.currentLanguage)).tag($0) }
                    }
                    .pickerStyle(.inline)
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "flag")
                            .font(.system(size: 11))
                        if priority != .normal {
                            Text(priority.localizedName(for: langManager.currentLanguage))
                                .font(.system(size: 10, weight: .medium))
                        }
                    }
                    .foregroundColor(priority == .normal ? .secondary.opacity(0.65) : .orange)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help(langManager.currentLanguage == .th ? "ความสำคัญ" : "Priority")

                Menu {
                    Button(langManager.currentLanguage == .th ? "วันนี้" : "Today") { dueDateOption = "today" }
                    Button(langManager.currentLanguage == .th ? "พรุ่งนี้" : "Tomorrow") { dueDateOption = "tomorrow" }
                    Button(langManager.currentLanguage == .th ? "ไม่มีกำหนด" : "No Date") { dueDateOption = "none" }
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11))
                        if dueDateOption != "today" {
                            Text(dueDateLabel)
                                .font(.system(size: 10, weight: .medium))
                        }
                    }
                    .foregroundColor(dueDateOption == "today" ? .secondary.opacity(0.65) : .accentColor)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help(dueDateLabel)

                if !text.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button(action: submit) {
                        Text(langManager.text(.add))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .fixedSize()
                }
            }
            .padding(.vertical, 6)

            Divider()
                .opacity(0.5)
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
