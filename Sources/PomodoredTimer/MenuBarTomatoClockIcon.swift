import AppKit

enum MenuBarTomatoClockIcon {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            NSColor.black.setStroke()
            NSColor.black.setFill()

            let tomato = NSBezierPath()
            tomato.move(to: NSPoint(x: 9, y: 13.6))
            tomato.curve(
                to: NSPoint(x: 15.3, y: 8.6),
                controlPoint1: NSPoint(x: 12.8, y: 14.5),
                controlPoint2: NSPoint(x: 15.3, y: 11.9)
            )
            tomato.curve(
                to: NSPoint(x: 9, y: 2),
                controlPoint1: NSPoint(x: 15.3, y: 4.8),
                controlPoint2: NSPoint(x: 12.8, y: 2)
            )
            tomato.curve(
                to: NSPoint(x: 2.7, y: 8.6),
                controlPoint1: NSPoint(x: 5.2, y: 2),
                controlPoint2: NSPoint(x: 2.7, y: 4.8)
            )
            tomato.curve(
                to: NSPoint(x: 9, y: 13.6),
                controlPoint1: NSPoint(x: 2.7, y: 11.9),
                controlPoint2: NSPoint(x: 5.2, y: 14.5)
            )
            tomato.close()
            tomato.lineWidth = 1.45
            tomato.lineCapStyle = .round
            tomato.lineJoinStyle = .round
            tomato.stroke()

            let leaves = NSBezierPath()
            leaves.move(to: NSPoint(x: 9, y: 13.4))
            leaves.line(to: NSPoint(x: 9, y: 16.2))
            leaves.move(to: NSPoint(x: 8.9, y: 13.6))
            leaves.line(to: NSPoint(x: 5.8, y: 15.2))
            leaves.move(to: NSPoint(x: 9.1, y: 13.6))
            leaves.line(to: NSPoint(x: 12.2, y: 15.2))
            leaves.lineWidth = 1.45
            leaves.lineCapStyle = .round
            leaves.lineJoinStyle = .round
            leaves.stroke()

            let hands = NSBezierPath()
            hands.move(to: NSPoint(x: 9, y: 7.7))
            hands.line(to: NSPoint(x: 9, y: 11.2))
            hands.move(to: NSPoint(x: 9, y: 7.7))
            hands.line(to: NSPoint(x: 12.3, y: 7.7))
            hands.lineWidth = 1.6
            hands.lineCapStyle = .round
            hands.lineJoinStyle = .round
            hands.stroke()

            NSBezierPath(ovalIn: NSRect(x: 8.1, y: 6.8, width: 1.8, height: 1.8)).fill()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "トマト時計"
        return image
    }()
}
