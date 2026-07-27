import Foundation

@main
struct TimerCoreTestRunner {
    private static var failures = 0
    private static var assertions = 0

    static func main() {
        checkCountdownHandMovement()
        checkFastNeedleRateBounds()
        checkTwoTimesProjection()
        checkDeadlineIndependence()
        checkPause()
        checkTimestampRecovery()
        checkCompletionBoundary()
        checkSettingsBoundary()
        checkNeedleSoundMutePersistence()
        checkNeedleSoundSchedule()
        checkRateDrivenSoundFrequency()
        checkMenuBarClockFormatting()
        checkDurationKeyboardInput()
        checkAutomaticCycleOrder()
        checkHourlyActivityHistory()
        checkLegacyStateMigration()
        checkPersistenceFailClosed()
        checkMondayWeekRange()

        if failures > 0 {
            print("FAIL: \(failures) deterministic checks failed")
            exit(1)
        }
        print("PASS: \(assertions) deterministic timer assertions (public)")
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ name: String) {
        assertions += 1
        if !condition() {
            failures += 1
            print("FAIL: \(name)")
        }
    }

    private static func checkCountdownHandMovement() {
        expect(TimerMath.countdownHandAngle(remaining: 25 * 60) == 150, "25 minutes starts at 25th mark")
        expect(TimerMath.countdownHandAngle(remaining: 24 * 60) == 144, "one real minute moves back one mark")
        expect(TimerMath.countdownHandAngle(remaining: 0) == 0, "countdown hand returns to zero")
        expect(TimerMath.countdownHandAngle(remaining: 60 * 60) == 360, "60 minute boundary stays continuous")
        expect(TimerMath.countdownHandAngle(remaining: 59 * 60) == 354, "hand moves backward across 60 minutes")
        expect(
            abs(TimerMath.remainingSectorFraction(remaining: 25 * 60) - (25.0 / 60.0)) < 0.000_001,
            "25 minute remaining sector"
        )
        expect(TimerMath.remainingSectorFraction(remaining: 90 * 60) == 1, "over 60 minutes fills the dial")
        expect(
            TimerMath.remainingOverlapSectorFraction(remaining: 60 * 60) == 0,
            "60 minutes has no overlap sector"
        )
        expect(
            TimerMath.remainingOverlapSectorFraction(remaining: 90 * 60) == 0.5,
            "90 minutes darkens the overlapping half"
        )
    }

    private static func checkFastNeedleRateBounds() {
        expect(TimerMath.clampedFastNeedleRate(0.1) == 0.5, "fast needle lower bound")
        expect(TimerMath.clampedFastNeedleRate(4) == 4, "fast needle keeps in-range value")
        expect(TimerMath.clampedFastNeedleRate(5) == 5, "fast needle supports 5x")
        expect(TimerMath.clampedFastNeedleRate(8) == 5, "fast needle upper bound")
    }

    private static func checkTwoTimesProjection() {
        let projection = TimerMath.projection(
            realElapsed: 3_600,
            duration: 3_600,
            fastRate: 2
        )
        expect(projection.fastNeedleElapsed == 7_200, "2x red hand")
        expect(projection.remaining == 0, "real completion")
    }

    private static func checkDeadlineIndependence() {
        let slow = TimerMath.projection(realElapsed: 600, duration: 3_600, fastRate: 0.5)
        let fast = TimerMath.projection(realElapsed: 600, duration: 3_600, fastRate: 5)
        expect(slow.remaining == 3_000 && fast.remaining == 3_000, "speed-independent deadline")
        expect(
            TimerMath.countdownHandAngle(remaining: slow.remaining)
                == TimerMath.countdownHandAngle(remaining: fast.remaining),
            "black countdown hand ignores red speed"
        )
    }

    private static func checkPause() {
        let start = Date(timeIntervalSince1970: 1_000)
        var session = TimerSession(duration: 3_600)
        session.start(at: start)
        session.pause(at: start.addingTimeInterval(120))
        expect(session.elapsed(at: start.addingTimeInterval(900)) == 120, "pause excludes wall time")
    }

