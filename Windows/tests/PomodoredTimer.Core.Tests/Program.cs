using System.Globalization;
using System.Text.Json;
using PomodoredTimer.Application;
using PomodoredTimer.Domain;

namespace PomodoredTimer.Core.Tests;

internal static class Program
{
    private static int failures;

    public static int Main(string[] args)
    {
        var vectorPath = args.Length > 0
            ? args[0]
            : Path.Combine("Shared", "TestVectors", "public-core-v1", "timer-vectors.json");

        CheckSharedVectors(vectorPath);
        CheckPauseExcludesWallTime();
        CheckAutomaticSessionTransition();
        CheckActivityHistory();
        CheckNinetyDayRetention();
        CheckNeedleSoundSchedule();
        CheckStateStoreRoundTripAndCorruptionRecovery();

        if (failures > 0)
        {
            Console.Error.WriteLine($"FAIL: {failures} Windows public core checks failed");
            return 1;
        }

        Console.WriteLine("PASS: Windows public core, storage isolation, and shared vectors");
        return 0;
    }

    private static void CheckSharedVectors(string vectorPath)
    {
        var document = JsonSerializer.Deserialize<VectorDocument>(
            File.ReadAllText(vectorPath),
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true });
        Expect(document?.SchemaVersion == 1, "shared vector schema");
        if (document is null)
        {
            return;
        }

        foreach (var item in document.ProjectionCases)
        {
            var projection = TimerMath.Projection(
                item.RealElapsedSeconds,
                item.DurationSeconds,
                item.FastRate);
            Expect(Near(projection.RemainingSeconds, item.RemainingSeconds), $"{item.Id} remaining");
            Expect(
                Near(projection.FastNeedleElapsedSeconds, item.FastNeedleElapsedSeconds),
                $"{item.Id} fast hand");
            Expect(
                Near(TimerMath.CountdownHandAngle(projection.RemainingSeconds), item.CountdownHandAngle),
                $"{item.Id} countdown hand");
        }

        foreach (var item in document.CycleCases)
        {
            var actual = TimerCycle.NextPhase(
                ParsePhase(item.Phase),
                item.CompletedFocusSets,
                item.FocusSetsBeforeLongBreak);
            Expect(actual == ParsePhase(item.Expected), $"{item.Id} cycle");
        }

