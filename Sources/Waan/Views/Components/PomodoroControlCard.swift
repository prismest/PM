import SwiftUI

public struct MenuBarLabelView: View {
    @ObservedObject var pomodoro: PomodoroManager = .shared

    public init() {}

    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: pomodoro.menuBarIconName)
            if let text = pomodoro.menuBarText {
                Text(text)
                    .monospacedDigit()
            }
        }
    }
}

public struct PomodoroControlCard: View {
    @ObservedObject var pomodoro: PomodoroManager
    @ObservedObject var langManager: LanguageManager = .shared
    let compact: Bool
    @State private var showingDurations: Bool = false

    public init(pomodoro: PomodoroManager? = nil, compact: Bool = false) {
        self.pomodoro = pomodoro ?? .shared
        self.compact = compact
    }

    private var isTh: Bool { langManager.currentLanguage == .th }

    private var statusColor: Color {
        switch pomodoro.state.session?.kind {
        case .focus: return pomodoro.isOvertime ? .orange : .accentColor
        case .breakTime: return pomodoro.isOvertime ? .orange : .green
        case nil: return .accentColor
        }
    }

    private var phaseTitle: String {
        switch pomodoro.activeKind {
        case .focus, nil: return pomodoro.isOvertime ? langManager.text(.overtimeLabel) : langManager.text(.focusLabel)
        case .breakTime: return langManager.text(.breakLabel)
        }
    }

    public var body: some View {
        if pomodoro.state == .idle {
            VStack(alignment: .leading, spacing: 4) {
                idleRow
                if let task = pomodoro.selectedTask {
                    HStack(spacing: 4) {
                        Text(task.title)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer()
                        Button(action: { pomodoro.clearSelectedTask() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        } else {
            activeView
        }
    }

    private var idleRow: some View {
        HStack(spacing: 8) {
            Button(action: { showingDurations.toggle() }) {
                HStack(spacing: 5) {
                    Image(systemName: "timer")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text(pomodoro.primaryClockDisplay)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.primary)
                    Text("\(pomodoro.focusMinutes)/\(pomodoro.breakMinutes)")
                        .font(.system(size: 10))
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .help(isTh ? "ตั้งเวลาทำงาน / พัก" : "Set focus & break durations")
            .popover(isPresented: $showingDurations, arrowEdge: .trailing) {
                durationConfigPopover
            }

            Spacer()

            Button(action: { pomodoro.startFocus() }) {
                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 9))
                    if !compact {
                        Text(langManager.text(.startFocus))
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                .foregroundColor(.accentColor)
                .padding(.horizontal, compact ? 7 : 8)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.12))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help(langManager.text(.startFocus))
        }
    }

    private var activeView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                Text(phaseTitle)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(pomodoro.isOvertime ? .orange : .secondary)
                if let title = pomodoro.state.session?.taskTitle ?? pomodoro.selectedTask?.title {
                    Text("· \(title)")
                        .font(.system(size: 10))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer()
            }

            HStack(alignment: .center, spacing: 6) {
                Text(pomodoro.primaryClockDisplay)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(pomodoro.isOvertime ? .orange : .primary)

                Spacer()

                Button(action: { pomodoro.togglePause() }) {
                    Image(systemName: pomodoro.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help(pomodoro.isPaused ? langManager.text(.resume) : langManager.text(.pause))

                let isFocus = pomodoro.activeKind == .focus
                Button(action: { isFocus ? pomodoro.startBreak() : pomodoro.startFocus() }) {
                    Text(langManager.text(isFocus ? .takeBreak : .backToWork))
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(isFocus ? (pomodoro.isOvertime ? Color.orange : Color.green.opacity(0.85)) : Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(5)
                }
                .buttonStyle(.plain)

                Button(action: { pomodoro.stopAndSave() }) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help(langManager.text(.finishSave))
            }

            ProgressView(value: pomodoro.progress)
                .progressViewStyle(.linear)
                .tint(statusColor)
                .controlSize(.mini)
        }
        .padding(.vertical, 4)
    }

    private var durationConfigPopover: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(isTh ? "ตั้งค่าเวลาการทำงานและพัก" : "Work & Break Durations")
                .font(.system(size: 12, weight: .bold))

            stepperRow(
                label: isTh ? "เวลาทำงาน (นาที)" : "Focus (minutes)",
                value: $pomodoro.focusMinutes,
                range: 1...180
            )

            stepperRow(
                label: isTh ? "เวลาพัก (นาที)" : "Break (minutes)",
                value: $pomodoro.breakMinutes,
                range: 1...60
            )

            HStack(spacing: 6) {
                ForEach([(15, 5), (25, 5), (45, 10), (50, 10)], id: \.0) { focus, brk in
                    let active = pomodoro.focusMinutes == focus && pomodoro.breakMinutes == brk
                    Button(action: {
                        pomodoro.focusMinutes = focus
                        pomodoro.breakMinutes = brk
                    }) {
                        Text("\(focus)/\(brk)")
                            .font(.system(size: 10, weight: .medium))
                            .monospacedDigit()
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(active ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                            .foregroundColor(active ? .accentColor : .primary)
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .frame(width: 230)
    }

    @ViewBuilder
    private func stepperRow(label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
            Spacer()
            Stepper(value: value, in: range) {
                Text("\(value.wrappedValue)")
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
                    .frame(minWidth: 26, alignment: .trailing)
            }
            .controlSize(.small)
        }
    }
}
