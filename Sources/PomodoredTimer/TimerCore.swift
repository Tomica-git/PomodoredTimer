import Foundation

enum TimerPhase: String, Codable, CaseIterable, Sendable {
    case focus
    case shortBreak
    case longBreak

    var title: String {
        switch self {
        case .focus: "集中"
        case .shortBreak: "短い休憩"
        case .longBreak: "長い休憩"
        }
    }

    var nextLabel: String {
        switch self {
        case .focus: "休憩"
        case .shortBreak, .longBreak: "集中"
        }
    }
}

enum TimerStatus: String, Codable, Sendable {
    case idle
    case running
    case paused
    case completed
}

enum TimerCycle {
    static func nextPhase(
        after phase: TimerPhase,
        completedFocusSets: Int,
        focusSetsBeforeLongBreak: Int
    ) -> TimerPhase {
        guard phase == .focus else { return .focus }
        let nextCompleted = completedFocusSets + 1
        return nextCompleted.isMultiple(of: max(1, focusSetsBeforeLongBreak))
            ? .longBreak
            : .shortBreak
    }
}

struct TimerSettings: Codable, Equatable, Sendable {
    var focusMinutes = 25
    var shortBreakMinutes = 5
    var longBreakMinutes = 15
    var focusSetsBeforeLongBreak = 4
    var automaticallyStartNextSession = false
    var soundEnabled = true
    var reduceMotion = false
    var needleSoundsMuted = false
    var tickVolume = 0.35
    var tockVolume = 0.55

    private enum CodingKeys: String, CodingKey {
        case focusMinutes
        case shortBreakMinutes
        case longBreakMinutes
        case focusSetsBeforeLongBreak
        case automaticallyStartNextSession
        case soundEnabled
        case reduceMotion
        case needleSoundsMuted
        case tickVolume
        case tockVolume
    }

    init() { }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        focusMinutes = try container.decodeIfPresent(Int.self, forKey: .focusMinutes) ?? 25
        shortBreakMinutes = try container.decodeIfPresent(Int.self, forKey: .shortBreakMinutes) ?? 5
        longBreakMinutes = try container.decodeIfPresent(Int.self, forKey: .longBreakMinutes) ?? 15
        focusSetsBeforeLongBreak = try container.decodeIfPresent(Int.self, forKey: .focusSetsBeforeLongBreak) ?? 4
        automaticallyStartNextSession =
            try container.decodeIfPresent(Bool.self, forKey: .automaticallyStartNextSession) ?? false
        soundEnabled = try container.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? true
        reduceMotion = try container.decodeIfPresent(Bool.self, forKey: .reduceMotion) ?? false
        needleSoundsMuted = try container.decodeIfPresent(Bool.self, forKey: .needleSoundsMuted) ?? false
        tickVolume = try container.decodeIfPresent(Double.self, forKey: .tickVolume) ?? 0.35
        tockVolume = try container.decodeIfPresent(Double.self, forKey: .tockVolume) ?? 0.55
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(focusMinutes, forKey: .focusMinutes)
        try container.encode(shortBreakMinutes, forKey: .shortBreakMinutes)
        try container.encode(longBreakMinutes, forKey: .longBreakMinutes)
        try container.encode(focusSetsBeforeLongBreak, forKey: .focusSetsBeforeLongBreak)
        try container.encode(automaticallyStartNextSession, forKey: .automaticallyStartNextSession)
        try container.encode(soundEnabled, forKey: .soundEnabled)
        try container.encode(reduceMotion, forKey: .reduceMotion)
        try container.encode(needleSoundsMuted, forKey: .needleSoundsMuted)
        try container.encode(tickVolume, forKey: .tickVolume)
        try container.encode(tockVolume, forKey: .tockVolume)
    }

    var isValid: Bool {
        (10...90).contains(focusMinutes)
            && (3...30).contains(shortBreakMinutes)
            && (3...30).contains(longBreakMinutes)
            && (1...12).contains(focusSetsBeforeLongBreak)
            && (0...1).contains(tickVolume)
            && (0...1).contains(tockVolume)
    }

    func duration(for phase: TimerPhase) -> TimeInterval {
        let minutes: Int
        switch phase {
        case .focus: minutes = focusMinutes
        case .shortBreak: minutes = shortBreakMinutes
        case .longBreak: minutes = longBreakMinutes
        }
        return TimeInterval(minutes * 60)
    }
}

struct TimerSession: Codable, Equatable, Sendable {
    var status: TimerStatus = .idle
    var duration: TimeInterval
    var accumulatedElapsed: TimeInterval = 0
    var runningSince: Date?

    init(duration: TimeInterval) {
        self.duration = duration
    }

