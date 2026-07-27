namespace PomodoredTimer.Domain;

public sealed class ActivitySegment
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public DateTimeOffset StartUtc { get; set; }

    public DateTimeOffset EndUtc { get; set; }

    public TimerPhase Phase { get; set; }

    public double DurationSeconds => Math.Max(0, (EndUtc - StartUtc).TotalSeconds);
}

public readonly record struct ActivitySummary(
    double FocusSeconds,
    double BreakSeconds,
    int CompletedFocusSessions);

public readonly record struct DailyActivityBucket(
    DateOnly Date,
    double FocusSeconds,
    double BreakSeconds,
    int CompletedFocusSessions);

public readonly record struct HourlyActivityBucket(
    int Hour,
    double FocusSeconds,
    double BreakSeconds);

public sealed class ActivityHistory
{
    public List<ActivitySegment> Segments { get; set; } = [];

    public List<DateTimeOffset> CompletedFocusDatesUtc { get; set; } = [];

    public void Record(DateTimeOffset startUtc, DateTimeOffset endUtc, TimerPhase phase)
    {
        if (endUtc <= startUtc)
        {
            return;
        }

        Segments.Add(new ActivitySegment
        {
            StartUtc = startUtc,
            EndUtc = endUtc,
            Phase = phase,
        });
        Trim(endUtc);
    }

    public void RecordCompletedFocus(DateTimeOffset dateUtc)
    {
        CompletedFocusDatesUtc.Add(dateUtc);
        Trim(dateUtc);
    }

    public ActivityHistory IncludingActiveSegment(
        DateTimeOffset? startUtc,
        DateTimeOffset endUtc,
        TimerPhase phase)
    {
        var copy = new ActivityHistory
        {
            Segments = Segments.Select(CloneSegment).ToList(),
            CompletedFocusDatesUtc = [.. CompletedFocusDatesUtc],
        };
        if (startUtc is not null)
        {
            copy.Record(startUtc.Value, endUtc, phase);
        }

        return copy;
    }

    public ActivitySummary Summary(
        DateOnly startDate,
        DateOnly endDateExclusive,
        TimeZoneInfo timeZone)
    {
        var startUtc = LocalMidnightUtc(startDate, timeZone);
        var endUtc = LocalMidnightUtc(endDateExclusive, timeZone);
        var focus = 0d;
        var rest = 0d;

        foreach (var segment in Segments)
        {
            var overlap = OverlapSeconds(segment.StartUtc, segment.EndUtc, startUtc, endUtc);
            if (segment.Phase == TimerPhase.Focus)
            {
                focus += overlap;
            }
            else
            {
                rest += overlap;
            }
        }

        var completed = CompletedFocusDatesUtc.Count(date => date >= startUtc && date < endUtc);
        return new ActivitySummary(focus, rest, completed);
    }

    public IReadOnlyList<DailyActivityBucket> DailyActivity(
        DateOnly startDate,
        DateOnly endDateExclusive,
        TimeZoneInfo timeZone)
    {
        var result = new List<DailyActivityBucket>();
        for (var date = startDate; date < endDateExclusive; date = date.AddDays(1))
        {
            var summary = Summary(date, date.AddDays(1), timeZone);
            result.Add(new DailyActivityBucket(
                date,
                summary.FocusSeconds,
                summary.BreakSeconds,
                summary.CompletedFocusSessions));
        }

        return result;
    }

    public IReadOnlyList<HourlyActivityBucket> HourlyActivity(
        DateOnly date,
        TimeZoneInfo timeZone)
    {
        var buckets = new List<HourlyActivityBucket>(24);
        for (var hour = 0; hour < 24; hour++)
        {
            var localStart = date.ToDateTime(new TimeOnly(hour, 0), DateTimeKind.Unspecified);
            var localEnd = hour == 23
                ? date.AddDays(1).ToDateTime(TimeOnly.MinValue, DateTimeKind.Unspecified)
                : date.ToDateTime(new TimeOnly(hour + 1, 0), DateTimeKind.Unspecified);

            if (timeZone.IsInvalidTime(localStart) || timeZone.IsInvalidTime(localEnd))
            {
                buckets.Add(new HourlyActivityBucket(hour, 0, 0));
                continue;
            }

            var startUtc = new DateTimeOffset(TimeZoneInfo.ConvertTimeToUtc(localStart, timeZone));
            var endUtc = new DateTimeOffset(TimeZoneInfo.ConvertTimeToUtc(localEnd, timeZone));
            var focus = 0d;
            var rest = 0d;
            foreach (var segment in Segments)
            {
                var overlap = OverlapSeconds(segment.StartUtc, segment.EndUtc, startUtc, endUtc);
                if (segment.Phase == TimerPhase.Focus)
                {
                    focus += overlap;
                }
                else
                {
                    rest += overlap;
                }
            }

            buckets.Add(new HourlyActivityBucket(hour, focus, rest));
        }

        return buckets;
    }

    private void Trim(DateTimeOffset relativeToUtc)
    {
        var cutoff = relativeToUtc.AddDays(-90);
        Segments.RemoveAll(segment => segment.EndUtc < cutoff);
        CompletedFocusDatesUtc.RemoveAll(date => date < cutoff);
    }

    private static ActivitySegment CloneSegment(ActivitySegment source) => new()
    {
        Id = source.Id,
        StartUtc = source.StartUtc,
        EndUtc = source.EndUtc,
        Phase = source.Phase,
    };

    private static DateTimeOffset LocalMidnightUtc(DateOnly date, TimeZoneInfo timeZone)
    {
        var local = date.ToDateTime(TimeOnly.MinValue, DateTimeKind.Unspecified);
        if (timeZone.IsInvalidTime(local))
        {
            local = local.AddHours(1);
        }

        return new DateTimeOffset(TimeZoneInfo.ConvertTimeToUtc(local, timeZone));
    }

    private static double OverlapSeconds(
        DateTimeOffset start,
        DateTimeOffset end,
        DateTimeOffset rangeStart,
        DateTimeOffset rangeEnd)
    {
        var overlapStart = start > rangeStart ? start : rangeStart;
        var overlapEnd = end < rangeEnd ? end : rangeEnd;
        return Math.Max(0, (overlapEnd - overlapStart).TotalSeconds);
    }
}
