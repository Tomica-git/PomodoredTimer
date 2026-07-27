import Foundation

@main
struct AppEditionTestRunner {
    static func main() {
        precondition(AppEdition.name == "public")
        precondition(AppEdition.bundleIdentifier == "jp.tomica.pomodoredtimer.public")
        precondition(AppEdition.timerStateKey == "pomodored.public.timer.state.v1")
        precondition(
            AppEdition.unreadableStateBackupKey
                == "pomodored.public.timer.state.unreadable-backup.v1"
        )
        precondition(AppEdition.compactModeKey == "pomodored.public.window.compact.v1")
        precondition(AppEdition.alwaysOnTopKey == "pomodored.public.window.alwaysOnTop.v1")
        precondition(!AppEdition.includesPersonalMedia)
        print("PASS: \(AppEdition.name) edition identity and storage keys")
    }
}
