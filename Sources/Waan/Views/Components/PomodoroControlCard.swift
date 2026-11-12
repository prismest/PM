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
        case .focus:
            return pomodoro.isOvertime ? .orange : .accentColor
        case .breakTime:
            return pomodoro.isOvertime ? .orange : .green
        case nil:
            return .accentColor
        }
    }

    private var phaseTitle: String {
        guard let kind = pomodoro.activeKind else {
            return langManager.text(.pomodoroTitle)
        }
        switch kind {
        case .focus:
            return pomodoro.isOvertime ? langManager.text(.overtimeLabel) : langManager.text(.focusLabel)
        case .breakTime:
            return langManager.text(.breakLabel)
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            headerRow
            boundTaskRow

            if pomodoro.state == .idle {
                idleBody
            } else {
                activeBody
            }
        }
        .padding(10)
        .background(statusColor.opacity(pomodoro.state == .idle ? 0.06 : 0.10))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(pomodoro.isOvertime ? Color.orange.opacity(0.45) : Color.secondary.opacity(0.12), lineWidth: 1)
        )
    }

    private var headerRow: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(pomodoro.state == .idle ? Color.secondary.opacity(0.4) : statusColor)
                .frame(width: 7, height: 7)

            Text(phaseTitle)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(pomodoro.isOvertime ? .orange : .primary)
                .lineLimit(1)

            Spacer()

            if pomodoro.state == .idle {
                Button(action: { showingDurations.toggle() }) {
                    HStack(spacing: 3) {
                        Text("\(pomodoro.focusMinutes)/\(pomodoro.breakMinutes)")
                            .font(.system(size: 10, weight: .medium))
                            .monospacedDigit()
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 9))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.12))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help(isTh ? "ตั้งเวลาทำงาน / พัก (นาที)" : "Configure focus & break durations")
                .popover(isPresented: $showingDurations, arrowEdge: .trailing) {
                    durationConfigPopover
                }
            } else {
                Text("\(isTh ? "รวม" : "Total") \(FocusDurationFormat.clock(pomodoro.elapsedSeconds))")
                    .font(.system(size: 10, weight: .medium))
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var boundTaskRow: some View {
        let boundTitle = pomodoro.state.session?.taskTitle ?? pomodoro.selectedTask?.title
        if let title = boundTitle {
            HStack(spacing: 4) {
                Image(systemName: "scope")
                    .font(.system(size: 9))
                    .foregroundColor(statusColor)
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 2)
                if pomodoro.state == .idle {
                    Button(action: { pomodoro.clearSelectedTask() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(isTh ? "เปลี่ยนเป็นโฟกัสอิสระ" : "Switch to free focus")
                }
            }
        } else if pomodoro.state != .idle {
            HStack(spacing: 4) {
                Image(systemName: "scope")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Text(langManager.text(.freeFocus))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var idleBody: some View {
        HStack(alignment: .center, spacing: compact ? 8 : 10) {
            Text(pomodoro.primaryClockDisplay)
                .font(.system(size: compact ? 20 : 22, weight: .bold, design: .rounded))
                .monospacedDigit()

            if !compact {
                Text("\(pomodoro.focusMinutes)m / \(pomodoro.breakMinutes)m")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: { pomodoro.startFocus() }) {
                HStack(spacing: 4) {
                    Image(systemName: "play.fill")
                        .font(.system(size: compact ? 9 : 10))
                    Text(langManager.text(.startFocus))
                        .font(.system(size: compact ? 10 : 11, weight: .semibold))
                }
                .padding(.horizontal, compact ? 8 : 10)
                .padding(.vertical, 5)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
    }

    private var activeBody: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(pomodoro.primaryClockDisplay)
                    .font(.system(size: compact ? 20 : 22, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(pomodoro.isOvertime ? .orange : .primary)

                Spacer()

                Text("/ \(FocusDurationFormat.clock(pomodoro.plannedSeconds))")
                    .font(.system(size: 10))
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }

            ProgressView(value: pomodoro.progress)
                .progressViewStyle(.linear)
                .tint(statusColor)
                .controlSize(.small)

            HStack(spacing: 6) {
                Button(action: { pomodoro.togglePause() }) {
                    Image(systemName: pomodoro.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 10))
                        .frame(width: 24, height: 22)
                        .background(Color.secondary.opacity(0.14))
                        .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .help(pomodoro.isPaused ? langManager.text(.resume) : langManager.text(.pause))

                let isFocus = pomodoro.activeKind == .focus
                Button(action: { isFocus ? pomodoro.startBreak() : pomodoro.startFocus() }) {
                    HStack(spacing: 3) {
                        Image(systemName: isFocus ? "cup.and.saucer.fill" : "play.fill")
                            .font(.system(size: 9))
                        Text(langManager.text(isFocus ? .takeBreak : .backToWork))
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 22)
                    .background(isFocus ? (pomodoro.isOvertime ? Color.orange : Color.green.opacity(0.85)) : Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)

                Button(action: { pomodoro.stopAndSave() }) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 9))
                        .frame(width: 24, height: 22)
                        .background(Color.secondary.opacity(0.14))
                        .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .help(langManager.text(.finishSave))
            }
        }
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
                presetButton(focus: 15, breakMins: 5)
                presetButton(focus: 25, breakMins: 5)
                presetButton(focus: 45, breakMins: 10)
                presetButton(focus: 50, breakMins: 10)
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

    @ViewBuilder
    private func presetButton(focus: Int, breakMins: Int) -> some View {
        let active = pomodoro.focusMinutes == focus && pomodoro.breakMinutes == breakMins
        Button(action: {
            pomodoro.focusMinutes = focus
            pomodoro.breakMinutes = breakMins
        }) {
            Text("\(focus)/\(breakMins)")
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
