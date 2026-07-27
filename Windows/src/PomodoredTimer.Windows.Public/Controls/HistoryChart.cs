using System.Globalization;
using System.Windows;
using System.Windows.Media;
using Color = System.Windows.Media.Color;
using Pen = System.Windows.Media.Pen;
using Point = System.Windows.Point;

namespace PomodoredTimer.Windows.Public.Controls;

public readonly record struct ChartBar(string Label, double FocusSeconds, double BreakSeconds);

public sealed class HistoryChart : FrameworkElement
{
    private IReadOnlyList<ChartBar> bars = [];

    public void SetBars(IReadOnlyList<ChartBar> value)
    {
        bars = value;
        InvalidateVisual();
    }

    protected override void OnRender(DrawingContext drawingContext)
    {
        base.OnRender(drawingContext);
        var border = new Pen(new SolidColorBrush(Color.FromArgb(45, 13, 92, 92)), 1);
        drawingContext.DrawRoundedRectangle(
            new SolidColorBrush(Color.FromArgb(120, 240, 248, 242)),
            border,
            new Rect(0, 0, Math.Max(0, ActualWidth), Math.Max(0, ActualHeight)),
            12,
            12);
        if (bars.Count == 0 || ActualWidth < 40 || ActualHeight < 40)
        {
            return;
        }

        const double left = 20;
        const double right = 14;
        const double top = 18;
        const double bottom = 30;
        var plotWidth = Math.Max(1, ActualWidth - left - right);
        var plotHeight = Math.Max(1, ActualHeight - top - bottom);
        var maximum = Math.Max(60, bars.Max(item => item.FocusSeconds + item.BreakSeconds));

        for (var line = 0; line <= 4; line++)
        {
            var y = top + plotHeight * line / 4;
            drawingContext.DrawLine(border, new Point(left, y), new Point(left + plotWidth, y));
        }

        var slot = plotWidth / bars.Count;
        var barWidth = Math.Max(2, Math.Min(24, slot * 0.65));
        var focusBrush = new SolidColorBrush(Color.FromRgb(232, 79, 69));
        var breakBrush = new SolidColorBrush(Color.FromRgb(51, 122, 184));
        var labelStride = bars.Count switch
        {
            <= 8 => 1,
            <= 24 => 3,
            _ => 5,
        };

        for (var index = 0; index < bars.Count; index++)
        {
            var item = bars[index];
            var x = left + slot * index + (slot - barWidth) / 2;
            var focusHeight = plotHeight * item.FocusSeconds / maximum;
            var breakHeight = plotHeight * item.BreakSeconds / maximum;
            var baseline = top + plotHeight;
            drawingContext.DrawRectangle(
                focusBrush,
                null,
                new Rect(x, baseline - focusHeight, barWidth, focusHeight));
            drawingContext.DrawRectangle(
                breakBrush,
                null,
                new Rect(x, baseline - focusHeight - breakHeight, barWidth, breakHeight));

            if (index % labelStride == 0 || index == bars.Count - 1)
            {
                var text = new FormattedText(
                    item.Label,
                    CultureInfo.CurrentCulture,
                    System.Windows.FlowDirection.LeftToRight,
                    new Typeface("Segoe UI"),
                    9,
                    new SolidColorBrush(Color.FromRgb(80, 107, 102)),
                    VisualTreeHelper.GetDpi(this).PixelsPerDip);
                drawingContext.DrawText(text, new Point(x + barWidth / 2 - text.Width / 2, baseline + 6));
            }
        }
    }
}
