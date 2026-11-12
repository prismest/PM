import SwiftUI

public struct FocusAnalyticsView: View {
    @ObservedObject var store: TaskStore
    @ObservedObject var pomodoro: PomodoroManager
    @ObservedObject var langManager: LanguageManager = .shared

    public init(store: TaskStore, pomodoro: PomodoroManager? = nil) {
        self.store = store
        self.pomodoro = pomodoro ?? .shared
    }

    private var lang: AppLanguage { langManager.currentLanguage }
    private var isTh: Bool { lang == .th }

    private var summaries: [CategoryTimeSummary] {
        pomodoro.categorySummaries(tasks: store.tasks)
    }

    private var totalFocusSeconds: Int {
        summaries.reduce(0) { $0 + $1.totalActualSeconds }
    }

    private var totalSessionCount: Int {
        summaries.reduce(0) { $0 + $1.sessionCount }
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(langManager.text(.focusInsights))
                        .font(.system(size: 18, weight: .bold))
                        .lineLimit(1)
                    Text(isTh
                         ? "เทียบเวลาที่ตั้งกับเวลาทำจริงตามประเภทและงาน"
                         : "Planned vs actual time by category and task")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                HStack(spacing: 6) {
                    statPill(
                        label: isTh ? "วันนี้" : "Today",
                        value: FocusDurationFormat.human(pomodoro.todayFocusSeconds, lang: lang)
                    )
                    statPill(
                        label: isTh ? "รวมทั้งหมด" : "All Time",
                        value: "\(FocusDurationFormat.human(totalFocusSeconds, lang: lang)) (\(totalSessionCount))"
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()

            if summaries.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 38))
                        .foregroundColor(.accentColor.opacity(0.5))
                    Text(isTh ? "ยังไม่มีประวัติการจับเวลา" : "No focus sessions recorded yet")
                        .font(.system(size: 14, weight: .medium))
                    Text(isTh
                         ? "กดปุ่มเล่นที่งานใดก็ได้แล้วกดพักเมื่อเสร็จ ระบบจะวิเคราะห์ความแม่นยำให้อัตโนมัติ"
                         : "Start a focus timer on any task and press Break when done to track time calibration.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(summaries) { category in
                            categoryCard(category)
                        }
                    }
                    .padding(16)
                }
            }
        }
    }

    @ViewBuilder
    private func statPill(label: String, value: String) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(6)
    }

    @ViewBuilder
    private func categoryCard(_ cat: CategoryTimeSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Text(FocusAnalytics.displayCategory(cat.id, lang: lang))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)

                calibrationBadge(cat.calibration)

                Spacer()

                Text(FocusDurationFormat.human(cat.totalActualSeconds, lang: lang))
                    .font(.system(size: 13, weight: .bold))
                    .monospacedDigit()
                    .foregroundColor(.accentColor)
            }

            HStack(spacing: 8) {
                Text(isTh
                     ? "ตั้งเฉลี่ย \(cat.averagePlannedMinutes) น. / ทำจริง \(cat.averageActualMinutes) น. (\(FocusDurationFormat.signedDelta(cat.averageDeltaSeconds, lang: lang))) • \(cat.sessionCount) รอบ"
                     : "Avg planned \(cat.averagePlannedMinutes)m / actual \(cat.averageActualMinutes)m (\(FocusDurationFormat.signedDelta(cat.averageDeltaSeconds, lang: lang))) • \(cat.sessionCount)x")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Spacer()

                if cat.calibration != .wellCalibrated && pomodoro.focusMinutes != cat.suggestedMinutes {
                    Button(action: { pomodoro.focusMinutes = cat.suggestedMinutes }) {
                        Text(isTh ? "ตั้งเป็น \(cat.suggestedMinutes) น." : "Set \(cat.suggestedMinutes)m")
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.14))
                            .foregroundColor(.accentColor)
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .help(isTh ? "ปรับเวลาโฟกัสตั้งต้นให้เหมาะกับงานประเภทนี้" : "Apply suggested focus duration for this category")
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                ForEach(cat.tasks) { task in
                    HStack(spacing: 8) {
                        Text(task.taskTitle)
                            .font(.system(size: 12))
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Spacer()

                        Text(FocusDurationFormat.signedDelta(task.totalActualSeconds - task.totalPlannedSeconds, lang: lang))
                            .font(.system(size: 10, weight: .medium))
                            .monospacedDigit()
                            .foregroundColor(calibrationColor(task.calibration))

                        Text(FocusDurationFormat.human(task.totalActualSeconds, lang: lang))
                            .font(.system(size: 11, weight: .semibold))
                            .monospacedDigit()
                            .foregroundColor(.primary)

                        Text("(\(task.sessionCount)x)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.14), lineWidth: 1)
        )
    }

    private func calibrationColor(_ cal: EstimationCalibration) -> Color {
        switch cal {
        case .underestimated: return .orange
        case .overestimated: return .blue
        case .wellCalibrated: return .green
        }
    }

    @ViewBuilder
    private func calibrationBadge(_ cal: EstimationCalibration) -> some View {
        let color = calibrationColor(cal)
        let title: String = {
            switch cal {
            case .underestimated: return isTh ? "ตั้งเวลาน้อยเกินไป" : "Set too short"
            case .overestimated: return isTh ? "ตั้งเวลาเยอะเกินไป" : "Set too long"
            case .wellCalibrated: return isTh ? "ตั้งเวลาพอดี" : "Well calibrated"
            }
        }()

        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}