    func elapsed(at date: Date) -> TimeInterval {
        let active = runningSince.map { max(0, date.timeIntervalSince($0)) } ?? 0
        return min(duration, max(0, accumulatedElapsed + active))
    }

    func remaining(at date: Date) -> TimeInterval {
        max(0, duration - elapsed(at: date))
    }

    mutating func start(at date: Date) {
        guard status == .idle || status == .paused else { return }
        runningSince = date
        status = .running
    }

    mutating func pause(at date: Date) {
        guard status == .running else { return }
        accumulatedElapsed = elapsed(at: date)
        runningSince = nil
        status = .paused
    }

    mutating func reset() {
        accumulatedElapsed = 0
        runningSince = nil
        status = .idle
    }

    @discardableResult
    mutating func completeIfNeeded(at date: Date) -> Bool {
        guard status == .running, elapsed(at: date) >= duration else { return false }
        accumulatedElapsed = duration
        runningSince = nil
        status = .completed
        return true
    }
}

struct TimeProjection: Equatable, Sendable {
    let realElapsed: TimeInterval
    let remaining: TimeInterval
    let fastNeedleElapsed: TimeInterval
}

enum TimerMath {
    static func clampedFastNeedleRate(_ rate: Double) -> Double {
        min(5, max(0.5, rate))
    }

    static func projection(
        realElapsed: TimeInterval,
        duration: TimeInterval,
        fastRate: Double
    ) -> TimeProjection {
        let safeElapsed = min(duration, max(0, realElapsed))
        return TimeProjection(
            realElapsed: safeElapsed,
            remaining: max(0, duration - safeElapsed),
            fastNeedleElapsed: safeElapsed * fastRate
        )
    }

    static func countdownHandAngle(remaining: TimeInterval) -> Double {
        let remainingMinutes = max(0, remaining) / 60
        return remainingMinutes * 6
    }

    static func remainingSectorFraction(remaining: TimeInterval) -> Double {
        min(1, max(0, remaining / 3_600))
    }

    static func remainingOverlapSectorFraction(remaining: TimeInterval) -> Double {
        min(1, max(0, (remaining - 3_600) / 3_600))
    }

    static func handAngle(elapsed: TimeInterval, rate: Double) -> Double {
        let cyclePosition = (elapsed * rate).truncatingRemainder(dividingBy: 60)
        return cyclePosition / 60 * 360
    }

    static func clockString(_ seconds: TimeInterval) -> String {
        let rounded = max(0, Int(ceil(seconds)))
        return String(format: "%02d:%02d", rounded / 60, rounded % 60)
    }
}

enum DurationInput {
    static func asciiDigits(from text: String, maximumLength: Int = 3) -> String {
        var result = ""
        for scalar in text.unicodeScalars {
            let asciiValue: UInt32?
            switch scalar.value {
            case 48...57:
                asciiValue = scalar.value
            case 0xFF10...0xFF19:
                asciiValue = scalar.value - 0xFF10 + 48
            default:
                asciiValue = nil
            }

            if let asciiValue, let converted = UnicodeScalar(asciiValue) {
                result.append(Character(String(converted)))
                if result.count == maximumLength {
                    break
                }
            }
        }
        return result
    }

    static func committedValue(
        from text: String,
        currentValue: Int,
        range: ClosedRange<Int>
    ) -> Int {
        let digits = asciiDigits(from: text)
        guard let value = Int(digits) else { return currentValue }
        return min(range.upperBound, max(range.lowerBound, value))
    }
}

struct NeedleSoundEvents: Equatable, Sendable {
    let tick: Bool
    let tock: Bool
}

struct NeedleSoundScheduler: Equatable, Sendable {
    private(set) var lastTickIndex: Int?
    private(set) var lastLapIndex: Int?

    mutating func reset(at fastNeedleElapsed: TimeInterval) {
        lastTickIndex = max(0, Int(floor(fastNeedleElapsed)))
        lastLapIndex = max(0, Int(floor(fastNeedleElapsed / 60)))
    }

    mutating func events(
        at fastNeedleElapsed: TimeInterval,
        isAudible: Bool
    ) -> NeedleSoundEvents {
        let tickIndex = max(0, Int(floor(fastNeedleElapsed)))
        let lapIndex = max(0, Int(floor(fastNeedleElapsed / 60)))

        guard let previousTick = lastTickIndex, let previousLap = lastLapIndex else {
            reset(at: fastNeedleElapsed)
            return NeedleSoundEvents(tick: false, tock: false)
        }

        lastTickIndex = tickIndex
        lastLapIndex = lapIndex

        guard isAudible else {
            return NeedleSoundEvents(tick: false, tock: false)
        }
        return NeedleSoundEvents(
            tick: tickIndex > previousTick,
            tock: lapIndex > previousLap
        )
    }
}

