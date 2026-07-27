import AppKit
import SwiftUI

struct WindowConfigurationView: NSViewRepresentable {
    let isCompact: Bool
    let isAlwaysOnTop: Bool
    let toggleCompact: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(toggleCompact: toggleCompact)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            configure(view.window, coordinator: context.coordinator)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.toggleCompact = toggleCompact
        DispatchQueue.main.async {
            configure(nsView.window, coordinator: context.coordinator)
        }
    }

    private func configure(_ window: NSWindow?, coordinator: Coordinator) {
        guard let window else { return }

        if let miniaturizeButton = window.standardWindowButton(.miniaturizeButton) {
            miniaturizeButton.isEnabled = false
            miniaturizeButton.isHidden = true
        }
        window.styleMask.remove(.miniaturizable)

        if let zoomButton = window.standardWindowButton(.zoomButton) {
            zoomButton.target = coordinator
            zoomButton.action = #selector(Coordinator.toggleCompactMode)
            zoomButton.toolTip = isCompact ? "通常サイズに戻す" : "コンパクト表示"
            zoomButton.setAccessibilityLabel(isCompact ? "通常サイズに戻す" : "コンパクト表示")
        }

        if coordinator.lastCompact != isCompact {
            let size = isCompact
                ? NSSize(width: 320, height: 300)
                : NSSize(width: 940, height: 700)
            window.minSize = isCompact
                ? NSSize(width: 300, height: 280)
                : NSSize(width: 820, height: 620)
            window.setContentSize(size)
            coordinator.lastCompact = isCompact
        }

        if coordinator.lastAlwaysOnTop != isAlwaysOnTop {
            window.level = isAlwaysOnTop ? .floating : .normal
            window.collectionBehavior = isAlwaysOnTop
                ? [.fullScreenAuxiliary, .canJoinAllSpaces]
                : []
            coordinator.lastAlwaysOnTop = isAlwaysOnTop
        }
    }

    final class Coordinator: NSObject {
        var lastCompact: Bool?
        var lastAlwaysOnTop: Bool?
        var toggleCompact: () -> Void

        init(toggleCompact: @escaping () -> Void) {
            self.toggleCompact = toggleCompact
        }

        @objc func toggleCompactMode() {
            toggleCompact()
        }
    }
}
