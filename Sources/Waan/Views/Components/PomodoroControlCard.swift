import SwiftUI

public struct TimerClockFace: View {
    public let progress: Double
    public let elapsedSeconds: Int
    public let color: Color
    public let size: CGFloat
    public let isPaused: Bool

    public init(
        progress: Double,
        elapsedSeconds: Int,
        color: Color,
        size: CGFloat = 38,
        isPaused: Bool = false
    ) {
        self.progress = min(max(progress, 0), 1)
        self.elapsedSeconds = max(0, elapsedSeconds)
        self.color = color
        self.size = size
        self.isPaused = isPaused
    }

    public var body: some View {
        let strokeWidth = max(2, size * 0.065)
        let ringSize = size - strokeWidth
        let gap = max(1.5, size * 0.045)
        let minuteHandLen = size * 0.27
        let secondHandLen = size * 0.34
        let dotSize = max(3.5, size * 0.11)

        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.16), lineWidth: strokeWidth)
                .frame(width: ringSize, height: ringSize)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round))
                .frame(width: ringSize, height: ringSize)
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.25), value: progress)

            ForEach(0..<12, id: \.self) { index in
                let major = index % 3 == 0
                let tickH = major ? size * 0.09 : size * 0.055
                let tickW = major ? max(1.2, size * 0.03) : max(0.8, size * 0.02)
                let tickOffset = (ringSize * 0.5) - (strokeWidth * 0.5) - gap - (tickH * 0.5)
                Rectangle()
                    .fill(Color.secondary.opacity(major ? 0.55 : 0.25))
                    .frame(width: tickW, height: tickH)
                    .offset(y: -tickOffset)
                    .rotationEffect(.degrees(Double(index) * 30))
            }

            Capsule()
                .fill(Color.primary.opacity(0.85))
                .frame(width: max(1.6, size * 0.048), height: minuteHandLen)
                .offset(y: -minuteHandLen * 0.5)
                .rotationEffect(.degrees(progress * 360.0))

            Capsule()
                .fill(color.opacity(isPaused ? 0.45 : 0.95))
                .frame(width: max(1.0, size * 0.028), height: secondHandLen)
                .offset(y: -secondHandLen * 0.5)
                .rotationEffect(.degrees(Double(elapsedSeconds) * 6.0))
                .animation(.linear(duration: 0.2), value: elapsedSeconds)

            Circle()
                .fill(color)
                .frame(width: dotSize, height: dotSize)
        }
        .frame(width: size, height: size)
    }
}

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

    public var body: some View {
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
