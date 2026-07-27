import AppKit
import SwiftUI

struct MenuBarTimerView: View {
    @ObservedObject var model: TimerViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text("\(model.phase.title)  \(model.menuBarTitle)")
            .font(.system(.body, design: .monospaced))

        Button {
            model.primaryAction()
        } label: {
            Label(model.primaryActionTitle, systemImage: primaryActionIcon)
        }
        .keyboardShortcut(.space, modifiers: [])

        Button {
            bringMainWindowToFront()
        } label: {
            Label("ウインドウを最前面に表示", systemImage: "macwindow.on.rectangle")
        }

        Button {
            openMainWindow()
        } label: {
            Label("設定を開く", systemImage: "gearshape")
        }
        .keyboardShortcut(",", modifiers: .command)

        Button {
            model.setCompactMode(!model.isCompactMode)
            openMainWindow()
        } label: {
            Label(
                model.isCompactMode ? "通常サイズに戻す" : "コンパクト表示",
                systemImage: model.isCompactMode
                    ? "arrow.up.left.and.arrow.down.right"
                    : "arrow.down.right.and.arrow.up.left"
            )
        }

        Button {
            model.toggleAlwaysOnTop()
        } label: {
            Label(
                model.isAlwaysOnTop ? "常に手前を解除" : "常に手前に表示",
                systemImage: model.isAlwaysOnTop ? "pin.slash" : "pin"
            )
        }

        Divider()

        Button {
            NSApplication.shared.terminate(nil)
        } label: {
            Label("Pomodored Timerを終了", systemImage: "power")
        }
        .keyboardShortcut("q", modifiers: .command)
    }

    private var primaryActionIcon: String {
        switch model.session.status {
        case .running: "pause.fill"
        case .completed: "forward.fill"
        case .idle, .paused: "play.fill"
        }
    }

    private func openMainWindow() {
        bringMainWindowToFront()
    }

    private func bringMainWindowToFront() {
        openWindow(id: "main")
        NSApplication.shared.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            guard let window = NSApplication.shared.windows.first(where: { $0.title == "Pomodored Timer" }) else {
                return
            }
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }
}
