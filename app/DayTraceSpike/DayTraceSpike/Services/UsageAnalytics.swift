import Foundation

struct AnalyticsDelta: Equatable {
    let current: Double
    let previous: Double

    init(current: Double, previous: Double) {
        self.current = Self.sanitize(current)
        self.previous = Self.sanitize(previous)
    }

    var absolute: Double {
        let value = current - previous
        return value == 0 ? 0 : value
    }

    var percentage: Double? {
        guard previous > 0 else { return nil }
        let value = (absolute / previous) * 100
        return value.isFinite ? value : nil
    }

    var isNew: Bool { previous == 0 && current > 0 }

    private static func sanitize(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return max(0, value)
    }
}

enum AnalyticsChangeKind: String, Equatable {
    case app
    case website
}

struct AnalyticsChange: Identifiable, Equatable {
    let entityID: String
    let name: String
    let delta: Double
    let kind: AnalyticsChangeKind

    var id: String { "\(kind.rawValue):\(entityID)" }
}

struct UsagePeriodComparison: Equatable {
    let current: HistoryUsageSnapshot
    let previous: HistoryUsageSnapshot

    var totalUsage: AnalyticsDelta {
        AnalyticsDelta(current: current.totalUsage, previous: previous.totalUsage)
    }

    var typedCharacters: AnalyticsDelta {
        AnalyticsDelta(
            current: Double(current.typingMetrics.typedCharacters),
            previous: Double(previous.typingMetrics.typedCharacters)
        )
    }

    var topAppChanges: [AnalyticsChange] {
        let currentValues = current.appUsageByApp.reduce(into: [String: (String, Double)]()) { result, entry in
            result[entry.key.bundleIdentifier] = (entry.key.displayName, entry.value)
        }
        let previousValues = previous.appUsageByApp.reduce(into: [String: (String, Double)]()) { result, entry in
            result[entry.key.bundleIdentifier] = (entry.key.displayName, entry.value)
        }
        return meaningfulChanges(currentValues: currentValues, previousValues: previousValues, kind: .app)
    }

    var topWebsiteChanges: [AnalyticsChange] {
        let currentValues = current.websiteUsageByDomain.reduce(into: [String: (String, Double)]()) {
            $0[$1.key] = ($1.key, $1.value)
        }
        let previousValues = previous.websiteUsageByDomain.reduce(into: [String: (String, Double)]()) {
            $0[$1.key] = ($1.key, $1.value)
        }
        return meaningfulChanges(currentValues: currentValues, previousValues: previousValues, kind: .website)
    }

    private func meaningfulChanges(
        currentValues: [String: (String, Double)],
        previousValues: [String: (String, Double)],
        kind: AnalyticsChangeKind
    ) -> [AnalyticsChange] {
        let ids = Set(currentValues.keys).union(previousValues.keys)
        return ids.compactMap { id in
            let current = max(0, currentValues[id]?.1 ?? 0)
            let previous = max(0, previousValues[id]?.1 ?? 0)
            let delta = current - previous
            let threshold = max(60, max(current, previous) * 0.05)
            guard delta.isFinite, abs(delta) >= threshold else { return nil }
            return AnalyticsChange(
                entityID: id,
                name: currentValues[id]?.0 ?? previousValues[id]?.0 ?? id,
                delta: delta,
                kind: kind
            )
        }
        .sorted {
            if abs($0.delta) != abs($1.delta) { return abs($0.delta) > abs($1.delta) }
            let nameOrder = $0.name.localizedCaseInsensitiveCompare($1.name)
            if nameOrder != .orderedSame { return nameOrder == .orderedAscending }
            return $0.entityID.localizedCaseInsensitiveCompare($1.entityID) == .orderedAscending
        }
        .prefix(5)
        .map { $0 }
    }
}

enum UsageComparisonPeriod {
    static func referenceDate(for range: HistoryRange, date: Date, calendar: Calendar) -> Date {
        switch range {
        case .today:
            return calendar.date(byAdding: .day, value: -1, to: date) ?? date
        case .yesterday:
            return calendar.date(byAdding: .day, value: -2, to: date) ?? date
        case .last7Days, .last30Days, .thisWeek:
            return calendar.date(byAdding: .day, value: -7, to: date) ?? date
        case .thisMonth:
            // This intentionally compares the elapsed portion of the current
            // month with the same day-of-month in the previous month. When a
            // day does not exist, Foundation's calendar clamps to that month.
            return calendar.date(byAdding: .month, value: -1, to: date) ?? date
        }
    }
}

enum DayTraceAnalytics {
    static func average(_ value: Double, over includedDays: Int) -> Double {
        guard includedDays > 0, value.isFinite else { return 0 }
        return max(0, value) / Double(includedDays)
    }

    static func includedDayCount(for snapshot: HistoryUsageSnapshot, asOf date: Date, calendar: Calendar) -> Int {
        let today = calendar.startOfDay(for: date)
        return snapshot.dailyTotals.filter {
            let day = calendar.startOfDay(for: $0.date)
            return day >= calendar.startOfDay(for: snapshot.startDate)
                && day <= min(today, calendar.startOfDay(for: snapshot.endDate))
        }.count
    }

    static func average(
        for snapshot: HistoryUsageSnapshot,
        asOf date: Date,
        calendar: Calendar
    ) -> Double {
        average(
            snapshot.totalUsage,
            over: includedDayCount(for: snapshot, asOf: date, calendar: calendar)
        )
    }

