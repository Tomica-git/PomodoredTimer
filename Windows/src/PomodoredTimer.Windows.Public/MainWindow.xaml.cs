using System.ComponentModel;
using System.Globalization;
using System.Windows;
using System.Windows.Input;
using System.Windows.Threading;
using PomodoredTimer.Application;
using PomodoredTimer.Domain;
using PomodoredTimer.Windows.Public.Services;
using MessageBox = System.Windows.MessageBox;

namespace PomodoredTimer.Windows.Public;

public partial class MainWindow : Window
{
    private readonly TimerEngine engine;
    private readonly DispatcherTimer refreshTimer;
    private readonly SoundService soundService = new();
    private bool refreshing;

    public MainWindow(TimerEngine engine)
    {
        this.engine = engine;
        InitializeComponent();
        refreshTimer = new DispatcherTimer(DispatcherPriority.Render)
        {
            Interval = TimeSpan.FromMilliseconds(100),
        };
        refreshTimer.Tick += RefreshTimer_Tick;
        refreshTimer.Start();
        ApplyWindowMode();
        Topmost = engine.State.IsAlwaysOnTop;
        RefreshView();
    }

    public void ApplyWindowMode()
    {
        if (engine.State.IsCompactMode)
        {
            SettingsPanel.Visibility = Visibility.Collapsed;
            SettingsColumn.Width = new GridLength(0);
            Width = 320;
            Height = 300;
            Dial.Width = 135;
            Dial.Height = 135;
            RemainingText.FontSize = 34;
            CompactButton.Content = "通常";
        }
        else
        {
            SettingsPanel.Visibility = Visibility.Visible;
            SettingsColumn.Width = new GridLength(290);
            Width = 940;
            Height = 700;
            Dial.Width = 300;
            Dial.Height = 300;
            RemainingText.FontSize = 64;
            CompactButton.Content = "縮小";
        }

        RefreshView();
    }

    public void RefreshView()
    {
        refreshing = true;
        var nowUtc = DateTimeOffset.UtcNow;
        var projection = engine.Projection(nowUtc);
        Dial.RemainingSeconds = projection.RemainingSeconds;
        Dial.FastNeedleElapsedSeconds = projection.FastNeedleElapsedSeconds;
        RemainingText.Text = TimerMath.ClockString(projection.RemainingSeconds);
        PhaseText.Text = $"{PhaseTitle(engine.State.Phase)} · SET {engine.State.CompletedFocusSets + 1}";
        SpeedText.Text = $"赤 ×{engine.State.FastNeedleRate:0.#}　黒 1分/1目盛";
        SoundText.Text = engine.State.Settings.NeedleSoundsMuted ? "針音ミュート" : "針音オン";
        CompletionText.Text = engine.State.Session.Status == TimerStatus.Completed
            ? $"完了しました。次は{PhaseTitle(engine.NextPhase)}です。"
            : "";
        PrimaryButton.Content = engine.State.Session.Status switch
        {
            TimerStatus.Idle => "開始",
            TimerStatus.Running => "一時停止",
            TimerStatus.Paused => "再開",
            TimerStatus.Completed => "次のセッション",
            _ => "開始",
        };

        FocusMinutesText.Text = engine.State.Settings.FocusMinutes.ToString(CultureInfo.InvariantCulture);
        ShortMinutesText.Text = engine.State.Settings.ShortBreakMinutes.ToString(CultureInfo.InvariantCulture);
        LongMinutesText.Text = engine.State.Settings.LongBreakMinutes.ToString(CultureInfo.InvariantCulture);
        AutoSessionCheck.IsChecked = engine.State.Settings.AutomaticallyStartNextSession;
        CompletionSoundCheck.IsChecked = engine.State.Settings.CompletionSoundEnabled;
        NeedleMuteCheck.IsChecked = engine.State.Settings.NeedleSoundsMuted;
        ReduceMotionCheck.IsChecked = engine.State.Settings.ReduceMotion;
        TopmostCheck.IsChecked = engine.State.IsAlwaysOnTop;
        PinButton.Content = engine.State.IsAlwaysOnTop ? "最前面解除" : "最前面";
        refreshing = false;
    }

