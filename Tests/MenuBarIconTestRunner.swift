import AppKit
import Foundation

@main
struct MenuBarIconTestRunner {
    static func main() {
        let image = MenuBarTomatoClockIcon.image
        guard image.isTemplate else {
            fail("menu bar icon must be a template image")
        }
        guard
            image.size == NSSize(width: 18, height: 18),
            let tiff = image.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: tiff)
        else {
            fail("menu bar icon must render as an 18x18 bitmap")
        }

        var visiblePixels = 0
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                if (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.05 {
                    visiblePixels += 1
                }
            }
        }

        guard visiblePixels >= 40 else {
            fail("menu bar icon rendered blank or nearly blank")
        }
        print("PASS: menu bar tomato clock icon renders \(visiblePixels) visible pixels")
    }

    private static func fail(_ message: String) -> Never {
        fputs("FAIL: \(message)\n", stderr)
        exit(1)
    }
}
