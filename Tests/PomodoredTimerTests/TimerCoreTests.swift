import Foundation
import Testing
@testable import PomodoredTimer

@Suite("Pomodored Timer core")
struct TimerCoreTests {
    @Test("2倍速は赤針だけを速め、残り時間は変えない")
    func twoTimesProjection() {
        let projection = TimerMath.projection(
            realElapsed: 3_600,
            duration: 3_600,
            fastRate: 2
        )

        #expect(projection.realElapsed == 3_600)
        #expect(projection.fastNeedleElapsed == 7_200)
        #expect(projection.remaining == 0)
    }

    @Test("黒針は25分位置から実時間1分で1目盛り戻る")
    func countdownHandMovement() {
        #expect(TimerMath.countdownHandAngle(remaining: 25 * 60) == 150)
        #expect(TimerMath.countdownHandAngle(remaining: 24 * 60) == 144)
        #expect(TimerMath.countdownHandAngle(remaining: 0) == 0)
        #expect(TimerMath.countdownHandAngle(remaining: 60 * 60) == 360)
        #expect(TimerMath.countdownHandAngle(remaining: 59 * 60) == 354)
        #expect(
            abs(TimerMath.remainingSectorFraction(remaining: 25 * 60) - (25.0 / 60.0))
                < 0.000_001
        )
        #expect(TimerMath.remainingOverlapSectorFraction(remaining: 60 * 60) == 0)
        #expect(TimerMath.remainingOverlapSectorFraction(remaining: 90 * 60) == 0.5)
    }

    @Test("長針の速度は0.5倍から5倍に収める")
    func fastNeedleRateBounds() {
        #expect(TimerMath.clampedFastNeedleRate(0.1) == 0.5)
        #expect(TimerMath.clampedFastNeedleRate(4) == 4)
        #expect(TimerMath.clampedFastNeedleRate(5) == 5)
        #expect(TimerMath.clampedFastNeedleRate(8) == 5)
    }

    @Test("針速度は実時間の残り時間を変えない")
    func speedDoesNotChangeDeadline() {
        let slow = TimerMath.projection(realElapsed: 600, duration: 3_600, fastRate: 0.5)
        let fast = TimerMath.projection(realElapsed: 600, duration: 3_600, fastRate: 5)
        #expect(slow.remaining == 3_000)
        #expect(fast.remaining == 3_000)
        #expect(
            TimerMath.countdownHandAngle(remaining: slow.remaining)
                == TimerMath.countdownHandAngle(remaining: fast.remaining)
        )
    }

    @Test("一時停止中の時間は経過時間に含めない")
    func pauseExcludesWallTime() {
        let start = Date(timeIntervalSince1970: 1_000)
        var session = TimerSession(duration: 3_600)
        session.start(at: start)
        session.pause(at: start.addingTimeInterval(120))

        #expect(session.elapsed(at: start.addingTimeInterval(900)) == 120)
        #expect(session.remaining(at: start.addingTimeInterval(900)) == 3_480)
    }

    @Test("バックグラウンド相当の時間も開始時刻から復元する")
    func timestampRecovery() {
        let start = Date(timeIntervalSince1970: 1_000)
        var session = TimerSession(duration: 1_500)
        session.start(at: start)

        #expect(session.elapsed(at: start.addingTimeInterval(601)) == 601)
        #expect(session.remaining(at: start.addingTimeInterval(601)) == 899)
    }

    @Test("実時間が設定時間に達するまで完了しない")
    func deterministicCompletion() {
        let start = Date(timeIntervalSince1970: 1_000)
        var session = TimerSession(duration: 3_600)
        session.start(at: start)

        #expect(session.completeIfNeeded(at: start.addingTimeInterval(3_599)) == false)
        #expect(session.status == .running)
        #expect(session.completeIfNeeded(at: start.addingTimeInterval(3_600)) == true)
        #expect(session.status == .completed)
    }

    @Test("設定値の境界を検証する")
    func settingsBoundary() {
        var settings = TimerSettings()
        settings.focusMinutes = 10
        settings.shortBreakMinutes = 3
        settings.longBreakMinutes = 30
        settings.focusSetsBeforeLongBreak = 1
        #expect(settings.isValid)

        settings.focusMinutes = 91
        #expect(!settings.isValid)
    }

    @Test("針音ミュートは保存され、旧設定では解除状態になる")
    func needleSoundMutePersistence() throws {
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
        let legacy = try JSONDecoder().decode(TimerSettings.self, from: legacyJSON)
        #expect(!legacy.needleSoundsMuted)

        var settings = TimerSettings()
        settings.needleSoundsMuted = true
        let restored = try JSONDecoder().decode(
            TimerSettings.self,
            from: JSONEncoder().encode(settings)
        )
        #expect(restored.needleSoundsMuted)
        #expect(restored.tickVolume == settings.tickVolume)
        #expect(restored.tockVolume == settings.tockVolume)
    }

    @Test("半角数字入力を検証する")
    func durationKeyboardInput() {
        #expect(DurationInput.asciiDigits(from: "90") == "90")
        #expect(DurationInput.asciiDigits(from: "９０") == "90")
        #expect(DurationInput.committedValue(from: "３０", currentValue: 25, range: 10...90) == 30)
        #expect(DurationInput.committedValue(from: "100", currentValue: 25, range: 10...90) == 90)
    }

    @Test("集中と休憩は設定したセット順で自動遷移する")
    func automaticCycleOrder() {
        #expect(
            TimerCycle.nextPhase(
                after: .focus,
                completedFocusSets: 0,
                focusSetsBeforeLongBreak: 4
            ) == .shortBreak
        )
        #expect(
            TimerCycle.nextPhase(
                after: .focus,
                completedFocusSets: 3,
                focusSetsBeforeLongBreak: 4
            ) == .longBreak
        )
        #expect(
            TimerCycle.nextPhase(
                after: .longBreak,
                completedFocusSets: 4,
                focusSetsBeforeLongBreak: 4
            ) == .focus
        )
    }


    @Test("作業と休憩を現在時刻の1時間単位へ分割する")
    func hourlyActivityHistory() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = calendar.date(from: DateComponents(year: 2026, month: 7, day: 26))!
        let focusStart = calendar.date(byAdding: .minute, value: 630, to: day)!
        let focusEnd = calendar.date(byAdding: .minute, value: 675, to: day)!
        let breakEnd = calendar.date(byAdding: .minute, value: 690, to: day)!

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
        #expect(hours[0].focusSeconds == 600)
        #expect(hours[10].focusSeconds == 1_800)
        #expect(hours[11].focusSeconds == 900)
        #expect(hours[11].breakSeconds == 900)

        let summary = history.summary(on: day, calendar: calendar)
        #expect(summary.focusSeconds == 3_300)
        #expect(summary.breakSeconds == 900)
        #expect(summary.completedFocusSessions == 1)

        let segments = history.activitySegments(on: day, calendar: calendar)
        #expect(segments.count == 3)
        #expect(segments[0].start == day)
        #expect(segments[0].duration == 600)
        #expect(segments[1].start == focusStart)

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
        #expect(rangeSummary.focusSeconds == 4_800)
        #expect(rangeSummary.breakSeconds == 2_100)
        #expect(rangeSummary.completedFocusSessions == 2)

        let dailyBuckets = history.dailyActivity(from: day, to: rangeEnd, calendar: calendar)
        #expect(dailyBuckets.count == 2)
        #expect(dailyBuckets[1].focusSeconds == 1_500)
        #expect(dailyBuckets[1].breakSeconds == 1_200)
        #expect(dailyBuckets[1].completedFocusSessions == 1)
    }
}
