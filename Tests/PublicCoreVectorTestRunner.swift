import Foundation

@main
struct PublicCoreVectorTestRunner {
    private static var failures = 0

    static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            print("FAIL: vector path is required")
            exit(2)
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
        let document = try JSONDecoder().decode(VectorDocument.self, from: data)
        expect(document.schemaVersion == 1, "shared vector schema")

        for item in document.projectionCases {
            let projection = TimerMath.projection(
                realElapsed: item.realElapsedSeconds,
                duration: item.durationSeconds,
                fastRate: item.fastRate
            )
            expect(near(projection.remaining, item.remainingSeconds), "\(item.id) remaining")
            expect(
                near(projection.fastNeedleElapsed, item.fastNeedleElapsedSeconds),
                "\(item.id) fast hand"
            )
            expect(
                near(TimerMath.countdownHandAngle(remaining: projection.remaining), item.countdownHandAngle),
                "\(item.id) countdown hand"
            )
        }

        for item in document.cycleCases {
            let actual = TimerCycle.nextPhase(
                after: phase(item.phase),
                completedFocusSets: item.completedFocusSets,
                focusSetsBeforeLongBreak: item.focusSetsBeforeLongBreak
            )
            expect(actual == phase(item.expected), "\(item.id) cycle")
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        for item in document.weekCases {
            let range = TimerCalendarRanges.mondayWeek(
                containing: date(item.date, calendar: calendar),
                calendar: calendar
            )
            expect(dayString(range.start, calendar: calendar) == item.expectedStart, "\(item.id) start")
            expect(
                dayString(range.end, calendar: calendar) == item.expectedEndExclusive,
                "\(item.id) end"
            )
        }

        if failures > 0 {
            print("FAIL: \(failures) shared public-core vectors failed")
            exit(1)
        }
        print("PASS: shared public-core vectors (Swift)")
    }

    private static func phase(_ value: String) -> TimerPhase {
        switch value {
        case "focus": .focus
        case "shortBreak": .shortBreak
        case "longBreak": .longBreak
        default:
            fatalError("Unknown shared vector phase: \(value)")
        }
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ name: String) {
        if !condition() {
            failures += 1
            print("FAIL: \(name)")
        }
    }

    private static func near(_ left: Double, _ right: Double) -> Bool {
        abs(left - right) < 0.000_001
    }

    private static func date(_ value: String, calendar: Calendar) -> Date {
        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { fatalError("Invalid shared date: \(value)") }
        return calendar.date(
            from: DateComponents(year: parts[0], month: parts[1], day: parts[2])
        )!
    }

    private static func dayString(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }

    private struct VectorDocument: Decodable {
        let schemaVersion: Int
        let projectionCases: [ProjectionCase]
        let cycleCases: [CycleCase]
        let weekCases: [WeekCase]
    }

    private struct ProjectionCase: Decodable {
        let id: String
        let realElapsedSeconds: Double
        let durationSeconds: Double
        let fastRate: Double
        let remainingSeconds: Double
        let fastNeedleElapsedSeconds: Double
        let countdownHandAngle: Double
    }

    private struct CycleCase: Decodable {
        let id: String
        let phase: String
        let completedFocusSets: Int
        let focusSetsBeforeLongBreak: Int
        let expected: String
    }

    private struct WeekCase: Decodable {
        let id: String
        let date: String
        let expectedStart: String
        let expectedEndExclusive: String
    }
}
