import Foundation

enum DayTraceDurationFormatter {
    struct Components: Equatable {
        let hours: Int
        let minutes: Int
        let seconds: Int
    }

    static func components(for duration: TimeInterval) -> Components {
        guard duration.isFinite else {
            return Components(hours: 0, minutes: 0, seconds: 0)
        }
        let totalSeconds = max(0, Int(duration.rounded(.down)))
        return Components(
            hours: totalSeconds / 3_600,
            minutes: (totalSeconds % 3_600) / 60,
            seconds: totalSeconds % 60
        )
    }

    static func string(seconds duration: TimeInterval, locale: Locale) -> String {
        let value = components(for: duration)

        if value.hours > 0 {
            let format = String(localized: "duration.hoursMinutesSeconds", locale: locale)
            return String(format: format, value.hours, value.minutes, value.seconds)
        }
        if value.minutes > 0 {
            let format = String(localized: "duration.minutesSeconds", locale: locale)
            return String(format: format, value.minutes, value.seconds)
        }

        let format = String(localized: "duration.secondsOnly", locale: locale)
        return String(format: format, value.seconds)
    }
}