    private void RefreshTimer_Tick(object? sender, EventArgs e)
    {
        var effects = engine.Update(DateTimeOffset.UtcNow);
        if (effects.Tick)
        {
            soundService.PlayTick();
        }

        if (effects.Tock)
        {
            soundService.PlayTock();
        }

        if (effects.CompletedSessions > 0 && engine.State.Settings.CompletionSoundEnabled)
        {
            soundService.PlayCompletion();
        }

        if (effects.StateChanged)
        {
            App.Current.SaveState();
        }

        RefreshView();
        App.Current.RefreshTray();
    }

    private void Primary_Click(object sender, RoutedEventArgs e) => App.Current.ExecutePrimaryAction();

    private void Reset_Click(object sender, RoutedEventArgs e)
    {
        var answer = MessageBox.Show(
            this,
            "現在の集中・休憩を終了し、SET 1の停止状態へ戻します。時間などの設定は残ります。",
            "最初に戻しますか？",
            MessageBoxButton.YesNo,
            MessageBoxImage.Warning);
        if (answer != MessageBoxResult.Yes)
        {
            return;
        }

        engine.Reset(DateTimeOffset.UtcNow);
        App.Current.SaveState();
        RefreshView();
    }

    private void Compact_Click(object sender, RoutedEventArgs e) => App.Current.ToggleCompactMode();

    private void Pin_Click(object sender, RoutedEventArgs e) => App.Current.ToggleAlwaysOnTop();

    private void History_Click(object sender, RoutedEventArgs e)
    {
        var history = new HistoryWindow(engine) { Owner = this };
        history.Show();
    }

    private void Duration_Click(object sender, RoutedEventArgs e)
    {
        if (sender is not FrameworkElement { Tag: string tag })
        {
            return;
        }

        var parts = tag.Split(':');
        var delta = int.Parse(parts[1], CultureInfo.InvariantCulture);
        switch (parts[0])
        {
            case "focus":
                engine.State.Settings.FocusMinutes = Math.Clamp(engine.State.Settings.FocusMinutes + delta, 10, 90);
                break;
            case "short":
                engine.State.Settings.ShortBreakMinutes = Math.Clamp(engine.State.Settings.ShortBreakMinutes + delta, 3, 30);
                break;
            case "long":
                engine.State.Settings.LongBreakMinutes = Math.Clamp(engine.State.Settings.LongBreakMinutes + delta, 3, 30);
                break;
        }

        engine.ApplySettings();
        App.Current.SaveState();
        RefreshView();
    }

    private void Speed_Click(object sender, RoutedEventArgs e)
    {
        if (sender is FrameworkElement { Tag: string value }
            && double.TryParse(value, NumberStyles.Float, CultureInfo.InvariantCulture, out var speed))
        {
            engine.SetSpeed(speed, DateTimeOffset.UtcNow);
            App.Current.SaveState();
            RefreshView();
        }
    }

    private void SettingCheck_Changed(object sender, RoutedEventArgs e)
    {
        if (refreshing)
        {
            return;
        }

        engine.State.Settings.AutomaticallyStartNextSession = AutoSessionCheck.IsChecked == true;
        engine.State.Settings.CompletionSoundEnabled = CompletionSoundCheck.IsChecked == true;
        engine.State.Settings.NeedleSoundsMuted = NeedleMuteCheck.IsChecked == true;
        engine.State.Settings.ReduceMotion = ReduceMotionCheck.IsChecked == true;
        engine.State.IsAlwaysOnTop = TopmostCheck.IsChecked == true;
        Topmost = engine.State.IsAlwaysOnTop;
        engine.ApplySettings();
        App.Current.SaveState();
        RefreshView();
        App.Current.RefreshTray();
    }

    private void Window_Closing(object? sender, CancelEventArgs e)
    {
        if (App.Current.IsExiting)
        {
            return;
        }

        e.Cancel = true;
        Hide();
    }

    private void Window_KeyDown(object sender, System.Windows.Input.KeyEventArgs e)
    {
        if (e.Key == Key.Space)
        {
            App.Current.ExecutePrimaryAction();
            e.Handled = true;
        }
        else if (e.Key == Key.R && Keyboard.Modifiers.HasFlag(ModifierKeys.Control))
        {
            Reset_Click(sender, new RoutedEventArgs());
            e.Handled = true;
        }
    }

    private static string PhaseTitle(TimerPhase phase) => phase switch
    {
        TimerPhase.Focus => "集中",
        TimerPhase.ShortBreak => "短い休憩",
        TimerPhase.LongBreak => "長い休憩",
        _ => "集中",
    };
}
