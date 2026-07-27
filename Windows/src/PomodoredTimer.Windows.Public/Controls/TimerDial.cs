using System.Windows;
using System.Windows.Media;
using PomodoredTimer.Domain;
using Brush = System.Windows.Media.Brush;
using Brushes = System.Windows.Media.Brushes;
using Color = System.Windows.Media.Color;
using Pen = System.Windows.Media.Pen;
using Point = System.Windows.Point;
using Size = System.Windows.Size;

namespace PomodoredTimer.Windows.Public.Controls;

public sealed class TimerDial : FrameworkElement
{
    public static readonly DependencyProperty RemainingSecondsProperty = DependencyProperty.Register(
        nameof(RemainingSeconds),
        typeof(double),
        typeof(TimerDial),
        new FrameworkPropertyMetadata(0d, FrameworkPropertyMetadataOptions.AffectsRender));

    public static readonly DependencyProperty FastNeedleElapsedSecondsProperty = DependencyProperty.Register(
        nameof(FastNeedleElapsedSeconds),
        typeof(double),
        typeof(TimerDial),
        new FrameworkPropertyMetadata(0d, FrameworkPropertyMetadataOptions.AffectsRender));

    public double RemainingSeconds
    {
        get => (double)GetValue(RemainingSecondsProperty);
        set => SetValue(RemainingSecondsProperty, value);
    }

    public double FastNeedleElapsedSeconds
    {
        get => (double)GetValue(FastNeedleElapsedSecondsProperty);
        set => SetValue(FastNeedleElapsedSecondsProperty, value);
    }

    protected override void OnRender(DrawingContext drawingContext)
    {
        base.OnRender(drawingContext);
        var size = Math.Min(ActualWidth, ActualHeight);
        if (size <= 1)
        {
            return;
        }

        var center = new Point(ActualWidth / 2, ActualHeight / 2);
        var radius = size / 2 - 8;
        var ink = Color.FromRgb(20, 51, 51);
        var coral = Color.FromRgb(232, 79, 69);

        drawingContext.DrawEllipse(
            new SolidColorBrush(Color.FromRgb(239, 249, 244)),
            new Pen(new SolidColorBrush(Color.FromArgb(55, 13, 92, 92)), 2),
            center,
            radius,
            radius);

        DrawSector(
            drawingContext,
            center,
            radius - 5,
            TimerMath.RemainingSectorFraction(RemainingSeconds),
            new SolidColorBrush(Color.FromArgb(118, 79, 186, 224)));
        DrawSector(
            drawingContext,
            center,
            radius - 5,
            TimerMath.RemainingOverlapSectorFraction(RemainingSeconds),
            new SolidColorBrush(Color.FromArgb(145, 245, 148, 184)));

        for (var index = 0; index < 60; index++)
        {
            var angle = index * 6d;
            var outer = PointAt(center, radius - 8, angle);
            var inner = PointAt(center, radius - (index % 5 == 0 ? 20 : 14), angle);
            drawingContext.DrawLine(
                new Pen(new SolidColorBrush(Color.FromArgb(index % 5 == 0 ? (byte)230 : (byte)145, ink.R, ink.G, ink.B)), index % 5 == 0 ? 3 : 1.5),
                inner,
                outer);
        }

        var fastAngle = TimerMath.HandAngle(FastNeedleElapsedSeconds);
        DrawArc(
            drawingContext,
            center,
            radius - 3,
            fastAngle / 360,
            new Pen(new SolidColorBrush(Color.FromArgb(128, coral.R, coral.G, coral.B)), 3));

        var fastTip = PointAt(center, radius * 0.66, fastAngle);
        drawingContext.DrawLine(
            new Pen(new SolidColorBrush(coral), Math.Max(4, size * 0.028)) { StartLineCap = PenLineCap.Round, EndLineCap = PenLineCap.Round },
            center,
            fastTip);

        var countdownAngle = TimerMath.CountdownHandAngle(RemainingSeconds) % 360;
        DrawTaperedHand(drawingContext, center, radius * 0.73, countdownAngle, new SolidColorBrush(Color.FromRgb(18, 22, 22)));

        drawingContext.DrawEllipse(
            new SolidColorBrush(Color.FromRgb(13, 92, 92)),
            new Pen(Brushes.White, 4),
            center,
            Math.Max(9, size * 0.055),
            Math.Max(9, size * 0.055));
    }

    private static void DrawSector(
        DrawingContext context,
        Point center,
        double radius,
        double fraction,
        Brush brush)
    {
        if (fraction <= 0)
        {
            return;
        }

        if (fraction >= 0.999_999)
        {
            context.DrawEllipse(brush, null, center, radius, radius);
            return;
        }

        var start = PointAt(center, radius, 0);
        var end = PointAt(center, radius, fraction * 360);
        var figure = new PathFigure { StartPoint = center, IsClosed = true, IsFilled = true };
        figure.Segments.Add(new LineSegment(start, true));
        figure.Segments.Add(new ArcSegment(
            end,
            new Size(radius, radius),
            0,
            fraction > 0.5,
            SweepDirection.Clockwise,
            true));
        figure.Segments.Add(new LineSegment(center, true));
        var geometry = new PathGeometry([figure]);
        context.DrawGeometry(brush, null, geometry);
    }

    private static void DrawArc(
        DrawingContext context,
        Point center,
        double radius,
        double fraction,
        Pen pen)
    {
        if (fraction <= 0)
        {
            return;
        }

        var safeFraction = Math.Min(0.999_999, fraction);
        var figure = new PathFigure { StartPoint = PointAt(center, radius, 0) };
        figure.Segments.Add(new ArcSegment(
            PointAt(center, radius, safeFraction * 360),
            new Size(radius, radius),
            0,
            safeFraction > 0.5,
            SweepDirection.Clockwise,
            true));
        context.DrawGeometry(null, pen, new PathGeometry([figure]));
    }

    private static void DrawTaperedHand(
        DrawingContext context,
        Point center,
        double length,
        double angle,
        Brush brush)
    {
        var direction = UnitVector(angle);
        var perpendicular = new Vector(-direction.Y, direction.X);
        var baseHalfWidth = Math.Max(7, length * 0.09);
        var tip = center + direction * length;
        var geometry = new StreamGeometry();
        using (var drawing = geometry.Open())
        {
            drawing.BeginFigure(center + perpendicular * baseHalfWidth, true, true);
            drawing.LineTo(tip, true, false);
            drawing.LineTo(center - perpendicular * baseHalfWidth, true, false);
        }

        geometry.Freeze();
        context.DrawGeometry(brush, null, geometry);
    }

    private static Point PointAt(Point center, double radius, double clockwiseDegreesFromTop)
    {
        var direction = UnitVector(clockwiseDegreesFromTop);
        return center + direction * radius;
    }

    private static Vector UnitVector(double clockwiseDegreesFromTop)
    {
        var radians = (clockwiseDegreesFromTop - 90) * Math.PI / 180;
        return new Vector(Math.Cos(radians), Math.Sin(radians));
    }
}