struct ActivitySegment: Codable, Equatable, Sendable, Identifiable {
    let id: UUID
    let start: Date
    let end: Date
    let phase: TimerPhase

    init(id: UUID = UUID(), start: Date, end: Date, phase: TimerPhase) {
        self.id = id
        self.start = start
        self.end = end
        self.phase = phase
    }

    var duration: TimeInterval {
        max(0, end.timeIntervalSince(start))
    }
}

struct HourlyActivity: Equatable, Sendable, Identifiable {
    let hour: Int
    var focusSeconds: TimeInterval
    var breakSeconds: TimeInterval

    var id: Int { hour }
    var totalSeconds: TimeInterval { focusSeconds + breakSeconds }
}

struct DailyActivitySummary: Equatable, Sendable {
    let focusSeconds: TimeInterval
    let breakSeconds: TimeInterval
    let completedFocusSessions: Int
}

struct DailyActivityBucket: Equatable, Sendable, Identifiable {
    let date: Date
    let focusSeconds: TimeInterval
    let breakSeconds: TimeInterval
    let completedFocusSessions: Int

    var id: Date { date }
    var totalSeconds: TimeInterval { focusSeconds + breakSeconds }
}

struct ActivityHistory: Codable, Equatable, Sendable {
    private(set) var segments: [ActivitySegment] = []
    private(set) var completedFocusDates: [Date] = []

    mutating func record(start: Date, end: Date, phase: TimerPhase) {
        guard end > start else { return }
        segments.append(ActivitySegment(start: start, end: end, phase: phase))
        trim(relativeTo: end)
    }

    mutating func recordCompletedFocus(at date: Date) {
        completedFocusDates.append(date)
        trim(relativeTo: date)
    }

    func includingActiveSegment(start: Date?, end: Date, phase: TimerPhase) -> ActivityHistory {
        guard let start, end > start else { return self }
        var copy = self
        copy.record(start: start, end: end, phase: phase)
        return copy
    }

    func hourlyActivity(
        on date: Date,
        calendar: Calendar = .current
    ) -> [HourlyActivity] {
        let dayStart = calendar.startOfDay(for: date)
        return (0..<24).map { hour in
            guard
                let hourStart = calendar.date(byAdding: .hour, value: hour, to: dayStart),
                let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourStart)
            else {
                return HourlyActivity(hour: hour, focusSeconds: 0, breakSeconds: 0)
            }

            var result = HourlyActivity(hour: hour, focusSeconds: 0, breakSeconds: 0)
            for segment in segments {
                let overlap = Self.overlap(
                    start: segment.start,
                    end: segment.end,
                    rangeStart: hourStart,
                    rangeEnd: hourEnd
                )
                guard overlap > 0 else { continue }
                if segment.phase == .focus {
                    result.focusSeconds += overlap
                } else {
                    result.breakSeconds += overlap
                }
            }
            return result
        }
    }

    func activitySegments(
        on date: Date,
        calendar: Calendar = .current
    ) -> [ActivitySegment] {
        let dayStart = calendar.startOfDay(for: date)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return []
        }

        return segments.compactMap { segment in
            let clippedStart = max(segment.start, dayStart)
            let clippedEnd = min(segment.end, dayEnd)
            guard clippedEnd > clippedStart else { return nil }
            return ActivitySegment(
                id: segment.id,
                start: clippedStart,
                end: clippedEnd,
                phase: segment.phase
            )
        }
        .sorted { $0.start < $1.start }
    }

    func summary(
        on date: Date,
        calendar: Calendar = .current
    ) -> DailyActivitySummary {
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        return summary(from: dayStart, to: dayEnd)
    }

    func summary(from start: Date, to end: Date) -> DailyActivitySummary {
        guard end > start else {
            return DailyActivitySummary(focusSeconds: 0, breakSeconds: 0, completedFocusSessions: 0)
        }

        var focusSeconds: TimeInterval = 0
        var breakSeconds: TimeInterval = 0
        for segment in segments {
            let duration = Self.overlap(
                start: segment.start,
                end: segment.end,
                rangeStart: start,
                rangeEnd: end
            )
            guard duration > 0 else { continue }
            if segment.phase == .focus {
                focusSeconds += duration
            } else {
                breakSeconds += duration
            }
        }

        return DailyActivitySummary(
            focusSeconds: focusSeconds,
            breakSeconds: breakSeconds,
            completedFocusSessions: completedFocusDates.count {
                $0 >= start && $0 < end
            }
        )
    }

    func dailyActivity(
        from start: Date,
        to end: Date,
        calendar: Calendar = .current
    ) -> [DailyActivityBucket] {
        guard end > start else { return [] }
        var buckets: [DailyActivityBucket] = []
        var dayStart = calendar.startOfDay(for: start)

        while dayStart < end {
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                break
            }
            let rangeStart = max(start, dayStart)
            let rangeEnd = min(end, dayEnd)
            let daySummary = summary(from: rangeStart, to: rangeEnd)
            buckets.append(
                DailyActivityBucket(
                    date: dayStart,
                    focusSeconds: daySummary.focusSeconds,
                    breakSeconds: daySummary.breakSeconds,
                    completedFocusSessions: daySummary.completedFocusSessions
                )
            )
            dayStart = dayEnd
        }

        return buckets
    }

    private mutating func trim(relativeTo date: Date) {
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: date) ?? .distantPast
        segments.removeAll { $0.end < cutoff }
        completedFocusDates.removeAll { $0 < cutoff }
    }

    private static func overlap(
        start: Date,
        end: Date,
        rangeStart: Date,
        rangeEnd: Date
    ) -> TimeInterval {
        max(0, min(end, rangeEnd).timeIntervalSince(max(start, rangeStart)))
    }
}

