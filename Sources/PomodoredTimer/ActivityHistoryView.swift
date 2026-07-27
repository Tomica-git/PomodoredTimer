import SwiftUI

struct ActivityHistoryView: View {
    @ObservedObject var model: TimerViewModel
    let close: () -> Void

    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var displayMode: ActivityHistoryDisplayMode = .timeline
    @State private var period: ActivityHistoryPeriod = .day

    private var selectedInterval: DateInterval {
        period.interval(containing: selectedDate, calendar: .current)
    }

    private var hours: [HourlyActivity] {
        model.hourlyActivity(on: selectedDate)
    }

    private var summary: DailyActivitySummary {
        model.activitySummary(from: selectedInterval.start, to: selectedInterval.end)
    }

    private var segments: [ActivitySegment] {
        model.activitySegments(on: selectedDate)
    }

    private var dailyBuckets: [DailyActivityBucket] {
        model.dailyActivity(from: selectedInterval.start, to: selectedInterval.end)
    }

    private var isCurrentPeriod: Bool {
        selectedInterval.contains(Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack {
                Button(action: close) {
                    Label("タイマー", systemImage: "chevron.left")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(Palette.teal)

                VStack(alignment: .leading, spacing: 2) {
                    Text("POMODORO TRACE")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(2.2)
                        .foregroundStyle(Palette.teal)
                    Text("作業と休憩の記録")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 7) {
                    HistoryPeriodControl(selection: $period)
                        .frame(width: 156)

                    HStack(spacing: 8) {
                        Button {
                            movePeriod(by: -1)
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        .accessibilityLabel(period.previousLabel)

                        Text(period.dateLabel(for: selectedInterval))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .frame(minWidth: period == .day ? 170 : 130)

                        Button {
                            movePeriod(by: 1)
                        } label: {
                            Image(systemName: "chevron.right")
                        }
                        .disabled(isCurrentPeriod)
                        .accessibilityLabel(period.nextLabel)

                        Button(period.currentLabel) {
                            selectedDate = Calendar.current.startOfDay(for: Date())
                        }
                        .disabled(isCurrentPeriod)
                        .fixedSize()
                    }
                }
            }

            HStack(spacing: 12) {
                HistorySummaryCard(
                    title: "ポモドーロ作業",
                    value: formatHistoryDuration(summary.focusSeconds),
                    detail: "赤バーの合計",
                    color: Palette.coral,
                    systemImage: "timer"
                )
                HistorySummaryCard(
                    title: "休憩",
                    value: formatHistoryDuration(summary.breakSeconds),
                    detail: "青バーの合計",
                    color: Palette.breakBlue,
                    systemImage: "cup.and.saucer.fill"
                )
                HistorySummaryCard(
                    title: "完了セット",
                    value: "\(summary.completedFocusSessions)",
                    detail: "最後まで集中",
                    color: Palette.teal,
                    systemImage: "checkmark.seal.fill"
                )
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(chartTitle)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    Spacer()
                    ChartLegend(color: Palette.coral, label: "集中")
                    ChartLegend(color: Palette.breakBlue, label: "休憩")
                    if period == .day {
                        HistoryDisplayModeControl(selection: $displayMode)
                            .frame(width: 150)
                    }
                }

                if period == .day, displayMode == .timeline {
                    DayTimelineView(
                        segments: segments,
                        date: selectedDate,
                        now: Calendar.current.isDateInToday(selectedDate) ? model.now : nil
                    )
                    .frame(height: 300)
                } else if period == .day {
                    ActivityHourChart(
                        hours: hours,
                        currentHour: Calendar.current.isDateInToday(selectedDate)
                            ? Calendar.current.component(.hour, from: model.now)
                            : nil
                    )
                    .frame(height: 255)

                    HStack {
                        Text("0")
                        Spacer()
                        Text("6")
                        Spacer()
                        Text("12")
                        Spacer()
                        Text("18")
                        Spacer()
                        Text("24時")
                    }
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Palette.muted)
                } else {
                    PeriodActivityChart(buckets: dailyBuckets, period: period)
                        .frame(height: 285)
                }
            }
            .padding(20)
            .background(Palette.panel.opacity(0.82), in: RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Palette.teal.opacity(0.12), lineWidth: 1)
            }

            HStack(spacing: 8) {
                Image(systemName: "lock.fill")
                Text("履歴はこのMac内に90日間保存されます。実際にタイマーが動いていた時間だけを記録します。")
            }
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Palette.muted)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 36)
        .padding(.top, 32)
        .padding(.bottom, 26)
        .background(Palette.canvas)
    }

    private var chartTitle: String {
        switch period {
        case .day:
            displayMode == .timeline ? "1日の時刻" : "24時間の合計"
        case .week:
            "1週間の日別合計"
        case .month:
            "1ヶ月の日別合計"
        }
    }

    private func movePeriod(by offset: Int) {
        guard let next = period.moving(selectedDate, by: offset, calendar: .current) else {
            return
        }
        selectedDate = min(Calendar.current.startOfDay(for: Date()), next)
    }
}

