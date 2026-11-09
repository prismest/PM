import SwiftUI

public struct ChatAssistantView: View {
    @ObservedObject var chatManager: AgyChatManager = .shared
    @State private var inputText: String = ""
    @State private var showingSettings: Bool = false

    public var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 13, weight: .bold))

                VStack(alignment: .leading, spacing: 1) {
                    Text("Antigravity AI")
                        .font(.system(size: 12, weight: .bold))
                    Text(chatManager.currentModelName)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button(action: { showingSettings.toggle() }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 10))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .help("Configure AI Role & Instructions")
                .popover(isPresented: $showingSettings, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "person.crop.circle.badge.checkmark")
                                .foregroundColor(.accentColor)
                            Text("AI Settings & Persona")
                                .font(.system(size: 12, weight: .bold))
                            Spacer()
                            Button("Reset") {
                                chatManager.resetInstructions()
                            }
                            .font(.system(size: 11))
                            .buttonStyle(.plain)
                            .foregroundColor(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Model & Reasoning")
                                .font(.system(size: 11, weight: .semibold))

                            Picker("", selection: $chatManager.selectedModel) {
                                ForEach(AgyChatManager.availableModels) { model in
                                    Text(model.name).tag(model.id)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)

                            if let selected = AgyChatManager.availableModels.first(where: { $0.id == chatManager.selectedModel }) {
                                Text(selected.detail)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }

                        Divider()

                        Text("บทบาท บุคลิก และคำสั่งตั้งต้น (มีผลเมื่อเริ่มแชทใหม่)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)

                        TextEditor(text: $chatManager.customInstructions)
                            .font(.system(size: 11))
                            .padding(4)
                            .frame(height: 110)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )

                        HStack {
                            Spacer()
                            Button("Done") {
                                showingSettings = false
                            }
                            .font(.system(size: 11, weight: .semibold))
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                    .padding(12)
                    .frame(width: 300)
                }

                Button(action: { chatManager.newChat() }) {
                    HStack(spacing: 3) {
                        Image(systemName: "plus.bubble")
                            .font(.system(size: 10))
                        Text("New Chat")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .help("Start a fresh conversation")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if chatManager.messages.isEmpty {
                            VStack(spacing: 12) {
                                Spacer(minLength: 40)

                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.accentColor.opacity(0.6))

                                Text("คุยกับ Antigravity CLI")
                                    .font(.system(size: 13, weight: .semibold))

                                Text("สั่งเพิ่ม, เลื่อน, จัดการ หรือวางแผนงานใน Waan ได้ต่อเนื่องใน Session เดียวกัน")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)

                                VStack(spacing: 6) {
                                    promptChip("สรุปงานที่ต้องทำวันนี้ให้หน่อย")
                                    promptChip("เลื่อนงานที่ค้างไปเป็นพรุ่งนี้")
                                    promptChip("เพิ่มงาน: ประชุมสรุปโปรเจกต์ (High priority)")
                                }
                                .padding(.top, 8)

                                Spacer(minLength: 40)
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            ForEach(chatManager.messages) { msg in
                                chatBubble(for: msg)
                                    .id(msg.id)
                            }

                            if chatManager.isSending {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .controlSize(.small)
                                    Text("Antigravity กำลังประมวลผล...")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.secondary.opacity(0.06))
                                .cornerRadius(8)
                                .padding(.horizontal, 12)
                                .id("loading_indicator")
                            }
                        }
                    }
                    .padding(.vertical, 12)
                }
                .onChange(of: chatManager.messages.count) {
                    if let last = chatManager.messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: chatManager.isSending) {
                    if chatManager.isSending {
                        withAnimation {
                            proxy.scrollTo("loading_indicator", anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            HStack(spacing: 8) {
                TextField("พิมพ์สั่งงานหรือคุยกับ AI...", text: $inputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .onSubmit {
                        submitMessage()
                    }
                    .disabled(chatManager.isSending)

                Button(action: submitMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(canSubmit ? .accentColor : .secondary.opacity(0.3))
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var canSubmit: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !chatManager.isSending
    }

    private func submitMessage() {
        guard canSubmit else { return }
        let text = inputText
        inputText = ""
        chatManager.sendMessage(text)
    }

    @ViewBuilder
    private func promptChip(_ prompt: String) -> some View {
        Button(action: {
            inputText = prompt
            submitMessage()
        }) {
            Text(prompt)
                .font(.system(size: 11))
                .foregroundColor(.accentColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.accentColor.opacity(0.08))
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func chatBubble(for msg: ChatMessage) -> some View {
        HStack(alignment: .top) {
            if msg.role == .user {
                Spacer(minLength: 32)
                Text(msg.content)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.accentColor)
                    .cornerRadius(12)
                    .padding(.trailing, 12)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey(msg.content))
                        .font(.system(size: 12))
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(12)
                .padding(.leading, 12)
                Spacer(minLength: 32)
            }
        }
    }
}