struct PersistedTimerState: Codable, Sendable {
    var settings: TimerSettings
    var phase: TimerPhase
    var completedFocusSets: Int
    var session: TimerSession
    var shortNeedleRate: Double
    var shortVisualElapsedBase: TimeInterval
    var rateAnchorRealElapsed: TimeInterval
    var activityHistory: ActivityHistory

    private enum CodingKeys: String, CodingKey {
        case settings
        case phase
        case completedFocusSets
        case session
        case shortNeedleRate
        case shortVisualElapsedBase
        case rateAnchorRealElapsed
        case activityHistory
    }

    init(
        settings: TimerSettings,
        phase: TimerPhase,
        completedFocusSets: Int,
        session: TimerSession,
        shortNeedleRate: Double,
        shortVisualElapsedBase: TimeInterval,
        rateAnchorRealElapsed: TimeInterval,
        activityHistory: ActivityHistory
    ) {
        self.settings = settings
        self.phase = phase
        self.completedFocusSets = completedFocusSets
        self.session = session
        self.shortNeedleRate = shortNeedleRate
        self.shortVisualElapsedBase = shortVisualElapsedBase
        self.rateAnchorRealElapsed = rateAnchorRealElapsed
        self.activityHistory = activityHistory
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        settings = try container.decode(TimerSettings.self, forKey: .settings)
        phase = try container.decode(TimerPhase.self, forKey: .phase)
        completedFocusSets = try container.decode(Int.self, forKey: .completedFocusSets)
        session = try container.decode(TimerSession.self, forKey: .session)
        shortNeedleRate = try container.decode(Double.self, forKey: .shortNeedleRate)
        shortVisualElapsedBase =
            try container.decodeIfPresent(TimeInterval.self, forKey: .shortVisualElapsedBase) ?? 0
        rateAnchorRealElapsed =
            try container.decodeIfPresent(TimeInterval.self, forKey: .rateAnchorRealElapsed) ?? 0
        activityHistory =
            try container.decodeIfPresent(ActivityHistory.self, forKey: .activityHistory) ?? ActivityHistory()
    }
}

struct PersistedTimerStateLoadResult {
    let state: PersistedTimerState?
    let shouldBlockWrites: Bool
}

enum PersistedTimerStateLoader {
    static func load(_ data: Data?) -> PersistedTimerStateLoadResult {
        guard let data else {
            return PersistedTimerStateLoadResult(state: nil, shouldBlockWrites: false)
        }

        guard
            let state = try? JSONDecoder().decode(PersistedTimerState.self, from: data),
            state.settings.isValid
        else {
            return PersistedTimerStateLoadResult(state: nil, shouldBlockWrites: true)
        }

        return PersistedTimerStateLoadResult(state: state, shouldBlockWrites: false)
    }
}

enum TimerCalendarRanges {
    static func mondayWeek(containing date: Date, calendar: Calendar) -> DateInterval {
        var mondayCalendar = calendar
        mondayCalendar.firstWeekday = 2
        mondayCalendar.minimumDaysInFirstWeek = 4

        let day = mondayCalendar.startOfDay(for: date)
        let weekday = mondayCalendar.component(.weekday, from: day)
        let daysSinceMonday = (weekday + 5) % 7
        let start = mondayCalendar.date(byAdding: .day, value: -daysSinceMonday, to: day) ?? day
        let end = mondayCalendar.date(byAdding: .day, value: 7, to: start)
            ?? start.addingTimeInterval(7 * 86_400)
        return DateInterval(start: start, end: end)
    }
}
