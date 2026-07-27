using Drawing = System.Drawing;
using Forms = System.Windows.Forms;
using PomodoredTimer.Domain;

namespace PomodoredTimer.Windows.Public.Services;

public sealed class TrayIconService : IDisposable
{
    private readonly App app;
    private readonly Forms.NotifyIcon notifyIcon;
    private readonly Drawing.Icon icon;
    private readonly Forms.ToolStripMenuItem primaryItem;
    private readonly Forms.ToolStripMenuItem compactItem;
    private readonly Forms.ToolStripMenuItem topmostItem;

    public TrayIconService(App app)
    {
        this.app = app;
        icon = TomatoIconFactory.Create();
        primaryItem = new Forms.ToolStripMenuItem("開始", null, (_, _) => app.ExecutePrimaryAction());
        compactItem = new Forms.ToolStripMenuItem("縮小", null, (_, _) => app.ToggleCompactMode());
        topmostItem = new Forms.ToolStripMenuItem("常に手前", null, (_, _) => app.ToggleAlwaysOnTop());

        var menu = new Forms.ContextMenuStrip();
        menu.Items.Add(primaryItem);
        menu.Items.Add(new Forms.ToolStripMenuItem("ウィンドウを表示", null, (_, _) => app.ShowTimerWindow()));
        menu.Items.Add(compactItem);
        menu.Items.Add(topmostItem);
        menu.Items.Add(new Forms.ToolStripSeparator());
        menu.Items.Add(new Forms.ToolStripMenuItem("Pomodored Timerを終了", null, (_, _) => app.ExitApplication()));

        notifyIcon = new Forms.NotifyIcon
        {
            Icon = icon,
            ContextMenuStrip = menu,
            Visible = true,
            Text = "Pomodored Timer",
        };
        notifyIcon.DoubleClick += (_, _) => app.ShowTimerWindow();
        Refresh();
    }

    public void Refresh()
    {
        var state = app.Engine.State;
        var remaining = TimerMath.ClockString(app.Engine.Projection(DateTimeOffset.UtcNow).RemainingSeconds);
        notifyIcon.Text = $"Pomodored {remaining}";
        primaryItem.Text = state.Session.Status switch
        {
            TimerStatus.Idle => "開始",
            TimerStatus.Running => "一時停止",
            TimerStatus.Paused => "再開",
            TimerStatus.Completed => "次のセッション",
            _ => "開始",
        };
        compactItem.Text = state.IsCompactMode ? "通常サイズに戻す" : "縮小";
        topmostItem.Text = state.IsAlwaysOnTop ? "常に手前を解除" : "常に手前";
    }

    public void Dispose()
    {
        notifyIcon.Visible = false;
        notifyIcon.Dispose();
        icon.Dispose();
    }
}
