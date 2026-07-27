using System.Drawing;
using System.Drawing.Drawing2D;
using System.Runtime.InteropServices;

namespace PomodoredTimer.Windows.Public.Services;

internal static class TomatoIconFactory
{
    public static Icon Create()
    {
        using var bitmap = new Bitmap(32, 32);
        using (var graphics = Graphics.FromImage(bitmap))
        {
            graphics.SmoothingMode = SmoothingMode.AntiAlias;
            graphics.Clear(Color.Transparent);
            using var tomatoBrush = new SolidBrush(Color.FromArgb(232, 79, 69));
            using var leafBrush = new SolidBrush(Color.FromArgb(24, 112, 78));
            using var whitePen = new Pen(Color.White, 2.2f)
            {
                StartCap = LineCap.Round,
                EndCap = LineCap.Round,
            };
            graphics.FillEllipse(tomatoBrush, 5, 7, 22, 21);
            graphics.FillPolygon(leafBrush, [
                new PointF(16, 8),
                new PointF(10, 3),
                new PointF(14, 10),
                new PointF(21, 3),
                new PointF(18, 10),
                new PointF(25, 7),
            ]);
            graphics.DrawEllipse(whitePen, 10, 11, 12, 12);
            graphics.DrawLine(whitePen, 16, 17, 16, 13);
            graphics.DrawLine(whitePen, 16, 17, 20, 17);
        }

        var handle = bitmap.GetHicon();
        try
        {
            using var temporary = Icon.FromHandle(handle);
            return (Icon)temporary.Clone();
        }
        finally
        {
            _ = DestroyIcon(handle);
        }
    }

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool DestroyIcon(IntPtr handle);
}
