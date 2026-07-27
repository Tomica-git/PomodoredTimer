namespace PomodoredTimer.Domain;

public enum TimerPhase
{
    Focus,
    ShortBreak,
    LongBreak,
}

public enum TimerStatus
{
    Idle,
    Running,
    Paused,
    Completed,
}

public static class TimerCycle
{
    public static TimerPhase NextPhase(
        TimerPhase phase,
        int completedFocusSets,
        int focusSetsBeforeLongBreak)
    {
        if (phase != TimerPhase.Focus)
        {
            return TimerPhase.Focus;
        }

        var nextCompleted = completedFocusSets + 1;
        return nextCompleted % Math.Max(1, focusSetsBeforeLongBreak) == 0
            ? TimerPhase.LongBreak
            : TimerPhase.ShortBreak;
    }
}

public sealed class TimerSettings
{
    public int FocusMinutes { get; set; } = 25;

    public int ShortBreakMinutes { get; set; } = 5;

    public int LongBreakMinutes { get; set; } = 15;

    public int FocusSetsBeforeLongBreak { get; set; } = 4;

    public bool AutomaticallyStartNextSession { get; set; }

    public bool CompletionSoundEnabled { get; set; } = true;

    public bool NeedleSoundsMuted { get; set; }

    public bool ReduceMotion { get; set; }

    public bool IsValid =>
        FocusMinutes is >= 10 and <= 90
        && ShortBreakMinutes is >= 3 and <= 30
        && LongBreakMinutes is >= 3 and <= 30
        && FocusSetsBeforeLongBreak is >= 1 and <= 12;

    public double DurationSeconds(TimerPhase phase) => phase switch
    {
        TimerPhase.Focus => FocusMinutes * 60d,
        TimerPhase.ShortBreak => ShortBreakMinutes * 60d,
        TimerPhase.LongBreak => LongBreakMinutes * 60d,
        _ => throw new ArgumentOutOfRangeException(nameof(phase)),
    };
}

public sealed class TimerSession
{
    public TimerStatus Status { get; set; } = TimerStatus.Idle;

    public double DurationSeconds { get; set; } = 25 * 60;

    public double AccumulatedElapsedSeconds { get; set; }

    public DateTimeOffset? RunningSinceUtc { get; set; }

    public double ElapsedAt(DateTimeOffset nowUtc)
    {
        var runningElapsed = RunningSinceUtc is null
            ? 0
            : Math.Max(0, (nowUtc - RunningSinceUtc.Value).TotalSeconds);
        return Math.Min(DurationSeconds, AccumulatedElapsedSeconds + runningElapsed);
    }

    public double RemainingAt(DateTimeOffset nowUtc) =>
        Math.Max(0, DurationSeconds - ElapsedAt(nowUtc));

    public DateTimeOffset? CompletionDate
    {
        get
        {
            if (Status != TimerStatus.Running || RunningSinceUtc is null)
            {
                return null;
            }

            var remainingAtResume = Math.Max(0, DurationSeconds - AccumulatedElapsedSeconds);
            return RunningSinceUtc.Value.AddSeconds(remainingAtResume);
        }
    }

    public void Start(DateTimeOffset nowUtc)
    {
        if (Status is not (TimerStatus.Idle or TimerStatus.Paused))
        {
            return;
        }

        RunningSinceUtc = nowUtc;
        Status = TimerStatus.Running;
    }

    public void Pause(DateTimeOffset nowUtc)
    {
        if (Status != TimerStatus.Running)
        {
            return;
        }

        AccumulatedElapsedSeconds = ElapsedAt(nowUtc);
        RunningSinceUtc = null;
        Status = TimerStatus.Paused;
    }

    public bool CompleteIfNeeded(DateTimeOffset nowUtc)
    {
        if (Status != TimerStatus.Running || ElapsedAt(nowUtc) < DurationSeconds)
        {
            return false;
        }

        AccumulatedElapsedSeconds = DurationSeconds;
        RunningSinceUtc = null;
        Status = TimerStatus.Completed;
        return true;
    }
}

public sealed class TimerState
{
    public const int CurrentSchemaVersion = 1;

    public int SchemaVersion { get; set; } = CurrentSchemaVersion;

    public string Platform { get; set; } = "windows";

    public string Edition { get; set; } = "public";

    public TimerSettings Settings { get; set; } = new();

    public TimerPhase Phase { get; set; } = TimerPhase.Focus;

    public int CompletedFocusSets { get; set; }

    public TimerSession Session { get; set; } = new();

    public double FastNeedleRate { get; set; } = 2;

    public double FastVisualElapsedBase { get; set; }

    public double RateAnchorRealElapsed { get; set; }

    public bool IsCompactMode { get; set; }

    public bool IsAlwaysOnTop { get; set; }

    public ActivityHistory ActivityHistory { get; set; } = new();

    public static TimerState CreateDefault()
    {
        var state = new TimerState();
        state.Session.DurationSeconds = state.Settings.DurationSeconds(TimerPhase.Focus);
        return state;
    }

    public bool IsValid =>
        SchemaVersion == CurrentSchemaVersion
        && string.Equals(Platform, "windows", StringComparison.Ordinal)
        && string.Equals(Edition, "public", StringComparison.Ordinal)
        && Settings.IsValid
        && Session.DurationSeconds > 0
        && FastNeedleRate is >= 0.5 and <= 5;
}

public readonly record struct TimerProjection(
    double RealElapsedSeconds,
    double RemainingSeconds,
    double FastNeedleElapsedSeconds);

public readonly record struct NeedleSoundEvents(bool Tick, bool Tock);

public sealed class NeedleSoundScheduler
{
    private int? lastTickIndex;
    private int? lastLapIndex;

    public void Reset(double fastNeedleElapsedSeconds)
    {
        lastTickIndex = Math.Max(0, (int)Math.Floor(fastNeedleElapsedSeconds));
        lastLapIndex = Math.Max(0, (int)Math.Floor(fastNeedleElapsedSeconds / 60));
    }

    public NeedleSoundEvents Events(double fastNeedleElapsedSeconds, bool isAudible)
    {
        var tickIndex = Math.Max(0, (int)Math.Floor(fastNeedleElapsedSeconds));
        var lapIndex = Math.Max(0, (int)Math.Floor(fastNeedleElapsedSeconds / 60));

        if (lastTickIndex is null || lastLapIndex is null)
        {
            Reset(fastNeedleElapsedSeconds);
            return default;
        }

        var result = new NeedleSoundEvents(
            Tick: isAudible && tickIndex > lastTickIndex,
            Tock: isAudible && lapIndex > lastLapIndex);
        lastTickIndex = tickIndex;
        lastLapIndex = lapIndex;
        return result;
    }
}
