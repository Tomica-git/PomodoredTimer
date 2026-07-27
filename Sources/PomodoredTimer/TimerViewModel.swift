import AppKit
import Combine
import Foundation

@MainActor
final class TimerViewModel: ObservableObject {
    @Published var settings: TimerSettings
    @Published var phase: TimerPhase
    @Published var completedFocusSets: Int
    @Published var session: TimerSession
    @Published var fastNeedleRate: Double
    @Published private(set) var activityHistory: ActivityHistory
    @Published var now = Date()
    @Published var showCompletion = false
    @Published var showResetConfirmation = false
    @Published var showStateRecoveryWarning: Bool
    @Published var isCompactMode: Bool
    @Published var isAlwaysOnTop: Bool

    private static let storageKey = AppEdition.timerStateKey
    private static let unreadableStateBackupKey = AppEdition.unreadableStateBackupKey
    private static let compactModeKey = AppEdition.compactModeKey
    private static let alwaysOnTopKey = AppEdition.alwaysOnTopKey
    private var ticker: AnyCancellable?
    private var fastVisualElapsedBase: TimeInterval
    private var rateAnchorRealElapsed: TimeInterval
    private var soundScheduler = NeedleSoundScheduler()
    private var persistenceWritesBlocked: Bool
    private lazy var tickSound = loadSound(named: "tick")
    private lazy var tockSound = loadSound(named: "tock")

