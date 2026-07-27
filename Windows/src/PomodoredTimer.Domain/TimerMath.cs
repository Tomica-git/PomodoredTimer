namespace PomodoredTimer.Domain;

public static class TimerMath
{
    public static double ClampFastNeedleRate(double rate) => Math.Clamp(rate, 0.5, 5);

    public static TimerProjection Projection(
        double realElapsedSeconds,
        double durationSeconds,
        double fastRate)
    {
        var safeElapsed = Math.Min(durationSeconds, Math.Max(0, realElapsedSeconds));
        return new TimerProjection(
            safeElapsed,
            Math.Max(0, durationSeconds - safeElapsed),
            safeElapsed * ClampFastNeedleRate(fastRate));
    }

    public static double CountdownHandAngle(double remainingSeconds) =>
        Math.Max(0, remainingSeconds) / 60 * 6;

    public static double RemainingSectorFraction(double remainingSeconds) =>
        Math.Clamp(remainingSeconds / 3_600, 0, 1);

    public static double RemainingOverlapSectorFraction(double remainingSeconds) =>
        Math.Clamp((remainingSeconds - 3_600) / 3_600, 0, 1);

    public static double HandAngle(double elapsedSeconds) =>
        PositiveRemainder(elapsedSeconds, 60) / 60 * 360;

    public static string ClockString(double remainingSeconds)
    {
        var totalSeconds = Math.Max(0, (int)Math.Ceiling(remainingSeconds));
        return $"{totalSeconds / 60:00}:{totalSeconds % 60:00}";
    }

    private static double PositiveRemainder(double value, double divisor)
    {
        var remainder = value % divisor;
        return remainder < 0 ? remainder + divisor : remainder;
    }
}

public readonly record struct CalendarDateRange(DateOnly Start, DateOnly EndExclusive);

public static class TimerCalendarRanges
{
    public static CalendarDateRange MondayWeek(DateOnly date)
    {
        var daysSinceMonday = ((int)date.DayOfWeek + 6) % 7;
        var start = date.AddDays(-daysSinceMonday);
        return new CalendarDateRange(start, start.AddDays(7));
    }
}
