import CoreData
import Foundation

/// The persisted timeline is intentionally a detail layer. Daily aggregates
/// remain the canonical source for totals and analytics.
@objc(AppUsageIntervalRecord)
final class AppUsageIntervalRecord: NSManagedObject {}

extension AppUsageIntervalRecord {
    @nonobjc class func fetchRequest() -> NSFetchRequest<AppUsageIntervalRecord> {
        NSFetchRequest<AppUsageIntervalRecord>(entityName: "AppUsageIntervalRecord")
    }

    @NSManaged var idString: String
    @NSManaged var dateKey: String
    @NSManaged var startAt: Date
    @NSManaged var endAt: Date
    @NSManaged var durationSeconds: Double
    @NSManaged var isOpen: Bool
    @NSManaged var bundleIdentifier: String
    @NSManaged var displayName: String
}

@objc(WebsiteUsageIntervalRecord)
final class WebsiteUsageIntervalRecord: NSManagedObject {}

extension WebsiteUsageIntervalRecord {
    @nonobjc class func fetchRequest() -> NSFetchRequest<WebsiteUsageIntervalRecord> {
        NSFetchRequest<WebsiteUsageIntervalRecord>(entityName: "WebsiteUsageIntervalRecord")
    }

    @NSManaged var idString: String
    @NSManaged var dateKey: String
    @NSManaged var startAt: Date
    @NSManaged var endAt: Date
    @NSManaged var durationSeconds: Double
    @NSManaged var isOpen: Bool
    @NSManaged var browserBundleIdentifier: String
    @NSManaged var domain: String
    @NSManaged var parentAppIntervalID: String?
}

struct TimelineAppInterval: Identifiable, Equatable {
    let id: String
    let dateKey: String
    let start: Date
    let end: Date
    let duration: TimeInterval
    let app: AppIdentity
    let isOpen: Bool

    var identity: String { app.bundleIdentifier }
}

struct TimelineWebsiteInterval: Identifiable, Equatable {
    let id: String
    let dateKey: String
    let start: Date
    let end: Date
    let duration: TimeInterval
    let domain: String
    let browserBundleIdentifier: String
    let parentAppIntervalID: String?
    let isOpen: Bool
}

struct TimelineGap: Identifiable, Equatable {
    let id: String
    let start: Date
    let end: Date
    var duration: TimeInterval { max(0, end.timeIntervalSince(start)) }
}

struct DailyTimelineSnapshot: Equatable {
    let date: Date
    let dateKey: String
    let appIntervals: [TimelineAppInterval]
    let websiteIntervals: [TimelineWebsiteInterval]
    let chromeGaps: [TimelineGap]
    let isRecorded: Bool

    static func empty(for date: Date, calendar: Calendar) -> DailyTimelineSnapshot {
        DailyTimelineSnapshot(
            date: date,
            dateKey: DayTraceDateKey.key(for: date, calendar: calendar),
            appIntervals: [], websiteIntervals: [], chromeGaps: [], isRecorded: false
        )
    }
}

struct TimelineDataStatistics: Equatable {
    let enabled: Bool
    let startDate: Date?
    let appIntervalCount: Int
    let websiteIntervalCount: Int
    let estimatedBytes: Int64?
}

/// Pure interval rules used by persistence and presentation. It deliberately
/// has no access to Core Data and performs no text or URL processing.
enum TimelineIntervalNormalizer {
    static func validated(start: Date, end: Date) -> (start: Date, end: Date, duration: TimeInterval)? {
        let duration = end.timeIntervalSince(start)
        guard start.timeIntervalSinceReferenceDate.isFinite,
              end.timeIntervalSinceReferenceDate.isFinite,
              duration.isFinite, duration > 0 else { return nil }
        return (start, end, duration)
    }

    static func split(start: Date, end: Date, calendar: Calendar) -> [(dateKey: String, start: Date, end: Date, duration: TimeInterval)] {
        guard validated(start: start, end: end) != nil else { return [] }
        var cursor = start
        var result: [(String, Date, Date, TimeInterval)] = []
        while cursor < end {
            let dayStart = calendar.startOfDay(for: cursor)
            let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? end
            let segmentEnd = min(end, nextDay)
            guard let segment = validated(start: cursor, end: segmentEnd) else { break }
            result.append((DayTraceDateKey.key(for: cursor, calendar: calendar), segment.start, segment.end, segment.duration))
            cursor = segmentEnd
        }
        return result
    }

    static func normalizeAppIntervals(_ intervals: [TimelineAppInterval]) -> [TimelineAppInterval] {
        var lastEndByKey: [String: Date] = [:]
        return intervals.sorted { $0.start == $1.start ? $0.end < $1.end : $0.start < $1.start }.compactMap { interval in
            guard let valid = validated(start: interval.start, end: interval.end) else { return nil }
            let key = interval.app.bundleIdentifier
            let start = max(valid.start, lastEndByKey[key] ?? valid.start)
            guard let clipped = validated(start: start, end: valid.end) else { return nil }
            lastEndByKey[key] = clipped.end
            return TimelineAppInterval(
                id: interval.id, dateKey: interval.dateKey, start: clipped.start,
                end: clipped.end, duration: clipped.duration, app: interval.app, isOpen: interval.isOpen
            )
        }
    }

    static func normalizeWebsiteIntervals(_ intervals: [TimelineWebsiteInterval]) -> [TimelineWebsiteInterval] {
        var lastEndByKey: [String: Date] = [:]
        return intervals.sorted { $0.start == $1.start ? $0.end < $1.end : $0.start < $1.start }.compactMap { interval in
            guard let valid = validated(start: interval.start, end: interval.end) else { return nil }
            let key = "\(interval.browserBundleIdentifier)|\(interval.domain)"
            let start = max(valid.start, lastEndByKey[key] ?? valid.start)
            guard let clipped = validated(start: start, end: valid.end) else { return nil }
            lastEndByKey[key] = clipped.end
            return TimelineWebsiteInterval(
                id: interval.id, dateKey: interval.dateKey, start: clipped.start,
                end: clipped.end, duration: clipped.duration, domain: interval.domain,
                browserBundleIdentifier: interval.browserBundleIdentifier,
                parentAppIntervalID: interval.parentAppIntervalID, isOpen: interval.isOpen
            )
        }
    }

    static func chromeGaps(
        appIntervals: [TimelineAppInterval],
        websiteIntervals: [TimelineWebsiteInterval]
    ) -> [TimelineGap] {
        var gaps: [TimelineGap] = []
        let websites = normalizeWebsiteIntervals(websiteIntervals.filter { $0.browserBundleIdentifier == "com.google.Chrome" })
        for app in normalizeAppIntervals(appIntervals).filter({ $0.app.bundleIdentifier == "com.google.Chrome" }) {
            var cursor = app.start
            for site in websites where site.end > app.start && site.start < app.end {
                let siteStart = max(app.start, site.start)
                let siteEnd = min(app.end, site.end)
                if siteStart > cursor {
                    gaps.append(TimelineGap(id: "gap-\(app.id)-\(cursor.timeIntervalSinceReferenceDate)", start: cursor, end: siteStart))
                }
                if siteEnd > cursor { cursor = max(cursor, siteEnd) }
            }
            if cursor < app.end {
                gaps.append(TimelineGap(id: "gap-\(app.id)-\(cursor.timeIntervalSinceReferenceDate)", start: cursor, end: app.end))
            }
        }
        return gaps
    }

}