    static func safePercentage(_ delta: AnalyticsDelta) -> Double? {
        guard let percentage = delta.percentage, percentage.isFinite else { return nil }
        return percentage == 0 ? 0 : percentage
    }
}

// MARK: - Product Completion analytics

struct HourlyActivityPoint: Identifiable, Equatable {
    let hour: Int
    let duration: TimeInterval

    var id: Int { hour }
}

struct WeekdayHourKey: Hashable, Equatable {
    let weekday: Int
    let hour: Int
}

struct SessionAnalytics: Equatable {
    let sessionCount: Int
    let averageDuration: TimeInterval
    let medianDuration: TimeInterval
    let longestDuration: TimeInterval
    let longestSessions: [TimelineAppInterval]
    let averageByApp: [String: TimeInterval]
    let longestByApp: [String: TimeInterval]
}

struct TransitionAnalytics: Identifiable, Equatable {
    let from: String
    let to: String
    let count: Int

    var id: String { "\(from)->\(to)" }
}

enum DayTraceProductAnalytics {
    static func hourlyActivity(
        from intervals: [TimelineAppInterval],
        calendar: Calendar
    ) -> [HourlyActivityPoint] {
        var totals = Array(repeating: 0.0, count: 24)
        for interval in intervals {
            add(interval.start, interval.end, to: &totals, calendar: calendar)
        }
        return totals.enumerated().map { HourlyActivityPoint(hour: $0.offset, duration: max(0, $0.element)) }
    }

    static func weekdayHourActivity(
        from snapshots: [DailyTimelineSnapshot],
        calendar: Calendar
    ) -> [WeekdayHourKey: TimeInterval] {
        var result: [WeekdayHourKey: TimeInterval] = [:]
        for snapshot in snapshots {
            for interval in snapshot.appIntervals {
                var cursor = interval.start
                while cursor < interval.end {
                    guard let hourInterval = calendar.dateInterval(of: .hour, for: cursor) else { break }
                    let segmentEnd = min(interval.end, hourInterval.end)
                    let weekday = calendar.component(.weekday, from: cursor)
                    let hour = calendar.component(.hour, from: cursor)
                    result[WeekdayHourKey(weekday: weekday, hour: hour), default: 0] += segmentEnd.timeIntervalSince(cursor)
                    cursor = segmentEnd
                }
            }
        }
        return result
    }

    static func sessionAnalytics(from intervals: [TimelineAppInterval]) -> SessionAnalytics {
        let valid = intervals.filter { $0.duration.isFinite && $0.duration > 0 }
        let durations = valid.map(\.duration).sorted()
        let median: TimeInterval
        if durations.isEmpty {
            median = 0
        } else if durations.count.isMultiple(of: 2) {
            median = (durations[durations.count / 2 - 1] + durations[durations.count / 2]) / 2
        } else {
            median = durations[durations.count / 2]
        }
        var averageByApp: [String: (total: TimeInterval, count: Int)] = [:]
        var longestByApp: [String: TimeInterval] = [:]
        for interval in valid {
            let key = interval.app.bundleIdentifier
            averageByApp[key, default: (0, 0)].total += interval.duration
            averageByApp[key, default: (0, 0)].count += 1
            longestByApp[key] = max(longestByApp[key, default: 0], interval.duration)
        }
        return SessionAnalytics(
            sessionCount: valid.count,
            averageDuration: valid.isEmpty ? 0 : durations.reduce(0, +) / Double(valid.count),
            medianDuration: median,
            longestDuration: durations.last ?? 0,
            longestSessions: valid.sorted { $0.duration > $1.duration }.prefix(10).map { $0 },
            averageByApp: averageByApp.mapValues { $0.total / Double(max(1, $0.count)) },
            longestByApp: longestByApp
        )
    }

    static func transitions(from intervals: [TimelineAppInterval]) -> [TransitionAnalytics] {
        let sorted = intervals.sorted { $0.start < $1.start }
        var counts: [String: (from: String, to: String, count: Int)] = [:]
        for pair in zip(sorted, sorted.dropFirst()) {
            guard pair.0.app.bundleIdentifier != pair.1.app.bundleIdentifier else { continue }
            let key = "\(pair.0.app.bundleIdentifier)->\(pair.1.app.bundleIdentifier)"
            counts[key, default: (pair.0.app.bundleIdentifier, pair.1.app.bundleIdentifier, 0)].count += 1
        }
        return counts.values
            .map { TransitionAnalytics(from: $0.from, to: $0.to, count: $0.count) }
            .sorted { $0.count == $1.count ? $0.id < $1.id : $0.count > $1.count }
    }

    private static func add(
        _ start: Date,
        _ end: Date,
        to totals: inout [TimeInterval],
        calendar: Calendar
    ) {
        guard end > start else { return }
        var cursor = start
        while cursor < end {
            guard let hourInterval = calendar.dateInterval(of: .hour, for: cursor) else { break }
            let segmentEnd = min(end, hourInterval.end)
            let hour = calendar.component(.hour, from: cursor)
            if (0..<24).contains(hour) {
                totals[hour] += max(0, segmentEnd.timeIntervalSince(cursor))
            }
            cursor = segmentEnd
        }
    }
}