    private static func checkTimestampRecovery() {
        let start = Date(timeIntervalSince1970: 1_000)
        var session = TimerSession(duration: 1_500)
        session.start(at: start)
        expect(session.remaining(at: start.addingTimeInterval(601)) == 899, "timestamp recovery")
    }

    private static func checkCompletionBoundary() {
        let start = Date(timeIntervalSince1970: 1_000)
        var session = TimerSession(duration: 3_600)
        session.start(at: start)
        expect(!session.completeIfNeeded(at: start.addingTimeInterval(3_599)), "not early")
        expect(session.completeIfNeeded(at: start.addingTimeInterval(3_600)), "complete on deadline")
    }

    private static func checkSettingsBoundary() {
        var settings = TimerSettings()
        expect(settings.isValid, "default settings valid")
        settings.focusMinutes = 10
        settings.shortBreakMinutes = 3
        settings.longBreakMinutes = 30
        expect(settings.isValid, "new minimum and maximum settings valid")
        settings.focusMinutes = 9
        expect(!settings.isValid, "focus lower boundary")
        settings.focusMinutes = 91
        expect(!settings.isValid, "focus upper boundary")
    }

    private static func checkNeedleSoundMutePersistence() {
        let legacyJSON = Data("""
        {
          "focusMinutes": 25,
          "shortBreakMinutes": 5,
          "longBreakMinutes": 15,
          "focusSetsBeforeLongBreak": 4,
          "soundEnabled": true,
          "reduceMotion": false,
          "tickVolume": 0.35,
          "tockVolume": 0.55
        }
        """.utf8)
        let legacy = try? JSONDecoder().decode(TimerSettings.self, from: legacyJSON)
        expect(legacy?.needleSoundsMuted == false, "legacy settings default needle mute to off")

        var settings = TimerSettings()
        settings.needleSoundsMuted = true
        let data = try? JSONEncoder().encode(settings)
        let restored = data.flatMap { try? JSONDecoder().decode(TimerSettings.self, from: $0) }
        expect(restored?.needleSoundsMuted == true, "needle mute persists")
        expect(restored?.tickVolume == settings.tickVolume, "mute keeps tick volume")
        expect(restored?.tockVolume == settings.tockVolume, "mute keeps tock volume")
    }

    private static func checkNeedleSoundSchedule() {
        var scheduler = NeedleSoundScheduler()
        scheduler.reset(at: 0)
        expect(!scheduler.events(at: 0.9, isAudible: true).tick, "no tick before visual second")
        expect(scheduler.events(at: 1.0, isAudible: true).tick, "tick on visual second")
        let lap = scheduler.events(at: 60.0, isAudible: true)
        expect(lap.tick && lap.tock, "tick and tock on lap")
        expect(!scheduler.events(at: 90.0, isAudible: false).tick, "silent state consumes missed ticks")
        expect(!scheduler.events(at: 90.1, isAudible: true).tick, "no replay after silent period")
    }

    private static func checkRateDrivenSoundFrequency() {
        var scheduler = NeedleSoundScheduler()
        scheduler.reset(at: 0)
        var tickCount = 0
        for step in 1...100 {
            let realElapsed = Double(step) / 10
            if scheduler.events(at: realElapsed * 2, isAudible: true).tick {
                tickCount += 1
            }
        }
        expect(tickCount == 20, "2x produces 20 ticks in 10 real seconds")
    }

    private static func checkMenuBarClockFormatting() {
        expect(TimerMath.clockString(1_500) == "25:00", "menu bar formats 25 minutes")
        expect(TimerMath.clockString(179.1) == "03:00", "menu bar rounds remaining seconds up")
        expect(TimerMath.clockString(0) == "00:00", "menu bar formats completion")
    }

