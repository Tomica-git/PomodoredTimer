using System.IO;
using System.Windows;
using PomodoredTimer.Application;
using PomodoredTimer.Windows.Public.Services;
using MessageBox = System.Windows.MessageBox;

namespace PomodoredTimer.Windows.Public;

public partial class App : System.Windows.Application
{
    private PublicStateStore? stateStore;
    private TrayIconService? trayIcon;
    private bool isExiting;

    public static new App Current => (App)System.Windows.Application.Current;

    public TimerEngine Engine { get; private set; } = null!;

    public MainWindow TimerWindow { get; private set; } = null!;

    public bool IsExiting => isExiting;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        stateStore = new PublicStateStore();
        var loaded = stateStore.Load();
        Engine = new TimerEngine(loaded.State, DateTimeOffset.UtcNow);
        TimerWindow = new MainWindow(Engine);
        MainWindow = TimerWindow;
        trayIcon = new TrayIconService(this);
        TimerWindow.Show();

        if (loaded.RecoveredFromCorruption)
        {
            Dispatcher.BeginInvoke(() => MessageBox.Show(
                TimerWindow,
                "読み込めない記録を隔離し、空の状態で起動しました。隔離した記録は削除していません。\n\n"
                    + loaded.QuarantinePath,
                "記録を保護しました",
                MessageBoxButton.OK,
                MessageBoxImage.Warning));
        }
    }

    public void ShowTimerWindow()
    {
        if (!TimerWindow.IsVisible)
        {
            TimerWindow.Show();
        }

        if (TimerWindow.WindowState == WindowState.Minimized)
        {
            TimerWindow.WindowState = WindowState.Normal;
        }

        TimerWindow.Activate();
        TimerWindow.Topmost = Engine.State.IsAlwaysOnTop;
        TimerWindow.RefreshView();
    }

    public void ExecutePrimaryAction()
    {
        Engine.PrimaryAction(DateTimeOffset.UtcNow);
        SaveState();
        TimerWindow.RefreshView();
        trayIcon?.Refresh();
    }

    public void ToggleCompactMode()
    {
        Engine.State.IsCompactMode = !Engine.State.IsCompactMode;
        TimerWindow.ApplyWindowMode();
        SaveState();
        trayIcon?.Refresh();
    }

    public void ToggleAlwaysOnTop()
    {
        Engine.State.IsAlwaysOnTop = !Engine.State.IsAlwaysOnTop;
        TimerWindow.Topmost = Engine.State.IsAlwaysOnTop;
        TimerWindow.RefreshView();
        SaveState();
        trayIcon?.Refresh();
    }

    public void SaveState()
    {
        try
        {
            stateStore?.Save(Engine.State);
        }
        catch (Exception exception) when (exception is IOException or UnauthorizedAccessException)
        {
            MessageBox.Show(
                TimerWindow,
                "記録を保存できませんでした。既存の記録は削除していません。\n\n" + exception.Message,
                "保存エラー",
                MessageBoxButton.OK,
                MessageBoxImage.Error);
        }
    }

    public void RefreshTray() => trayIcon?.Refresh();

    public void ExitApplication()
    {
        SaveState();
        isExiting = true;
        trayIcon?.Dispose();
        TimerWindow.Close();
        Shutdown();
    }
}