        foreach (var item in document.WeekCases)
        {
            var range = TimerCalendarRanges.MondayWeek(
                DateOnly.ParseExact(item.Date, "yyyy-MM-dd", CultureInfo.InvariantCulture));
            Expect(
                range.Start.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture) == item.ExpectedStart,
                $"{item.Id} start");
            Expect(
                range.EndExclusive.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture)
                    == item.ExpectedEndExclusive,
                $"{item.Id} end");
        }
    }

    private static void CheckPauseExcludesWallTime()
    {
        var start = DateTimeOffset.Parse("2026-07-27T00:00:00Z");
        var session = new TimerSession { DurationSeconds = 1_500 };
        session.Start(start);
        session.Pause(start.AddSeconds(120));
        Expect(Near(session.ElapsedAt(start.AddHours(2)), 120), "paused wall time is excluded");
    }

    private static void CheckAutomaticSessionTransition()
    {
        var start = DateTimeOffset.Parse("2026-07-27T00:00:00Z");
        var state = TimerState.CreateDefault();
        state.Settings.AutomaticallyStartNextSession = true;
        state.Session.DurationSeconds = 10;
        var engine = new TimerEngine(state, start);
        engine.PrimaryAction(start);

        var first = engine.Update(start.AddSeconds(10));
        Expect(first.CompletedSessions == 1, "focus completion event");
        Expect(state.Phase == TimerPhase.ShortBreak, "focus moves to short break");
        Expect(state.CompletedFocusSets == 1, "focus set increments");
        Expect(state.Session.Status == TimerStatus.Running, "automatic break starts");

        var second = engine.Update(start.AddSeconds(10 + state.Settings.ShortBreakMinutes * 60));
        Expect(second.CompletedSessions == 1, "break completion event");
        Expect(state.Phase == TimerPhase.Focus, "break moves to focus");
        Expect(state.Session.Status == TimerStatus.Running, "automatic focus starts");
    }

    private static void CheckActivityHistory()
    {
        var history = new ActivityHistory();
        var day = DateTimeOffset.Parse("2026-07-27T00:00:00Z");
        history.Record(day.AddHours(10.5), day.AddHours(11.25), TimerPhase.Focus);
        history.Record(day.AddHours(11.25), day.AddHours(11.5), TimerPhase.ShortBreak);
        history.RecordCompletedFocus(day.AddHours(11.25));

        var summary = history.Summary(
            new DateOnly(2026, 7, 27),
            new DateOnly(2026, 7, 28),
            TimeZoneInfo.Utc);
        Expect(Near(summary.FocusSeconds, 2_700), "daily focus summary");
        Expect(Near(summary.BreakSeconds, 900), "daily break summary");
        Expect(summary.CompletedFocusSessions == 1, "daily completed summary");

        var hours = history.HourlyActivity(new DateOnly(2026, 7, 27), TimeZoneInfo.Utc);
        Expect(Near(hours[10].FocusSeconds, 1_800), "hourly focus split");
        Expect(Near(hours[11].FocusSeconds, 900), "hourly focus remainder");
        Expect(Near(hours[11].BreakSeconds, 900), "hourly break split");
    }

    private static void CheckNinetyDayRetention()
    {
        var history = new ActivityHistory();
        var now = DateTimeOffset.Parse("2026-07-27T00:00:00Z");
        history.Record(now.AddDays(-100), now.AddDays(-99), TimerPhase.Focus);
        history.Record(now.AddMinutes(-25), now, TimerPhase.Focus);
        Expect(history.Segments.Count == 1, "history trims older than 90 days");
    }

    private static void CheckNeedleSoundSchedule()
    {
        var scheduler = new NeedleSoundScheduler();
        scheduler.Reset(0);
        Expect(!scheduler.Events(0.9, true).Tick, "no tick before visual second");
        Expect(scheduler.Events(1, true).Tick, "tick on visual second");
        var lap = scheduler.Events(60, true);
        Expect(lap.Tick && lap.Tock, "tick and tock on visual lap");
        Expect(!scheduler.Events(90, false).Tick, "mute consumes missed ticks");
        Expect(!scheduler.Events(90.1, true).Tick, "no replay after mute");
    }

    private static void CheckStateStoreRoundTripAndCorruptionRecovery()
    {
        var directory = Path.Combine(Path.GetTempPath(), $"pomodored-state-test-{Guid.NewGuid():N}");
        try
        {
            var store = new PublicStateStore(directory);
            var state = TimerState.CreateDefault();
            state.CompletedFocusSets = 3;
            store.Save(state);

            var restored = store.Load();
            Expect(!restored.RecoveredFromCorruption, "valid state does not recover");
            Expect(restored.State.CompletedFocusSets == 3, "state round trip");
            Expect(restored.State.Platform == "windows", "state platform identity");
            Expect(restored.State.Edition == "public", "state edition identity");

            File.WriteAllText(store.StatePath, "{not-json");
            var recovered = store.Load();
            Expect(recovered.RecoveredFromCorruption, "corrupt state is quarantined");
            Expect(recovered.QuarantinePath is not null && File.Exists(recovered.QuarantinePath), "quarantine survives");
            Expect(!File.Exists(store.StatePath), "corrupt state is not overwritten");
        }
        finally
        {
            if (Directory.Exists(directory))
            {
                Directory.Delete(directory, recursive: true);
            }
        }
    }

    private static TimerPhase ParsePhase(string value) => value switch
    {
        "focus" => TimerPhase.Focus,
        "shortBreak" => TimerPhase.ShortBreak,
        "longBreak" => TimerPhase.LongBreak,
        _ => throw new InvalidDataException($"Unknown phase in shared vector: {value}"),
    };

    private static void Expect(bool condition, string name)
    {
        if (condition)
        {
            return;
        }

        failures++;
        Console.Error.WriteLine($"FAIL: {name}");
    }

    private static bool Near(double left, double right) => Math.Abs(left - right) < 0.000_001;

    private sealed class VectorDocument
    {
        public int SchemaVersion { get; set; }

        public List<ProjectionCase> ProjectionCases { get; set; } = [];

        public List<CycleCase> CycleCases { get; set; } = [];

        public List<WeekCase> WeekCases { get; set; } = [];
    }

    private sealed class ProjectionCase
    {
        public string Id { get; set; } = "";

        public double RealElapsedSeconds { get; set; }

        public double DurationSeconds { get; set; }

        public double FastRate { get; set; }

        public double RemainingSeconds { get; set; }

        public double FastNeedleElapsedSeconds { get; set; }

        public double CountdownHandAngle { get; set; }
    }

    private sealed class CycleCase
    {
        public string Id { get; set; } = "";

        public string Phase { get; set; } = "";

        public int CompletedFocusSets { get; set; }

        public int FocusSetsBeforeLongBreak { get; set; }

        public string Expected { get; set; } = "";
    }

    private sealed class WeekCase
    {
        public string Id { get; set; } = "";

        public string Date { get; set; } = "";

        public string ExpectedStart { get; set; } = "";

        public string ExpectedEndExclusive { get; set; } = "";
    }
}