private enum ActivityHistoryPeriod: String, CaseIterable, Identifiable {
    case day
    case week
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day: "日"
        case .week: "週"
        case .month: "月"
        }
    }

    var currentLabel: String {
        switch self {
        case .day: "今日"
        case .week: "今週"
        case .month: "今月"
        }
    }

    var previousLabel: String { "前の\(title)" }
    var nextLabel: String { "次の\(title)" }

    func interval(containing date: Date, calendar: Calendar) -> DateInterval {
        switch self {
        case .day:
            return calendar.dateInterval(of: .day, for: date)
                ?? DateInterval(start: calendar.startOfDay(for: date), duration: 86_400)
        case .week:
            return TimerCalendarRanges.mondayWeek(containing: date, calendar: calendar)
        case .month:
            return calendar.dateInterval(of: .month, for: date)
                ?? DateInterval(start: calendar.startOfDay(for: date), duration: 86_400)
        }
    }

    func moving(_ date: Date, by offset: Int, calendar: Calendar) -> Date? {
        let component: Calendar.Component
        switch self {
        case .day: component = .day
        case .week: component = .day
        case .month: component = .month
        }
        let value = self == .week ? offset * 7 : offset
        return calendar.date(byAdding: component, value: value, to: date)
    }

    func dateLabel(for interval: DateInterval) -> String {
        switch self {
        case .day:
            return interval.start.formatted(
                .dateTime.year().month(.wide).day().weekday(.abbreviated)
            )
        case .week:
            let finalDay = interval.end.addingTimeInterval(-1)
            let startText = interval.start.formatted(.dateTime.month().day())
            let endText = finalDay.formatted(.dateTime.month().day())
            return "\(startText)〜\(endText)"
        case .month:
            return interval.start.formatted(.dateTime.year().month(.wide))
        }
    }

    func bucketLabel(for date: Date, index: Int, count: Int) -> String {
        switch self {
        case .day:
            return ""
        case .week:
            let weekday = date.formatted(.dateTime.weekday(.narrow))
            let day = Calendar.current.component(.day, from: date)
            return "\(weekday)\n\(day)"
        case .month:
            let day = Calendar.current.component(.day, from: date)
            return day == 1 || day.isMultiple(of: 5) || index == count - 1 ? "\(day)" : ""
        }
    }
}

private struct HistoryPeriodControl: View {
    @Binding var selection: ActivityHistoryPeriod

