using System.Globalization;
using System.Windows;
using PomodoredTimer.Application;
using PomodoredTimer.Domain;
using PomodoredTimer.Windows.Public.Controls;

namespace PomodoredTimer.Windows.Public;

public partial class HistoryWindow : Window
{
    private readonly TimerEngine engine;
    private DateOnly selectedDate = DateOnly.FromDateTime(DateTime.Now);
    private HistoryPeriod period = HistoryPeriod.Day;

    public HistoryWindow(TimerEngine engine)
    {
        this.engine = engine;
        InitializeComponent();
        RefreshHistory();
    }

    private void Period_Click(object sender, RoutedEventArgs e)
    {
        if (sender is not FrameworkElement { Tag: string tag })
        {
            return;
        }

        period = tag switch
        {
            "week" => HistoryPeriod.Week,
            "month" => HistoryPeriod.Month,
            _ => HistoryPeriod.Day,
        };
        RefreshHistory();
    }

    private void Previous_Click(object sender, RoutedEventArgs e)
    {
        selectedDate = period switch
        {
            HistoryPeriod.Day => selectedDate.AddDays(-1),
            HistoryPeriod.Week => selectedDate.AddDays(-7),
            HistoryPeriod.Month => selectedDate.AddMonths(-1),
            _ => selectedDate,
        };
        RefreshHistory();
    }

    private void Next_Click(object sender, RoutedEventArgs e)
    {
        selectedDate = period switch
        {
            HistoryPeriod.Day => selectedDate.AddDays(1),
            HistoryPeriod.Week => selectedDate.AddDays(7),
            HistoryPeriod.Month => selectedDate.AddMonths(1),
            _ => selectedDate,
        };
        RefreshHistory();
    }

    private void RefreshHistory()
    {
        var timeZone = TimeZoneInfo.Local;
        var history = engine.HistoryIncludingActiveSegment(DateTimeOffset.UtcNow);
        DateOnly start;
        DateOnly end;
        IReadOnlyList<ChartBar> bars;

        switch (period)
        {
            case HistoryPeriod.Day:
                start = selectedDate;
                end = start.AddDays(1);
                bars = history.HourlyActivity(start, timeZone)
                    .Select(item => new ChartBar($"{item.Hour:00}", item.FocusSeconds, item.BreakSeconds))
                    .ToList();
                RangeText.Text = start.ToString("yyyy年M月d日", CultureInfo.CurrentCulture);
                break;
            case HistoryPeriod.Week:
                var week = TimerCalendarRanges.MondayWeek(selectedDate);
                start = week.Start;
                end = week.EndExclusive;
                bars = history.DailyActivity(start, end, timeZone)
                    .Select(item => new ChartBar(item.Date.ToString("M/d", CultureInfo.CurrentCulture), item.FocusSeconds, item.BreakSeconds))
                    .ToList();
                RangeText.Text = $"{start:yyyy/M/d} — {end.AddDays(-1):M/d}";
                break;
            case HistoryPeriod.Month:
                start = new DateOnly(selectedDate.Year, selectedDate.Month, 1);
                end = start.AddMonths(1);
                bars = history.DailyActivity(start, end, timeZone)
                    .Select(item => new ChartBar(item.Date.Day.ToString(CultureInfo.InvariantCulture), item.FocusSeconds, item.BreakSeconds))
                    .ToList();
                RangeText.Text = start.ToString("yyyy年M月", CultureInfo.CurrentCulture);
                break;
            default:
                throw new ArgumentOutOfRangeException();
        }

        var summary = history.Summary(start, end, timeZone);
        FocusSummaryText.Text = DurationText(summary.FocusSeconds);
        BreakSummaryText.Text = DurationText(summary.BreakSeconds);
        SetsSummaryText.Text = summary.CompletedFocusSessions.ToString(CultureInfo.InvariantCulture);
        Chart.SetBars(bars);
    }

    private static string DurationText(double seconds)
    {
        var totalMinutes = Math.Max(0, (int)Math.Round(seconds / 60));
        return totalMinutes >= 60
            ? $"{totalMinutes / 60}時間 {totalMinutes % 60}分"
            : $"{totalMinutes}分";
    }

    private enum HistoryPeriod
    {
        Day,
        Week,
        Month,
    }
}