    init() {
        isCompactMode = UserDefaults.standard.bool(forKey: Self.compactModeKey)
        isAlwaysOnTop = UserDefaults.standard.bool(forKey: Self.alwaysOnTopKey)

        let storedData = UserDefaults.standard.data(forKey: Self.storageKey)
        let loadResult = PersistedTimerStateLoader.load(storedData)
        persistenceWritesBlocked = loadResult.shouldBlockWrites
        showStateRecoveryWarning = loadResult.shouldBlockWrites
        if loadResult.shouldBlockWrites, let storedData {
            UserDefaults.standard.set(storedData, forKey: Self.unreadableStateBackupKey)
        }

        if let saved = loadResult.state {
            settings = saved.settings
            phase = saved.phase
            completedFocusSets = saved.completedFocusSets
            session = saved.session
            fastNeedleRate = TimerMath.clampedFastNeedleRate(saved.shortNeedleRate)
            activityHistory = saved.activityHistory
            fastVisualElapsedBase = saved.shortVisualElapsedBase
            rateAnchorRealElapsed = saved.rateAnchorRealElapsed
        } else {
            let initialSettings = TimerSettings()
            settings = initialSettings
            phase = .focus
            completedFocusSets = 0
            session = TimerSession(duration: initialSettings.duration(for: .focus))
            fastNeedleRate = 2
            activityHistory = ActivityHistory()
            fastVisualElapsedBase = 0
            rateAnchorRealElapsed = 0
        }

        refresh()
        soundScheduler.reset(at: projection.fastNeedleElapsed)
        ticker = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in
                self?.tick(at: date)
            }
    }

    var projection: TimeProjection {
        let realElapsed = session.elapsed(at: now)
        let sinceRateChange = max(0, realElapsed - rateAnchorRealElapsed)
        return TimeProjection(
            realElapsed: realElapsed,
            remaining: session.remaining(at: now),
            fastNeedleElapsed: fastVisualElapsedBase + sinceRateChange * fastNeedleRate
        )
    }

    var primaryActionTitle: String {
        switch session.status {
        case .idle: "開始"
        case .running: "一時停止"
        case .paused: "再開"
        case .completed: "次のセッション"
        }
    }

    var menuBarTitle: String {
        TimerMath.clockString(projection.remaining)
    }

    var nextPhase: TimerPhase {
        TimerCycle.nextPhase(
            after: phase,
            completedFocusSets: completedFocusSets,
            focusSetsBeforeLongBreak: settings.focusSetsBeforeLongBreak
        )
    }

    func primaryAction() {
        now = Date()
        switch session.status {
        case .idle, .paused:
            session.start(at: now)
            soundScheduler.reset(at: projection.fastNeedleElapsed)
        case .running:
            recordActiveSegment(endingAt: now)
            session.pause(at: now)
        case .completed:
            moveToNextPhase()
            session.start(at: now)
        }
        persist()
    }

    func requestReset() {
        let hasCycleProgress = session.status != .idle
            || phase != .focus
            || completedFocusSets > 0
        if hasCycleProgress {
            showResetConfirmation = true
        } else {
            reset()
        }
    }

    func keepUnreadableState() {
        showStateRecoveryWarning = false
    }

    func replaceUnreadableStateWithFreshState() {
        guard persistenceWritesBlocked else { return }
        persistenceWritesBlocked = false
        showStateRecoveryWarning = false
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
        persist()
    }

    func reset() {
        now = Date()
        recordActiveSegment(endingAt: now)
        phase = .focus
        completedFocusSets = 0
        session = TimerSession(duration: settings.duration(for: .focus))
        resetVisualClock()
        showCompletion = false
        showResetConfirmation = false
        persist()
    }

    func applySettings() {
        guard settings.isValid else { return }
        if session.status == .idle {
            session.duration = settings.duration(for: phase)
        }
        persist()
    }

    func previewTick() {
        play(tickSound, volume: effectiveNeedleVolume(settings.tickVolume))
    }

    func previewTock() {
        play(tockSound, volume: effectiveNeedleVolume(settings.tockVolume))
    }

    func toggleNeedleSoundsMuted() {
        settings.needleSoundsMuted.toggle()
        applySettings()
    }

    func setCompactMode(_ compact: Bool) {
        isCompactMode = compact
        UserDefaults.standard.set(compact, forKey: Self.compactModeKey)
    }

    func toggleAlwaysOnTop() {
        isAlwaysOnTop.toggle()
        UserDefaults.standard.set(isAlwaysOnTop, forKey: Self.alwaysOnTopKey)
    }

    func setSpeed(_ speed: Double) {
        reanchorVisualClock()
        fastNeedleRate = TimerMath.clampedFastNeedleRate(speed)
        persist()
    }

    func hourlyActivity(on date: Date) -> [HourlyActivity] {
        historyIncludingActiveSegment.hourlyActivity(on: date)
    }

    func activitySegments(on date: Date) -> [ActivitySegment] {
        historyIncludingActiveSegment.activitySegments(on: date)
    }

    func activitySummary(on date: Date) -> DailyActivitySummary {
        historyIncludingActiveSegment.summary(on: date)
    }

    func activitySummary(from start: Date, to end: Date) -> DailyActivitySummary {
        historyIncludingActiveSegment.summary(from: start, to: end)
    }

    func dailyActivity(from start: Date, to end: Date) -> [DailyActivityBucket] {
        historyIncludingActiveSegment.dailyActivity(from: start, to: end)
    }

    func dismissCompletion() {
        showCompletion = false
    }

    private func tick(at date: Date) {
        now = date
        let soundEvents = soundScheduler.events(
            at: projection.fastNeedleElapsed,
            isAudible: session.status == .running
                && phase == .focus
                && !settings.needleSoundsMuted
        )
        if soundEvents.tick {
            play(tickSound, volume: effectiveNeedleVolume(settings.tickVolume))
        }
        if soundEvents.tock {
            play(tockSound, volume: effectiveNeedleVolume(settings.tockVolume))
        }
        if advanceCompletedSessions(upTo: date) > 0 {
            if settings.soundEnabled {
                NSSound(named: "Glass")?.play()
            }
            NSApplication.shared.requestUserAttention(.informationalRequest)
            persist()
        }
    }

    private func refresh() {
        now = Date()
        _ = advanceCompletedSessions(upTo: now)
    }

    private func moveToNextPhase() {
        let destination = nextPhase
        if phase == .focus {
            completedFocusSets += 1
        }
        phase = destination
        session = TimerSession(duration: settings.duration(for: phase))
        resetVisualClock()
        showCompletion = false
    }

    @discardableResult
    private func advanceCompletedSessions(upTo date: Date) -> Int {
        var completionCount = 0

        while
            session.status == .running,
            let completionDate = currentSessionCompletionDate,
            date >= completionDate
        {
            recordActiveSegment(endingAt: completionDate)
            guard session.completeIfNeeded(at: completionDate) else { break }

            if phase == .focus {
                activityHistory.recordCompletedFocus(at: completionDate)
            }
            completionCount += 1

            guard settings.automaticallyStartNextSession else {
                showCompletion = true
                break
            }

            moveToNextPhase()
            session.start(at: completionDate)
        }

        return completionCount
    }

    private var currentSessionCompletionDate: Date? {
        guard session.status == .running, let runningSince = session.runningSince else { return nil }
        let remainingAtResume = max(0, session.duration - session.accumulatedElapsed)
        return runningSince.addingTimeInterval(remainingAtResume)
    }

    private func recordActiveSegment(endingAt end: Date) {
        guard let start = session.runningSince else { return }
        activityHistory.record(start: start, end: end, phase: phase)
    }

    private var historyIncludingActiveSegment: ActivityHistory {
        guard session.status == .running else { return activityHistory }
        let end = min(now, currentSessionCompletionDate ?? now)
        return activityHistory.includingActiveSegment(
            start: session.runningSince,
            end: end,
            phase: phase
        )
    }

    private func reanchorVisualClock() {
        let current = projection
        fastVisualElapsedBase = current.fastNeedleElapsed
        rateAnchorRealElapsed = current.realElapsed
    }

    private func resetVisualClock() {
        fastVisualElapsedBase = 0
        rateAnchorRealElapsed = 0
        soundScheduler.reset(at: 0)
    }

    private func loadSound(named name: String) -> NSSound? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav") else { return nil }
        return NSSound(contentsOf: url, byReference: true)
    }

    private func play(_ sound: NSSound?, volume: Double) {
        guard volume > 0, let sound else { return }
        sound.stop()
        sound.volume = Float(volume)
        sound.play()
    }

    private func effectiveNeedleVolume(_ volume: Double) -> Double {
        settings.needleSoundsMuted ? 0 : volume
    }

    private func persist() {
        guard !persistenceWritesBlocked else { return }
        let state = PersistedTimerState(
            settings: settings,
            phase: phase,
            completedFocusSets: completedFocusSets,
            session: session,
            shortNeedleRate: fastNeedleRate,
            shortVisualElapsedBase: fastVisualElapsedBase,
            rateAnchorRealElapsed: rateAnchorRealElapsed,
            activityHistory: activityHistory
        )
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}