    private static func checkDurationKeyboardInput() {
        expect(DurationInput.asciiDigits(from: "90") == "90", "accept half-width digits")
        expect(DurationInput.asciiDigits(from: "９０") == "90", "convert full-width digits")
        expect(DurationInput.asciiDigits(from: "２a５") == "25", "convert mixed full-width digits")
        expect(DurationInput.asciiDigits(from: "2a5") == "25", "remove non-digits")
        expect(DurationInput.asciiDigits(from: "1234") == "123", "limit input length")
        expect(
            DurationInput.committedValue(from: "9", currentValue: 25, range: 10...90) == 10,
            "clamp below focus minimum"
        )
        expect(
            DurationInput.committedValue(from: "100", currentValue: 25, range: 10...90) == 90,
            "clamp above focus maximum"
        )
        expect(
            DurationInput.committedValue(from: "３０", currentValue: 25, range: 10...90) == 30,
            "commit converted full-width digits"
        )
        expect(
            DurationInput.committedValue(from: "", currentValue: 25, range: 10...90) == 25,
            "empty input restores current value"
        )
    }

    private static func checkAutomaticCycleOrder() {
        expect(
            TimerCycle.nextPhase(
                after: .focus,
                completedFocusSets: 0,
                focusSetsBeforeLongBreak: 4
            ) == .shortBreak,
            "first focus advances to short break"
        )
        expect(
            TimerCycle.nextPhase(
                after: .focus,
                completedFocusSets: 3,
                focusSetsBeforeLongBreak: 4
            ) == .longBreak,
            "fourth focus advances to long break"
        )
        expect(
            TimerCycle.nextPhase(
                after: .shortBreak,
                completedFocusSets: 1,
                focusSetsBeforeLongBreak: 4
            ) == .focus,
            "break advances to focus"
        )
    }


    private static func checkHourlyActivityHistory() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = calendar.date(from: DateComponents(year: 2026, month: 7, day: 26))!
        let focusStart = calendar.date(byAdding: .minute, value: 10 * 60 + 30, to: day)!
        let focusEnd = calendar.date(byAdding: .minute, value: 11 * 60 + 15, to: day)!
        let breakEnd = calendar.date(byAdding: .minute, value: 11 * 60 + 30, to: day)!

        var history = ActivityHistory()
        history.record(start: focusStart, end: focusEnd, phase: .focus)
        history.record(start: focusEnd, end: breakEnd, phase: .shortBreak)
        history.record(
            start: calendar.date(byAdding: .minute, value: -15, to: day)!,
            end: calendar.date(byAdding: .minute, value: 10, to: day)!,
            phase: .focus
        )
        history.recordCompletedFocus(at: focusEnd)

        let hours = history.hourlyActivity(on: day, calendar: calendar)
        expect(hours[0].focusSeconds == 600, "cross-midnight focus clips into today's first hour")
        expect(hours[10].focusSeconds == 1_800, "focus splits into 10 o'clock bucket")
        expect(hours[11].focusSeconds == 900, "focus splits into 11 o'clock bucket")
        expect(hours[11].breakSeconds == 900, "break uses blue 11 o'clock bucket")

        let summary = history.summary(on: day, calendar: calendar)
        expect(summary.focusSeconds == 3_300, "daily focus summary")
        expect(summary.breakSeconds == 900, "daily break summary")
        expect(summary.completedFocusSessions == 1, "daily completed pomodoro count")

        let segments = history.activitySegments(on: day, calendar: calendar)
        expect(segments.count == 3, "daily timeline returns intersecting segments")
        expect(segments[0].start == day, "timeline clips a segment at midnight")
        expect(segments[0].duration == 600, "timeline keeps only today's portion")
        expect(segments[1].start == focusStart, "timeline sorts segments by start time")

        let nextDay = calendar.date(byAdding: .day, value: 1, to: day)!
        let nextFocusStart = calendar.date(byAdding: .hour, value: 10, to: nextDay)!
        let nextFocusEnd = calendar.date(byAdding: .minute, value: 25, to: nextFocusStart)!
        let nextBreakStart = calendar.date(byAdding: .hour, value: 9, to: nextDay)!
        let nextBreakEnd = calendar.date(byAdding: .minute, value: 20, to: nextBreakStart)!
        history.record(start: nextFocusStart, end: nextFocusEnd, phase: .focus)
        history.record(start: nextBreakStart, end: nextBreakEnd, phase: .shortBreak)
        history.recordCompletedFocus(at: nextFocusEnd)