    var body: some View {
        HStack(spacing: 3) {
            ForEach(ActivityHistoryPeriod.allCases) { period in
                let isSelected = selection == period
                Button {
                    selection = period
                } label: {
                    Text(period.title)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(isSelected ? Color.white : Palette.muted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 25)
                        .background(
                            isSelected ? Palette.teal : Color.gray.opacity(0.16),
                            in: RoundedRectangle(cornerRadius: 7)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(period.title)ごとに表示")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.18), lineWidth: 1)
        }
    }
}

private enum ActivityHistoryDisplayMode: String, CaseIterable, Identifiable {
    case timeline
    case bars

    var id: String { rawValue }

    var title: String {
        switch self {
        case .timeline: "時刻表"
        case .bars: "棒グラフ"
        }
    }
}

private struct HistoryDisplayModeControl: View {
    @Binding var selection: ActivityHistoryDisplayMode

    var body: some View {
        HStack(spacing: 3) {
            ForEach(ActivityHistoryDisplayMode.allCases) { mode in
                let isSelected = selection == mode
                Button {
                    selection = mode
                } label: {
                    Text(mode.title)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(isSelected ? Color.white : Palette.muted)
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background(
                            isSelected ? Palette.teal : Color.gray.opacity(0.16),
                            in: RoundedRectangle(cornerRadius: 7)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.18), lineWidth: 1)
        }
    }
}

private struct DayTimelineView: View {
    let segments: [ActivitySegment]
    let date: Date
    let now: Date?

    private let hourHeight: CGFloat = 56
    private let labelWidth: CGFloat = 52

    private var calendar: Calendar { .current }
    private var dayStart: Date { calendar.startOfDay(for: date) }

    private var dayEnd: Date {
        calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86_400)
    }

    private var initialHour: Int {
        let reference = segments.first?.start ?? now
        guard let reference else { return 8 }
        return max(0, calendar.component(.hour, from: reference) - 1)
    }

    var body: some View {
        GeometryReader { proxy in
            ScrollViewReader { scrollProxy in
                ScrollView(.vertical) {
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Palette.canvas.opacity(0.42))
                            .frame(
                                width: max(0, proxy.size.width - labelWidth),
                                height: hourHeight * 24
                            )
                            .offset(x: labelWidth)

                        VStack(spacing: 0) {
                            ForEach(0..<24, id: \.self) { hour in
                                HStack(alignment: .top, spacing: 8) {
                                    Text(String(format: "%02d:00", hour))
                                        .frame(width: labelWidth - 8, alignment: .trailing)
                                    Rectangle()
                                        .fill(Palette.teal.opacity(hour.isMultiple(of: 6) ? 0.20 : 0.10))
                                        .frame(height: 1)
                                }
                                .frame(height: hourHeight, alignment: .top)
                                .id(hour)
                            }

                            HStack(alignment: .top, spacing: 8) {
                                Text("24:00")
                                    .frame(width: labelWidth - 8, alignment: .trailing)
                                Rectangle()
                                    .fill(Palette.teal.opacity(0.20))
                                    .frame(height: 1)
                            }
                        }
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Palette.muted)

                        ForEach(segments) { segment in
                            timelineBlock(for: segment, availableWidth: proxy.size.width)
                        }

                        if let now, now >= dayStart, now < dayEnd {
                            currentTimeLine(at: now, availableWidth: proxy.size.width)
                        }

                        if segments.isEmpty {
                            Text("この日の記録はありません")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Palette.muted)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(Palette.panel.opacity(0.92), in: Capsule())
                                .offset(x: labelWidth + 18, y: hourHeight * 8 + 14)
                        }
                    }
                    .frame(width: proxy.size.width, height: hourHeight * 24 + 18, alignment: .topLeading)
                }
                .scrollIndicators(.visible)
                .onAppear {
                    scrollToInitialHour(using: scrollProxy)
                }
                .onChange(of: date) { _, _ in
                    scrollToInitialHour(using: scrollProxy)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("0時から24時までの記録")
    }

    private func timelineBlock(for segment: ActivitySegment, availableWidth: CGFloat) -> some View {
        let startOffset = segment.start.timeIntervalSince(dayStart) / 3_600
        let durationHours = segment.duration / 3_600
        let y = CGFloat(max(0, startOffset)) * hourHeight
        let height = max(14, CGFloat(durationHours) * hourHeight)
        let color = segment.phase == .focus ? Palette.coral : Palette.breakBlue
        let label = segment.phase == .focus ? "集中" : "休憩"

        return HStack(spacing: 6) {
            Text(label)
                .fontWeight(.bold)
            Text("\(timelineTime(segment.start))–\(timelineTime(segment.end))")
                .monospacedDigit()
        }
        .font(.system(size: 10, weight: .medium, design: .rounded))
        .foregroundStyle(Color.white)
        .lineLimit(1)
        .padding(.horizontal, 8)
        .frame(
            width: max(0, availableWidth - labelWidth - 12),
            height: height,
            alignment: .leading
        )
        .background(color.opacity(0.90), in: RoundedRectangle(cornerRadius: 5))
        .overlay {
            RoundedRectangle(cornerRadius: 5)
                .stroke(color, lineWidth: 1)
        }
        .offset(x: labelWidth + 6, y: y)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label)、\(timelineTime(segment.start))から\(timelineTime(segment.end))")
    }

    private func currentTimeLine(at date: Date, availableWidth: CGFloat) -> some View {
        let offset = date.timeIntervalSince(dayStart) / 3_600
        return HStack(spacing: 5) {
            Circle()
                .fill(Palette.teal)
                .frame(width: 6, height: 6)
            Rectangle()
                .fill(Palette.teal.opacity(0.55))
                .frame(height: 1)
        }
        .frame(width: max(0, availableWidth - labelWidth - 4))
        .offset(x: labelWidth + 1, y: CGFloat(offset) * hourHeight - 3)
        .accessibilityHidden(true)
    }

    private func scrollToInitialHour(using proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            proxy.scrollTo(initialHour, anchor: .top)
        }
    }

