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
            HStack(alignment: .firstTextBaseline) {
                Text(langManager.text(.focusInsights))
                    .font(.system(size: 18, weight: .bold))

                Spacer()

                Text(isTh
                     ? "วันนี้ \(FocusDurationFormat.human(pomodoro.todayFocusSeconds, lang: lang)) · รวม \(FocusDurationFormat.human(totalFocusSeconds, lang: lang)) (\(totalSessionCount))"
                     : "Today \(FocusDurationFormat.human(pomodoro.todayFocusSeconds, lang: lang)) · Total \(FocusDurationFormat.human(totalFocusSeconds, lang: lang)) (\(totalSessionCount))")
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()
                .opacity(0.4)

            if summaries.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text(isTh ? "ยังไม่มีประวัติการจับเวลา" : "No focus sessions yet")
                        .font(.system(size: 13, weight: .medium))
                    Text(isTh
                         ? "เริ่มจับเวลาที่งานใดก็ได้แล้วกดพักเมื่อเสร็จ"
                         : "Start a focus timer on any task and take a break when done.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        ForEach(summaries) { category in
                            categorySection(category)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 18)
                }
            }
        }
    }

    @ViewBuilder
    private func categorySection(_ cat: CategoryTimeSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(FocusAnalytics.displayCategory(cat.id, lang: lang))
                    .font(.system(size: 13.5, weight: .semibold))

                Text(calibrationLabel(cat.calibration))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(calibrationColor(cat.calibration))

                Spacer()

                Text(FocusDurationFormat.human(cat.totalActualSeconds, lang: lang))
                    .font(.system(size: 13, weight: .semibold))
                    .monospacedDigit()
            }

            HStack(spacing: 8) {
                Text(isTh
                     ? "ตั้งเฉลี่ย \(cat.averagePlannedMinutes) น. / จริง \(cat.averageActualMinutes) น. (\(FocusDurationFormat.signedDelta(cat.averageDeltaSeconds, lang: lang))) · \(cat.sessionCount) รอบ"
                     : "Planned \(cat.averagePlannedMinutes)m avg / actual \(cat.averageActualMinutes)m (\(FocusDurationFormat.signedDelta(cat.averageDeltaSeconds, lang: lang))) · \(cat.sessionCount)x")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                Spacer()

                if cat.calibration != .wellCalibrated && pomodoro.focusMinutes != cat.suggestedMinutes {
                    Button(action: { pomodoro.focusMinutes = cat.suggestedMinutes }) {
                        Text(isTh ? "ปรับเป็น \(cat.suggestedMinutes) น." : "Set \(cat.suggestedMinutes)m")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                ForEach(cat.tasks) { task in
                    HStack(spacing: 8) {
                        Text(task.taskTitle)
                            .font(.system(size: 12))
                            .foregroundColor(.primary.opacity(0.85))
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Spacer()

                        Text(FocusDurationFormat.signedDelta(task.totalActualSeconds - task.totalPlannedSeconds, lang: lang))
                            .font(.system(size: 10.5))
                            .monospacedDigit()
                            .foregroundColor(calibrationColor(task.calibration).opacity(0.9))

                        Text(FocusDurationFormat.human(task.totalActualSeconds, lang: lang))
                            .font(.system(size: 11.5, weight: .medium))
                            .monospacedDigit()
                            .frame(minWidth: 46, alignment: .trailing)

                        Text("\(task.sessionCount)x")
                            .font(.system(size: 10.5))
                            .foregroundColor(.secondary)
                            .frame(minWidth: 22, alignment: .trailing)
                    }
                    .padding(.leading, 8)
                }
            }
            .padding(.top, 2)

            Divider()
                .opacity(0.35)
                .padding(.top, 6)
        }
    }

    private func calibrationColor(_ cal: EstimationCalibration) -> Color {
        switch cal {
        case .underestimated: return .orange
        case .overestimated: return .blue
        case .wellCalibrated: return .green
        }
    }

    private func calibrationLabel(_ cal: EstimationCalibration) -> String {
        switch cal {
        case .underestimated: return isTh ? "ตั้งเวลาน้อยเกินไป" : "Set too short"
        case .overestimated: return isTh ? "ตั้งเวลาเยอะเกินไป" : "Set too long"
        case .wellCalibrated: return isTh ? "ตั้งเวลาพอดี" : "On target"
        }
    }
}
