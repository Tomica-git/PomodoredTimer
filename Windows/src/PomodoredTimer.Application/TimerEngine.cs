using PomodoredTimer.Domain;

namespace PomodoredTimer.Application;

public readonly record struct TimerEffects(
    bool Tick,
    bool Tock,
    int CompletedSessions,
    bool StateChanged);

public sealed class TimerEngine
{
    private readonly NeedleSoundScheduler soundScheduler = new();

    public TimerEngine(TimerState state, DateTimeOffset nowUtc)
    {
        State = state.IsValid ? state : throw new ArgumentException("Invalid public timer state.", nameof(state));
        soundScheduler.Reset(Projection(nowUtc).FastNeedleElapsedSeconds);
    }

    public TimerState State { get; }

    public TimerProjection Projection(DateTimeOffset nowUtc)
    {
        var realElapsed = State.Session.ElapsedAt(nowUtc);
        var sinceRateChange = Math.Max(0, realElapsed - State.RateAnchorRealElapsed);
        return new TimerProjection(
            realElapsed,
            State.Session.RemainingAt(nowUtc),
            State.FastVisualElapsedBase + sinceRateChange * State.FastNeedleRate);
    }

    public TimerPhase NextPhase => TimerCycle.NextPhase(
        State.Phase,
        State.CompletedFocusSets,
        State.Settings.FocusSetsBeforeLongBreak);

    public void PrimaryAction(DateTimeOffset nowUtc)
    {
        switch (State.Session.Status)
        {
            case TimerStatus.Idle:
            case TimerStatus.Paused:
                State.Session.Start(nowUtc);
                soundScheduler.Reset(Projection(nowUtc).FastNeedleElapsedSeconds);
                break;
            case TimerStatus.Running:
                RecordActiveSegment(nowUtc);
                State.Session.Pause(nowUtc);
                break;
            case TimerStatus.Completed:
                MoveToNextPhase();
                State.Session.Start(nowUtc);
                break;
            default:
                throw new ArgumentOutOfRangeException();
        }
    }

    public void Reset(DateTimeOffset nowUtc)
    {
        RecordActiveSegment(nowUtc);
        State.Phase = TimerPhase.Focus;
        State.CompletedFocusSets = 0;
        State.Session = NewSession(TimerPhase.Focus);
        ResetVisualClock();
    }

    public void ApplySettings()
    {
        if (!State.Settings.IsValid)
        {
            throw new InvalidOperationException("Timer settings are outside the public edition limits.");
        }

        if (State.Session.Status == TimerStatus.Idle)
        {
            State.Session.DurationSeconds = State.Settings.DurationSeconds(State.Phase);
        }
    }

    public void SetSpeed(double speed, DateTimeOffset nowUtc)
    {
        var current = Projection(nowUtc);
        State.FastVisualElapsedBase = current.FastNeedleElapsedSeconds;
        State.RateAnchorRealElapsed = current.RealElapsedSeconds;
        State.FastNeedleRate = TimerMath.ClampFastNeedleRate(speed);
    }

    public TimerEffects Update(DateTimeOffset nowUtc)
    {
        var projection = Projection(nowUtc);
        var sounds = soundScheduler.Events(
            projection.FastNeedleElapsedSeconds,
            State.Session.Status == TimerStatus.Running
                && State.Phase == TimerPhase.Focus
                && !State.Settings.NeedleSoundsMuted);

        var completions = AdvanceCompletedSessions(nowUtc);
        return new TimerEffects(
            sounds.Tick,
            sounds.Tock,
            completions,
            completions > 0);
    }

    public ActivityHistory HistoryIncludingActiveSegment(DateTimeOffset nowUtc)
    {
        if (State.Session.Status != TimerStatus.Running)
        {
            return State.ActivityHistory;
        }

        var completionDate = State.Session.CompletionDate ?? nowUtc;
        var endUtc = nowUtc < completionDate ? nowUtc : completionDate;
        return State.ActivityHistory.IncludingActiveSegment(
            State.Session.RunningSinceUtc,
            endUtc,
            State.Phase);
    }

    private int AdvanceCompletedSessions(DateTimeOffset nowUtc)
    {
        var completionCount = 0;
        while (State.Session.Status == TimerStatus.Running
            && State.Session.CompletionDate is { } completionDate
            && nowUtc >= completionDate)
        {
            RecordActiveSegment(completionDate);
            if (!State.Session.CompleteIfNeeded(completionDate))
            {
                break;
            }

            if (State.Phase == TimerPhase.Focus)
            {
                State.ActivityHistory.RecordCompletedFocus(completionDate);
            }

            completionCount++;
            if (!State.Settings.AutomaticallyStartNextSession)
            {
                break;
            }

            MoveToNextPhase();
            State.Session.Start(completionDate);
        }

        return completionCount;
    }

    private void MoveToNextPhase()
    {
        var destination = NextPhase;
        if (State.Phase == TimerPhase.Focus)
        {
            State.CompletedFocusSets++;
        }

        State.Phase = destination;
        State.Session = NewSession(destination);
        ResetVisualClock();
    }

    private TimerSession NewSession(TimerPhase phase) => new()
    {
        DurationSeconds = State.Settings.DurationSeconds(phase),
    };

    private void RecordActiveSegment(DateTimeOffset endUtc)
    {
        if (State.Session.RunningSinceUtc is not { } startUtc)
        {
            return;
        }

        State.ActivityHistory.Record(startUtc, endUtc, State.Phase);
    }

    private void ResetVisualClock()
    {
        State.FastVisualElapsedBase = 0;
        State.RateAnchorRealElapsed = 0;
        soundScheduler.Reset(0);
    }
}