        let rangeEnd = calendar.date(byAdding: .day, value: 2, to: day)!
        let rangeSummary = history.summary(from: day, to: rangeEnd)
        expect(rangeSummary.focusSeconds == 4_800, "period focus summary spans days")
        expect(rangeSummary.breakSeconds == 2_100, "period break summary spans days")
        expect(rangeSummary.completedFocusSessions == 2, "period completed set summary spans days")

        let dailyBuckets = history.dailyActivity(from: day, to: rangeEnd, calendar: calendar)
        expect(dailyBuckets.count == 2, "period chart creates one bucket per day")
        expect(dailyBuckets[1].focusSeconds == 1_500, "second day focus bucket")
        expect(dailyBuckets[1].breakSeconds == 1_200, "second day break bucket")
        expect(dailyBuckets[1].completedFocusSessions == 1, "second day completed set bucket")
    }

    private static func checkLegacyStateMigration() {
        let legacyState = Data("""
        {
          "settings": {
            "focusMinutes": 25,
            "shortBreakMinutes": 5,
            "longBreakMinutes": 15,
            "focusSetsBeforeLongBreak": 4,
            "soundEnabled": true,
            "reduceMotion": false,
            "needleSoundsMuted": false,
            "tickVolume": 0.35,
            "tockVolume": 0.55
          },
          "phase": "focus",
          "completedFocusSets": 2,
          "session": {
            "status": "paused",
            "duration": 1500,
            "accumulatedElapsed": 300
          },
          "shortNeedleRate": 3,
          "linkedRates": false,
          "customLongNeedleRate": 1.25,
          "shortVisualElapsedBase": 900,
          "longVisualElapsedBase": 100,
          "rateAnchorRealElapsed": 300
        }
        """.utf8)

        let restored = try? JSONDecoder().decode(PersistedTimerState.self, from: legacyState)
        expect(restored?.completedFocusSets == 2, "legacy state keeps completed sets")
        expect(restored?.settings.automaticallyStartNextSession == false, "legacy auto transition defaults off")
        expect(restored?.activityHistory.segments.isEmpty == true, "legacy history defaults empty")
    }

    private static func checkPersistenceFailClosed() {
        let missing = PersistedTimerStateLoader.load(nil)
        expect(!missing.shouldBlockWrites, "missing state permits first save")

        let unreadable = PersistedTimerStateLoader.load(Data("{not-json".utf8))
        expect(unreadable.state == nil, "unreadable state is not treated as fresh data")
        expect(unreadable.shouldBlockWrites, "unreadable state blocks overwrite")

        let settings = TimerSettings()
        let validState = PersistedTimerState(
            settings: settings,
            phase: .focus,
            completedFocusSets: 2,
            session: TimerSession(duration: settings.duration(for: .focus)),
            shortNeedleRate: 2,
            shortVisualElapsedBase: 0,
            rateAnchorRealElapsed: 0,
            activityHistory: ActivityHistory()
        )
        let validData = try? JSONEncoder().encode(validState)
        let valid = PersistedTimerStateLoader.load(validData)
        expect(!valid.shouldBlockWrites, "valid state permits persistence")
        expect(valid.state?.completedFocusSets == 2, "valid state restores content")
    }

    private static func checkMondayWeekRange() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let sunday = calendar.date(from: DateComponents(year: 2026, month: 7, day: 26))!
        let range = TimerCalendarRanges.mondayWeek(containing: sunday, calendar: calendar)
        let start = calendar.dateComponents([.year, .month, .day], from: range.start)
        let end = calendar.dateComponents([.year, .month, .day], from: range.end)
        expect(start == DateComponents(year: 2026, month: 7, day: 20), "week starts Monday")
        expect(end == DateComponents(year: 2026, month: 7, day: 27), "week ends next Monday")
    }
}
