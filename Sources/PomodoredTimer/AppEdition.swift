import Foundation

#if !EDITION_PUBLIC
#error("The public source repository requires EDITION_PUBLIC")
#endif

#if FEATURE_PERSONAL_MEDIA || EDITION_PERSONAL
#error("Private edition capabilities cannot be compiled from the public source repository")
#endif

enum AppEdition {
    static let name = "public"
    static let bundleIdentifier = "jp.tomica.pomodoredtimer.public"
    static let timerStateKey = "pomodored.public.timer.state.v1"
    static let unreadableStateBackupKey = "pomodored.public.timer.state.unreadable-backup.v1"
    static let compactModeKey = "pomodored.public.window.compact.v1"
    static let alwaysOnTopKey = "pomodored.public.window.alwaysOnTop.v1"
    static let includesPersonalMedia = false
}
