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