    private func timelineTime(_ date: Date) -> String {
        if date == dayEnd {
            return "24:00"
        }
        return date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }
}

private struct ActivityHourChart: View {
    let hours: [HourlyActivity]
    let currentHour: Int?

    var body: some View {
        GeometryReader { proxy in
            let chartHeight = proxy.size.height

            ZStack(alignment: .bottom) {
                VStack {
                    ForEach(0..<4, id: \.self) { _ in
                        Divider()
                            .overlay(Palette.teal.opacity(0.10))
                        Spacer()
                    }
                }

                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(hours) { hour in
                        let focusHeight = chartHeight * min(1, hour.focusSeconds / 3_600)
                        let breakHeight = chartHeight * min(1, hour.breakSeconds / 3_600)

                        VStack(spacing: 1) {
                            if breakHeight > 0 {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Palette.breakBlue)
                                    .frame(height: breakHeight)
                            }
                            if focusHeight > 0 {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Palette.coral)
                                    .frame(height: focusHeight)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .background {
                            if currentHour == hour.hour {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Palette.teal.opacity(0.07))
                            }
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(
                            "\(hour.hour)時、集中\(spokenHistoryDuration(hour.focusSeconds))、休憩\(spokenHistoryDuration(hour.breakSeconds))"
                        )
                    }
                }
            }
        }
    }
}

private struct PeriodActivityChart: View {
    let buckets: [DailyActivityBucket]
    let period: ActivityHistoryPeriod

    private var maximumSeconds: TimeInterval {
        max(60, buckets.map(\.totalSeconds).max() ?? 0)
    }

    var body: some View {
        VStack(spacing: 7) {
            GeometryReader { proxy in
                let chartHeight = proxy.size.height

                ZStack(alignment: .bottom) {
                    VStack {
                        ForEach(0..<4, id: \.self) { _ in
                            Divider()
                                .overlay(Palette.teal.opacity(0.10))
                            Spacer()
                        }
                    }

                    HStack(alignment: .bottom, spacing: period == .month ? 3 : 12) {
                        ForEach(buckets) { bucket in
                            let focusHeight = chartHeight * 0.88 * bucket.focusSeconds / maximumSeconds
                            let breakHeight = chartHeight * 0.88 * bucket.breakSeconds / maximumSeconds

                            VStack(spacing: 1) {
                                if breakHeight > 0 {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Palette.breakBlue)
                                        .frame(height: breakHeight)
                                }
                                if focusHeight > 0 {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Palette.coral)
                                        .frame(height: focusHeight)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .background {
                                if Calendar.current.isDateInToday(bucket.date) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Palette.teal.opacity(0.07))
                                }
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(
                                "\(bucket.date.formatted(.dateTime.month().day()))、集中\(spokenHistoryDuration(bucket.focusSeconds))、休憩\(spokenHistoryDuration(bucket.breakSeconds))"
                            )
                        }
                    }
                }
            }

            HStack(alignment: .top, spacing: period == .month ? 3 : 12) {
                ForEach(Array(buckets.enumerated()), id: \.element.id) { index, bucket in
                    Text(period.bucketLabel(for: bucket.date, index: index, count: buckets.count))
                        .frame(maxWidth: .infinity)
                }
            }
            .font(.system(size: period == .month ? 9 : 10, weight: .medium, design: .monospaced))
            .foregroundStyle(Palette.muted)
            .frame(height: period == .week ? 28 : 14, alignment: .top)
        }
    }
}

private struct HistorySummaryCard: View {
    let title: String
    let value: String
    let detail: String
    let color: Color
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background(color.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Palette.muted)
                Text(value)
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(detail)
                    .font(.system(size: 9))
                    .foregroundStyle(Palette.muted)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Palette.panel.opacity(0.82), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct ChartLegend: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 12, height: 6)
            Text(label)
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(Palette.muted)
    }
}

private func formatHistoryDuration(_ seconds: TimeInterval) -> String {
    let totalMinutes = Int(seconds / 60)
    if totalMinutes >= 60 {
        return "\(totalMinutes / 60)時間\(totalMinutes % 60)分"
    }
    return "\(totalMinutes)分"
}

private func spokenHistoryDuration(_ seconds: TimeInterval) -> String {
    let totalMinutes = Int(seconds / 60)
    return "\(totalMinutes)分"
}
