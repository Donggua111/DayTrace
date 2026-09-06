import XCTest
@testable import DayTrace

@MainActor
final class DayTraceTests: XCTestCase {
    func testExactlyOneHundredQualifyingKeys() {
        let keys = Array(repeating: Int64(0), count: 100)
        XCTAssertEqual(keys.filter(KeyClassifier.isQualifying).count, 100)
    }

    func testModifierAndSystemKeysDoNotQualify() {
        let modifiers: [Int64] = [53, 54, 55, 56, 57, 58, 59, 60, 61, 62, 64, 72, 73, 74, 96]
        XCTAssertEqual(modifiers.filter(KeyClassifier.isQualifying).count, 0)
    }

    func testInputBoundaries() {
        XCTAssertTrue(KeyClassifier.isQualifying(keyCode: 36)) // Return
        XCTAssertTrue(KeyClassifier.isQualifying(keyCode: 48)) // Tab
        XCTAssertTrue(KeyClassifier.isQualifying(keyCode: 49)) // Space
        XCTAssertTrue(KeyClassifier.isQualifying(keyCode: 51)) // Delete
        XCTAssertTrue(KeyClassifier.isQualifying(keyCode: 82)) // Keypad 0
    }

    func testKeyboardEventClassifierClassifiesV1Categories() {
        XCTAssertEqual(KeyboardEventClassifier.classify(event: makeKeyboardEvent(output: "a")), .english)
        XCTAssertEqual(KeyboardEventClassifier.classify(event: makeKeyboardEvent(output: "7")), .number)
        XCTAssertEqual(KeyboardEventClassifier.classify(event: makeKeyboardEvent(output: "!")), .symbol)
        XCTAssertEqual(KeyboardEventClassifier.classify(event: makeKeyboardEvent(output: " ")), .space)
    }

    func testKeyboardEventClassifierIgnoresControlAndNavigationKeys() {
        XCTAssertEqual(KeyboardEventClassifier.classify(event: makeKeyboardEvent(keyCode: 36)), .ignored) // Return
        XCTAssertEqual(KeyboardEventClassifier.classify(event: makeKeyboardEvent(keyCode: 48)), .ignored) // Tab
        XCTAssertEqual(KeyboardEventClassifier.classify(event: makeKeyboardEvent(keyCode: 51)), .ignored) // Delete
        XCTAssertEqual(KeyboardEventClassifier.classify(event: makeKeyboardEvent(keyCode: 54)), .ignored) // Command
        XCTAssertEqual(KeyboardEventClassifier.classify(event: makeKeyboardEvent(keyCode: 123)), .ignored) // Left arrow
    }

    func testKeyboardEventClassifierIgnoresUnsupportedEvents() {
        XCTAssertEqual(KeyboardEventClassifier.classify(event: makeKeyboardEvent(output: "你")), .ignored)
        XCTAssertEqual(KeyboardEventClassifier.classify(event: makeKeyboardEvent(keyDown: false)), .ignored)
        XCTAssertEqual(KeyboardEventClassifier.classify(event: makeKeyboardEvent(output: "ab")), .ignored)
    }

    func testEventTapStartDuringStoppingIsRetainedUntilCleanup() {
        var lifecycle = EventTapLifecycleModel()

        XCTAssertTrue(lifecycle.requestStart())
        XCTAssertTrue(lifecycle.requestStop())
        XCTAssertFalse(lifecycle.requestStart())
        XCTAssertTrue(lifecycle.pendingStartAfterStop)

        XCTAssertTrue(lifecycle.didCreateTap())
        XCTAssertEqual(lifecycle.state, .stopping)
        XCTAssertTrue(lifecycle.finishStop())
        XCTAssertEqual(lifecycle.state, .stopped)
        XCTAssertFalse(lifecycle.pendingStartAfterStop)

        XCTAssertTrue(lifecycle.requestStart())
        XCTAssertEqual(lifecycle.state, .starting)
        XCTAssertFalse(lifecycle.pendingStartAfterStop)
    }

    func testEventTapRapidStartStopStartProducesOneRestartRequest() {
        var lifecycle = EventTapLifecycleModel()

        XCTAssertTrue(lifecycle.requestStart())
        XCTAssertFalse(lifecycle.requestStart())
        XCTAssertFalse(lifecycle.didCreateTap())
        XCTAssertEqual(lifecycle.state, .running)
        XCTAssertTrue(lifecycle.requestStop())
        XCTAssertFalse(lifecycle.requestStop())
        XCTAssertFalse(lifecycle.requestStart())
        XCTAssertFalse(lifecycle.requestStart())
        XCTAssertTrue(lifecycle.pendingStartAfterStop)

        XCTAssertTrue(lifecycle.finishStop())
        XCTAssertTrue(lifecycle.requestStart())
        XCTAssertFalse(lifecycle.requestStart())
        XCTAssertFalse(lifecycle.didCreateTap())
        XCTAssertEqual(lifecycle.state, .running)
    }

    func testTypingCategoryHasNoAssociatedPayload() {
        let categories: [TypingCategory] = [.english, .number, .symbol, .space, .ignored]
        for category in categories {
            XCTAssertTrue(Mirror(reflecting: category).children.isEmpty)
        }
    }

    func testTypingMetricsAggregateCategoriesAndComputeTypedCharacters() {
        var metrics = TypingMetrics()
        metrics.record(.english)
        metrics.record(.number)
        metrics.record(.symbol)
        metrics.record(.space)

        XCTAssertEqual(metrics.englishCharacters, 1)
        XCTAssertEqual(metrics.numberCharacters, 1)
        XCTAssertEqual(metrics.symbolCharacters, 1)
        XCTAssertEqual(metrics.spaceCharacters, 1)
        XCTAssertEqual(metrics.typedCharacters, 4)
        XCTAssertEqual(metrics.estimatedEnglishWords, 0)
    }

    func testIgnoredCategoryDoesNotChangeTypingMetrics() {
        var metrics = TypingMetrics()
        metrics.record(.ignored)
        XCTAssertEqual(metrics.typedCharacters, 0)
    }

    func testTypingCounterAggregatesPerAppAndFindsMostTypedApp() {
        let appA = AppIdentity(bundleIdentifier: "com.example.a", displayName: "App A")
        let appB = AppIdentity(bundleIdentifier: "com.example.b", displayName: "App B")
        let counter = TypingCounter(appProvider: { appA })
        let start = Date(timeIntervalSinceReferenceDate: 100)

        for offset in 0..<10 {
            counter.record(category: .english, app: appA, at: start.addingTimeInterval(Double(offset)))
        }
        for offset in 0..<20 {
            counter.record(category: .english, app: appB, at: start.addingTimeInterval(Double(offset)))
        }

        XCTAssertEqual(counter.appMetricsByApp[appA]?.typedCharacters, 10)
        XCTAssertEqual(counter.appMetricsByApp[appB]?.typedCharacters, 20)
        XCTAssertEqual(counter.mostTypedInApp, appB)
    }

    func testEstimatedEnglishWordsUsesOnlyEnglishAggregate() {
        var metrics = TypingMetrics()
        for _ in 0..<100 {
            metrics.record(.english)
        }
        for _ in 0..<100 {
            metrics.record(.symbol)
        }

        XCTAssertEqual(metrics.estimatedEnglishWords, 20)
    }

    func testDurationFormattingRetainsSecondPrecision() {
        XCTAssertEqual(
            DayTraceDurationFormatter.components(for: 754.9),
            DayTraceDurationFormatter.Components(hours: 0, minutes: 12, seconds: 34)
        )
        XCTAssertEqual(
            DayTraceDurationFormatter.components(for: 3661),
            DayTraceDurationFormatter.Components(hours: 1, minutes: 1, seconds: 1)
        )
    }

    func testDurationFormattingSafelyHandlesNonFiniteAndNegativeValues() {
        let zero = DayTraceDurationFormatter.Components(hours: 0, minutes: 0, seconds: 0)
        XCTAssertEqual(DayTraceDurationFormatter.components(for: -1), zero)
        XCTAssertEqual(DayTraceDurationFormatter.components(for: .nan), zero)
        XCTAssertEqual(DayTraceDurationFormatter.components(for: .infinity), zero)
        XCTAssertEqual(DayTraceDurationFormatter.components(for: -.infinity), zero)
    }

    func testMenuBarDisplayModeLiveRefreshPolicy() {
        XCTAssertFalse(MenuBarDisplayMode.iconOnly.requiresLiveRefresh)
        XCTAssertTrue(MenuBarDisplayMode.usage.requiresLiveRefresh)
        XCTAssertTrue(MenuBarDisplayMode.typing.requiresLiveRefresh)
        XCTAssertTrue(MenuBarDisplayMode.usageAndTyping.requiresLiveRefresh)
    }

    func testMenuBarUsageTitleChangesWithSecondPrecision() {
        let locale = Locale(identifier: "en_US")
        let first = DayTraceDurationFormatter.string(seconds: 677, locale: locale)
        let second = DayTraceDurationFormatter.string(seconds: 678, locale: locale)

        XCTAssertNotEqual(first, second)
    }

    func testTypingActivityFormattingLeavesUnavailableTypingSpeedUnformatted() {
        XCTAssertNil(TypingActivityFormatting.roundedCPM(nil))
        XCTAssertNil(TypingActivityFormatting.roundedCPM(0))
        XCTAssertNil(TypingActivityFormatting.roundedCPM(.infinity))
        XCTAssertEqual(TypingActivityFormatting.roundedCPM(42.6), 43)
    }

    func testTypingSessionsUseFiveMinuteTimeout() {
        let counter = TypingCounter(appProvider: { nil })
        let start = Date(timeIntervalSinceReferenceDate: 200)

        counter.record(category: .english, app: nil, at: start)
        counter.record(category: .number, app: nil, at: start.addingTimeInterval(299))
        XCTAssertEqual(counter.typingSessions, 1)

        counter.record(category: .symbol, app: nil, at: start.addingTimeInterval(599))
        XCTAssertEqual(counter.typingSessions, 2)
    }

    func testIgnoredEventsDoNotExtendTypingSession() {
        let counter = TypingCounter(appProvider: { nil })
        let start = Date(timeIntervalSinceReferenceDate: 300)

        counter.record(category: .english, app: nil, at: start)
        counter.record(category: .ignored, app: nil, at: start.addingTimeInterval(299))
        counter.record(category: .english, app: nil, at: start.addingTimeInterval(300))

        XCTAssertEqual(counter.typingSessions, 2)
    }

    func testActiveTypingDurationCapsLongInterEventIntervals() {
        let counter = TypingCounter(appProvider: { nil })
        let start = Date(timeIntervalSinceReferenceDate: 400)

        counter.record(category: .english, app: nil, at: start)
        counter.record(category: .english, app: nil, at: start.addingTimeInterval(2))
        counter.record(category: .english, app: nil, at: start.addingTimeInterval(62))

        XCTAssertEqual(counter.activeTypingDuration, 7, accuracy: 0.001)
    }

    func testCharactersPerMinuteUsesActiveTypingDuration() {
        let counter = TypingCounter(appProvider: { nil })
        let start = Date(timeIntervalSinceReferenceDate: 500)

        counter.record(category: .english, app: nil, at: start)
        counter.record(category: .number, app: nil, at: start.addingTimeInterval(2))
        counter.record(category: .symbol, app: nil, at: start.addingTimeInterval(6))

        XCTAssertEqual(counter.charactersPerMinute ?? 0, 30, accuracy: 0.001)
    }

    func testCharactersPerMinuteIsNilWithoutActiveDuration() {
        let counter = TypingCounter(appProvider: { nil })
        counter.record(category: .english, app: nil, at: Date(timeIntervalSinceReferenceDate: 600))
        XCTAssertNil(counter.charactersPerMinute)
    }

    func testResetMetricsClearsAllTypingAggregatesAndRuntimeState() {
        let app = AppIdentity(bundleIdentifier: "com.example.reset", displayName: "Reset App")
        let counter = TypingCounter(appProvider: { app })
        let start = Date(timeIntervalSinceReferenceDate: 700)

        counter.record(category: .english, app: app, at: start)
        counter.record(category: .english, app: app, at: start.addingTimeInterval(2))
        counter.resetMetrics()

        XCTAssertEqual(counter.metrics.typedCharacters, 0)
        XCTAssertTrue(counter.appMetricsByApp.isEmpty)
        XCTAssertEqual(counter.typingSessions, 0)
        XCTAssertEqual(counter.activeTypingDuration, 0, accuracy: 0.001)
        XCTAssertNil(counter.charactersPerMinute)
        XCTAssertNil(counter.mostTypedInApp)
    }

    func testUsageStoreAccumulatesSameDayAppUsageWithSeconds() {
        let calendar = fixedCalendar(timeZone: "UTC")
        let store = UsageStore(inMemory: true, calendarProvider: { calendar })
        let app = AppIdentity(bundleIdentifier: "com.example.editor", displayName: "Editor")
        let start = makeDate(day: 30, hour: 9, minute: 0, second: 0, calendar: calendar)

        store.recordForegroundInterval(ForegroundInterval(
            id: UUID(), app: app, start: start, end: start.addingTimeInterval(3727), duration: 3727
        ))
        store.checkpoint(at: start.addingTimeInterval(3727))

        XCTAssertEqual(store.snapshot(at: start).appUsageByApp[app] ?? 0, 3727, accuracy: 0.001)
    }

    func testUsageStoreSplitsAppUsageAtLocalMidnight() {
        let calendar = fixedCalendar(timeZone: "UTC")
        let store = UsageStore(inMemory: true, calendarProvider: { calendar })
        let app = AppIdentity(bundleIdentifier: "com.example.browser", displayName: "Browser")
        let start = makeDate(day: 30, hour: 23, minute: 59, second: 55, calendar: calendar)
        let end = makeDate(day: 31, hour: 0, minute: 0, second: 10, calendar: calendar)

        store.recordForegroundInterval(ForegroundInterval(id: UUID(), app: app, start: start, end: end, duration: 15))
        store.checkpoint(at: end)

        XCTAssertEqual(store.snapshot(at: start).appUsageByApp[app] ?? 0, 5, accuracy: 0.001)
        XCTAssertEqual(store.snapshot(at: end).appUsageByApp[app] ?? 0, 10, accuracy: 0.001)
    }

    func testUsageStoreSplitsWebsiteUsageAtLocalMidnight() {
        let calendar = fixedCalendar(timeZone: "UTC")
        let store = UsageStore(inMemory: true, calendarProvider: { calendar })
        let browser = AppIdentity(bundleIdentifier: "com.google.Chrome", displayName: "Google Chrome")
        let start = makeDate(day: 30, hour: 23, minute: 59, second: 55, calendar: calendar)
        let end = makeDate(day: 31, hour: 0, minute: 0, second: 10, calendar: calendar)

        store.recordForegroundInterval(ForegroundInterval(id: UUID(), app: browser, start: start, end: end, duration: 15))
        store.recordWebsiteInterval(DomainInterval(domain: "chatgpt.com", start: start, end: end, duration: 15))
        store.checkpoint(at: end)

        XCTAssertEqual(store.snapshot(at: start).websiteUsageByDomain["chatgpt.com"] ?? 0, 5, accuracy: 0.001)
        XCTAssertEqual(store.snapshot(at: end).websiteUsageByDomain["chatgpt.com"] ?? 0, 10, accuracy: 0.001)
    }

    func testWebsiteUsageDoesNotIncreaseTotalUsage() {
        let calendar = fixedCalendar(timeZone: "UTC")
        let store = UsageStore(inMemory: true, calendarProvider: { calendar })
        let chrome = AppIdentity(bundleIdentifier: "com.google.Chrome", displayName: "Google Chrome")
        let start = makeDate(day: 30, hour: 12, minute: 0, second: 0, calendar: calendar)

        store.recordForegroundInterval(ForegroundInterval(
            id: UUID(), app: chrome, start: start, end: start.addingTimeInterval(600), duration: 600
        ))
        store.recordWebsiteInterval(DomainInterval(
            domain: "github.com", start: start, end: start.addingTimeInterval(600), duration: 600
        ))
        store.checkpoint(at: start.addingTimeInterval(600))

        XCTAssertEqual(store.snapshot(at: start).totalUsage, 600, accuracy: 0.001)
        XCTAssertEqual(store.snapshot(at: start).websiteUsageByDomain["github.com"] ?? 0, 600, accuracy: 0.001)
    }

    func testWebsiteAttributionIsCappedByChromeUsage() {
        let calendar = fixedCalendar(timeZone: "UTC")
        let store = UsageStore(inMemory: true, calendarProvider: { calendar })
        let chrome = AppIdentity(bundleIdentifier: "com.google.Chrome", displayName: "Google Chrome")
        let start = makeDate(day: 30, hour: 12, minute: 0, second: 0, calendar: calendar)

        store.recordForegroundInterval(ForegroundInterval(
            id: UUID(), app: chrome, start: start, end: start.addingTimeInterval(60), duration: 60
        ))
        store.recordWebsiteInterval(DomainInterval(
            domain: "github.com", start: start, end: start.addingTimeInterval(120), duration: 120
        ))
        store.checkpoint(at: start.addingTimeInterval(120))

        let snapshot = store.snapshot(at: start)
        XCTAssertEqual(snapshot.totalUsage, 60, accuracy: 0.001)
        XCTAssertLessThanOrEqual(snapshot.websiteUsageByDomain.values.reduce(0, +), 60.001)
    }

    func testWebsiteReconciliationLeavesNonOverageUnchanged() {
        let result = WebsiteUsageReconciliation.reconcile(
            websiteUsage: ["chatgpt.com": 40, "github.com": 60],
            chromeUsage: 120
        )

        XCTAssertEqual(result["chatgpt.com"] ?? 0, 40, accuracy: 0.001)
        XCTAssertEqual(result["github.com"] ?? 0, 60, accuracy: 0.001)
    }

    func testWebsiteReconciliationProportionallyClipsOverage() {
        let result = WebsiteUsageReconciliation.reconcile(
            websiteUsage: ["chatgpt.com": 80, "github.com": 40],
            chromeUsage: 60
        )

        XCTAssertEqual(result["chatgpt.com"] ?? 0, 40, accuracy: 0.001)
        XCTAssertEqual(result["github.com"] ?? 0, 20, accuracy: 0.001)
        XCTAssertEqual(result.values.reduce(0, +), 60, accuracy: 0.001)
    }

    func testWebsiteReconciliationDropsInvalidValuesAndMissingChrome() {
        let withoutChrome = WebsiteUsageReconciliation.reconcile(
            websiteUsage: ["chatgpt.com": 20, "github.com": -.infinity],
            chromeUsage: 0
        )
        let withInvalidChrome = WebsiteUsageReconciliation.reconcile(
            websiteUsage: ["chatgpt.com": 20, "github.com": -5, "docs.google.com": .nan],
            chromeUsage: .nan
        )

        XCTAssertTrue(withoutChrome.isEmpty)
        XCTAssertTrue(withInvalidChrome.isEmpty)
    }

    func testWebsitePersistenceRemainsRawWhileSnapshotsAndExportReconcile() throws {
        let calendar = fixedCalendar(timeZone: "UTC")
        let store = UsageStore(inMemory: true, calendarProvider: { calendar })
        let chrome = AppIdentity(bundleIdentifier: "com.google.Chrome", displayName: "Google Chrome")
        let start = makeDate(day: 30, hour: 12, minute: 0, second: 0, calendar: calendar)

        store.recordForegroundInterval(ForegroundInterval(
            id: UUID(), app: chrome, start: start, end: start.addingTimeInterval(100), duration: 100
        ))
        store.recordWebsiteInterval(DomainInterval(
            domain: "chatgpt.com", start: start, end: start.addingTimeInterval(80), duration: 80
        ))
        store.recordWebsiteInterval(DomainInterval(
            domain: "github.com", start: start.addingTimeInterval(80), end: start.addingTimeInterval(120), duration: 40
        ))
        store.checkpoint(at: start.addingTimeInterval(120))

        XCTAssertEqual(store.rawWebsiteDurationForTesting(at: start, domain: "chatgpt.com"), 80, accuracy: 0.001)
        XCTAssertEqual(store.rawWebsiteDurationForTesting(at: start, domain: "github.com"), 40, accuracy: 0.001)

        let snapshot = store.snapshot(at: start)
        let history = store.historySnapshot(for: .today, at: start.addingTimeInterval(120))
        XCTAssertEqual(snapshot.websiteUsageByDomain["chatgpt.com"] ?? 0, 66.666, accuracy: 0.001)
        XCTAssertEqual(snapshot.websiteUsageByDomain["github.com"] ?? 0, 33.333, accuracy: 0.001)
        XCTAssertEqual(history.websiteUsageByDomain, snapshot.websiteUsageByDomain)

        let data = try XCTUnwrap(store.exportAggregatesJSON())
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let websiteRows = try XCTUnwrap(object["websiteUsage"] as? [[String: Any]])
        let exported = Dictionary(uniqueKeysWithValues: websiteRows.compactMap { row -> (String, Double)? in
            guard let domain = row["domain"] as? String,
                  let duration = row["durationSeconds"] as? Double else { return nil }
            return (domain, duration)
        })
        XCTAssertEqual(exported["chatgpt.com"] ?? 0, 66.666, accuracy: 0.001)
        XCTAssertEqual(exported["github.com"] ?? 0, 33.333, accuracy: 0.001)
    }

    func testHistoryReconcilesWebsitePerDayBeforeRangeAggregation() {
        let calendar = fixedCalendar(timeZone: "UTC")
        let store = UsageStore(inMemory: true, calendarProvider: { calendar })
        let chrome = AppIdentity(bundleIdentifier: "com.google.Chrome", displayName: "Google Chrome")
        let previousDay = makeDate(day: 30, hour: 12, minute: 0, second: 0, calendar: calendar)
        let currentDay = makeDate(day: 31, hour: 12, minute: 0, second: 0, calendar: calendar)

        for day in [previousDay, currentDay] {
            store.recordForegroundInterval(ForegroundInterval(
                id: UUID(), app: chrome, start: day, end: day.addingTimeInterval(60), duration: 60
            ))
            store.recordWebsiteInterval(DomainInterval(
                domain: "chatgpt.com", start: day, end: day.addingTimeInterval(120), duration: 120
            ))
        }
        store.checkpoint(at: currentDay.addingTimeInterval(120))

        let history = store.historySnapshot(for: .last7Days, at: currentDay)
        XCTAssertEqual(history.websiteUsageByDomain["chatgpt.com"] ?? 0, 120, accuracy: 0.001)
        XCTAssertEqual(history.dailyTotals.last?.totalUsage ?? 0, 60, accuracy: 0.001)
    }

    func testHistoryAggregatesCalendarDaysAndIncludesCurrentRuntime() {
        let calendar = fixedCalendar(timeZone: "UTC")
        let store = UsageStore(inMemory: true, calendarProvider: { calendar })
        let app = AppIdentity(bundleIdentifier: "com.example.history", displayName: "History App")
        let yesterday = makeDate(day: 30, hour: 10, minute: 0, second: 0, calendar: calendar)
        let today = makeDate(day: 31, hour: 10, minute: 0, second: 0, calendar: calendar)

        store.recordForegroundInterval(ForegroundInterval(
            id: UUID(), app: app, start: yesterday, end: yesterday.addingTimeInterval(90), duration: 90
        ))
        store.checkpoint(at: yesterday.addingTimeInterval(90))
        store.recordForegroundInterval(ForegroundInterval(
            id: UUID(), app: app, start: today, end: today.addingTimeInterval(30), duration: 30
        ))

        let history = store.historySnapshot(for: .last7Days, at: today)
        XCTAssertEqual(history.totalUsage, 120, accuracy: 0.001)
        XCTAssertEqual(history.dailyTotals.count, 7)
        XCTAssertEqual(history.dailyTotals.last?.totalUsage ?? 0, 30, accuracy: 0.001)
    }

    func testHistoryYesterdayExcludesCurrentDay() {
        let calendar = fixedCalendar(timeZone: "UTC")
        let store = UsageStore(inMemory: true, calendarProvider: { calendar })
        let app = AppIdentity(bundleIdentifier: "com.example.history", displayName: "History App")
        let yesterday = makeDate(day: 30, hour: 10, minute: 0, second: 0, calendar: calendar)
        let today = makeDate(day: 31, hour: 10, minute: 0, second: 0, calendar: calendar)

        store.recordForegroundInterval(ForegroundInterval(
            id: UUID(), app: app, start: yesterday, end: yesterday.addingTimeInterval(90), duration: 90
        ))
        store.recordForegroundInterval(ForegroundInterval(
            id: UUID(), app: app, start: today, end: today.addingTimeInterval(30), duration: 30
        ))

        let history = store.historySnapshot(for: .yesterday, at: today)
        XCTAssertEqual(history.totalUsage, 90, accuracy: 0.001)
        XCTAssertEqual(history.dailyTotals.count, 1)
        XCTAssertEqual(history.endDate, yesterday)
    }

    func testHistoryYesterdayCrossesMonthBoundary() {
        let calendar = fixedCalendar(timeZone: "UTC")
        let store = UsageStore(inMemory: true, calendarProvider: { calendar })
        let app = AppIdentity(bundleIdentifier: "com.example.month", displayName: "Month App")
        let previousMonth = makeDate(year: 2026, month: 8, day: 31, hour: 23, minute: 0, second: 0, calendar: calendar)
        let current = makeDate(year: 2026, month: 9, day: 1, hour: 10, minute: 0, second: 0, calendar: calendar)

        store.recordForegroundInterval(ForegroundInterval(
            id: UUID(), app: app, start: previousMonth, end: previousMonth.addingTimeInterval(15), duration: 15
        ))
        store.recordForegroundInterval(ForegroundInterval(
            id: UUID(), app: app, start: current, end: current.addingTimeInterval(30), duration: 30
        ))

        let history = store.historySnapshot(for: .yesterday, at: current)
        XCTAssertEqual(history.totalUsage, 15, accuracy: 0.001)
        XCTAssertEqual(history.dailyTotals.count, 1)
    }

    func testHistoryYesterdayCrossesYearBoundary() {
        let calendar = fixedCalendar(timeZone: "UTC")
        let store = UsageStore(inMemory: true, calendarProvider: { calendar })
        let app = AppIdentity(bundleIdentifier: "com.example.year", displayName: "Year App")
        let previousYear = makeDate(year: 2026, month: 12, day: 31, hour: 23, minute: 0, second: 0, calendar: calendar)
        let current = makeDate(year: 2027, month: 1, day: 1, hour: 10, minute: 0, second: 0, calendar: calendar)

        store.recordForegroundInterval(ForegroundInterval(
            id: UUID(), app: app, start: previousYear, end: previousYear.addingTimeInterval(20), duration: 20
        ))

        let history = store.historySnapshot(for: .yesterday, at: current)
        XCTAssertEqual(history.totalUsage, 20, accuracy: 0.001)
        XCTAssertEqual(history.startDate, calendar.startOfDay(for: previousYear))
    }

    func testHistoryLastSevenDaysCrossesMonthBoundary() {
        let calendar = fixedCalendar(timeZone: "UTC")
        let store = UsageStore(inMemory: true, calendarProvider: { calendar })
        let app = AppIdentity(bundleIdentifier: "com.example.seven", displayName: "Seven Day App")
        let current = makeDate(year: 2026, month: 9, day: 2, hour: 12, minute: 0, second: 0, calendar: calendar)
        let first = makeDate(year: 2026, month: 8, day: 27, hour: 8, minute: 0, second: 0, calendar: calendar)

        for offset in 0..<7 {
            let day = calendar.date(byAdding: .day, value: offset, to: first)!
            store.recordForegroundInterval(ForegroundInterval(
                id: UUID(), app: app, start: day, end: day.addingTimeInterval(1), duration: 1
            ))
        }

        let history = store.historySnapshot(for: .last7Days, at: current)
        XCTAssertEqual(history.dailyTotals.count, 7)
        XCTAssertEqual(history.totalUsage, 7, accuracy: 0.001)
        XCTAssertEqual(history.startDate, calendar.startOfDay(for: first))
    }

    func testHistoryLastSevenDaysCrossesYearBoundary() {
        let calendar = fixedCalendar(timeZone: "UTC")
        let store = UsageStore(inMemory: true, calendarProvider: { calendar })
        let app = AppIdentity(bundleIdentifier: "com.example.yearseven", displayName: "Year Seven App")
        let current = makeDate(year: 2027, month: 1, day: 3, hour: 12, minute: 0, second: 0, calendar: calendar)
        let first = makeDate(year: 2026, month: 12, day: 28, hour: 8, minute: 0, second: 0, calendar: calendar)

        for offset in 0..<7 {
            let day = calendar.date(byAdding: .day, value: offset, to: first)!
            store.recordForegroundInterval(ForegroundInterval(
                id: UUID(), app: app, start: day, end: day.addingTimeInterval(1), duration: 1
            ))
        }

        let history = store.historySnapshot(for: .last7Days, at: current)
        XCTAssertEqual(history.dailyTotals.count, 7)
        XCTAssertEqual(history.totalUsage, 7, accuracy: 0.001)
        XCTAssertEqual(history.startDate, calendar.startOfDay(for: first))
    }

    func testHistoryThisMonthUsesCalendarMonthStart() {
        let calendar = fixedCalendar(timeZone: "UTC")
        let store = UsageStore(inMemory: true, calendarProvider: { calendar })
        let app = AppIdentity(bundleIdentifier: "com.example.thismonth", displayName: "This Month App")
        let outside = makeDate(year: 2026, month: 8, day: 31, hour: 12, minute: 0, second: 0, calendar: calendar)
        let inside = makeDate(year: 2026, month: 9, day: 1, hour: 12, minute: 0, second: 0, calendar: calendar)
        let current = makeDate(year: 2026, month: 9, day: 15, hour: 12, minute: 0, second: 0, calendar: calendar)

        store.recordForegroundInterval(ForegroundInterval(id: UUID(), app: app, start: outside, end: outside.addingTimeInterval(10), duration: 10))
        store.recordForegroundInterval(ForegroundInterval(id: UUID(), app: app, start: inside, end: inside.addingTimeInterval(20), duration: 20))

        let history = store.historySnapshot(for: .thisMonth, at: current)
        XCTAssertEqual(history.totalUsage, 20, accuracy: 0.001)
        XCTAssertEqual(history.dailyTotals.count, 15)
        XCTAssertEqual(history.startDate, calendar.startOfDay(for: inside))
    }

    func testHistoryThisWeekUsesInjectedCalendarWeekStart() {
        var calendar = fixedCalendar(timeZone: "UTC")
        calendar.firstWeekday = 2 // Monday
        calendar.minimumDaysInFirstWeek = 4
        let store = UsageStore(inMemory: true, calendarProvider: { calendar })
        let app = AppIdentity(bundleIdentifier: "com.example.thisweek", displayName: "This Week App")
        let sunday = makeDate(year: 2026, month: 9, day: 13, hour: 12, minute: 0, second: 0, calendar: calendar)
        let monday = makeDate(year: 2026, month: 9, day: 14, hour: 12, minute: 0, second: 0, calendar: calendar)
        let tuesday = makeDate(year: 2026, month: 9, day: 15, hour: 12, minute: 0, second: 0, calendar: calendar)

        store.recordForegroundInterval(ForegroundInterval(id: UUID(), app: app, start: sunday, end: sunday.addingTimeInterval(50), duration: 50))
        store.recordForegroundInterval(ForegroundInterval(id: UUID(), app: app, start: monday, end: monday.addingTimeInterval(10), duration: 10))
        store.recordForegroundInterval(ForegroundInterval(id: UUID(), app: app, start: tuesday, end: tuesday.addingTimeInterval(20), duration: 20))

        let history = store.historySnapshot(for: .thisWeek, at: tuesday)
        XCTAssertEqual(history.totalUsage, 30, accuracy: 0.001)
        XCTAssertEqual(history.startDate, calendar.startOfDay(for: monday))
    }

    func testHistoryLast30DaysIncludesMissingDaysAsZeroInStableOrder() {
        let calendar = fixedCalendar(timeZone: "UTC")
        let store = UsageStore(inMemory: true, calendarProvider: { calendar })
        let app = AppIdentity(bundleIdentifier: "com.example.heatmap", displayName: "Heatmap App")
        let first = makeDate(year: 2026, month: 9, day: 1, hour: 12, minute: 0, second: 0, calendar: calendar)
        let current = makeDate(year: 2026, month: 9, day: 30, hour: 12, minute: 0, second: 0, calendar: calendar)

        store.recordForegroundInterval(ForegroundInterval(id: UUID(), app: app, start: first, end: first.addingTimeInterval(10), duration: 10))
        store.recordForegroundInterval(ForegroundInterval(id: UUID(), app: app, start: current, end: current.addingTimeInterval(20), duration: 20))

        let history = store.historySnapshot(for: .last30Days, at: current)
        XCTAssertEqual(history.dailyTotals.count, 30)
        XCTAssertEqual(history.dailyTotals.first?.date, calendar.startOfDay(for: first))
        XCTAssertEqual(history.dailyTotals.last?.date, calendar.startOfDay(for: current))
        XCTAssertEqual(history.dailyTotals[1].totalUsage, 0, accuracy: 0.001)
        XCTAssertEqual(history.totalUsage, 30, accuracy: 0.001)
    }

    func testComparisonReferenceDateUsesCalendarBoundariesAndLikeForLikeMonth() {
        let calendar = fixedCalendar(timeZone: "UTC")
        let january = makeDate(year: 2026, month: 1, day: 15, hour: 12, minute: 0, second: 0, calendar: calendar)
        let march = makeDate(year: 2024, month: 3, day: 31, hour: 12, minute: 0, second: 0, calendar: calendar)

        XCTAssertEqual(
            calendar.component(.month, from: UsageComparisonPeriod.referenceDate(for: .thisMonth, date: january, calendar: calendar)),
            12
        )
        XCTAssertEqual(
            calendar.component(.year, from: UsageComparisonPeriod.referenceDate(for: .thisMonth, date: january, calendar: calendar)),
            2025
        )
        XCTAssertEqual(
            calendar.component(.day, from: UsageComparisonPeriod.referenceDate(for: .thisMonth, date: march, calendar: calendar)),
            29
        )
        XCTAssertEqual(
            calendar.component(.day, from: UsageComparisonPeriod.referenceDate(for: .last7Days, date: march, calendar: calendar)),
            24
        )
    }

    func testAnalyticsClampsInvalidValuesAndKeepsStableTieOrdering() {
        let delta = AnalyticsDelta(current: .nan, previous: -.infinity)
        XCTAssertEqual(delta.current, 0)
        XCTAssertEqual(delta.previous, 0)
        XCTAssertEqual(delta.absolute, 0)
        XCTAssertNil(delta.percentage)

        let appA = AppIdentity(bundleIdentifier: "com.example.a", displayName: "Same")
        let appB = AppIdentity(bundleIdentifier: "com.example.b", displayName: "Same")
        var current = HistoryUsageSnapshot(range: .today, startDate: Date(), endDate: Date())
        current.appUsageByApp[appB] = 120
        current.appUsageByApp[appA] = 120
        let comparison = UsagePeriodComparison(current: current, previous: HistoryUsageSnapshot(range: .today, startDate: Date(), endDate: Date()))
        XCTAssertEqual(comparison.topAppChanges.map(\.entityID), [appA.bundleIdentifier, appB.bundleIdentifier])
    }

    func testAnalyticsAverageUsesCalendarIncludedDaysAndEmptyRangeIsZero() {
        let calendar = fixedCalendar(timeZone: "UTC")
        let day = makeDate(year: 2026, month: 9, day: 30, hour: 12, minute: 0, second: 0, calendar: calendar)
        var snapshot = HistoryUsageSnapshot(range: .last7Days, startDate: day.addingTimeInterval(-6 * 86_400), endDate: day)
        snapshot.appUsageByApp[AppIdentity(bundleIdentifier: "com.example.average", displayName: "Average App")] = 180
        snapshot.dailyTotals = [
            HistoryDay(date: day.addingTimeInterval(-6 * 86_400), totalUsage: 60),
            HistoryDay(date: day, totalUsage: 120)
        ]

        XCTAssertEqual(DayTraceAnalytics.includedDayCount(for: snapshot, asOf: day, calendar: calendar), 2)
        XCTAssertEqual(DayTraceAnalytics.average(for: snapshot, asOf: day, calendar: calendar), 90, accuracy: 0.001)

        var empty = snapshot
        empty.dailyTotals = []
        XCTAssertEqual(DayTraceAnalytics.average(for: empty, asOf: day, calendar: calendar), 0, accuracy: 0.001)
    }

    func testDeleteAllDataClearsSavedAndRuntimeAggregates() {
        let calendar = fixedCalendar(timeZone: "UTC")
        let store = UsageStore(inMemory: true, calendarProvider: { calendar })
        let app = AppIdentity(bundleIdentifier: "com.example.delete", displayName: "Delete App")
        let date = makeDate(day: 30, hour: 11, minute: 0, second: 0, calendar: calendar)

        store.recordForegroundInterval(ForegroundInterval(
            id: UUID(), app: app, start: date, end: date.addingTimeInterval(10), duration: 10
        ))
        store.recordTyping(category: .english, app: app, at: date)
        store.checkpoint(at: date.addingTimeInterval(10))

        XCTAssertTrue(store.deleteAllData())
        let snapshot = store.snapshot(at: date.addingTimeInterval(10))
        XCTAssertTrue(snapshot.appUsageByApp.isEmpty)
        XCTAssertTrue(snapshot.typingMetrics.typedCharacters == 0)
    }

    func testDeleteClearsCursorsAndOnlyPersistsPostDeleteActivity() {
        let calendar = fixedCalendar(timeZone: "UTC")
        let store = UsageStore(inMemory: true, calendarProvider: { calendar })
        let app = AppIdentity(bundleIdentifier: "com.example.deletecursor", displayName: "Delete Cursor App")
        let date = makeDate(day: 30, hour: 11, minute: 0, second: 0, calendar: calendar)

        store.recordForegroundInterval(ForegroundInterval(
            id: UUID(), app: app, start: date, end: date.addingTimeInterval(10), duration: 10
        ))
        store.checkpoint(at: date.addingTimeInterval(10))
        XCTAssertEqual(store.snapshot(at: date).appUsageByApp[app] ?? 0, 10, accuracy: 0.001)

        XCTAssertTrue(store.deleteAllData())
        store.checkpoint(at: date.addingTimeInterval(20))
        XCTAssertTrue(store.snapshot(at: date.addingTimeInterval(20)).appUsageByApp.isEmpty)

        store.recordForegroundInterval(ForegroundInterval(
            id: UUID(), app: app, start: date.addingTimeInterval(30), end: date.addingTimeInterval(40), duration: 10
        ))
        store.checkpoint(at: date.addingTimeInterval(40))

        XCTAssertEqual(store.snapshot(at: date.addingTimeInterval(40)).appUsageByApp[app] ?? 0, 10, accuracy: 0.001)
    }

    func testDeleteActiveIntervalReanchorsTrackerBeforePostDeleteUsage() {
        let calendar = fixedCalendar(timeZone: "UTC")
        let store = UsageStore(inMemory: true, calendarProvider: { calendar })
        let tracker = ForegroundTracker()
        let domainTracker = DomainTracker(foregroundTracker: tracker)
        let app = AppIdentity(bundleIdentifier: "com.example.active-delete", displayName: "Active Delete App")
        let date = makeDate(day: 30, hour: 12, minute: 0, second: 0, calendar: calendar)

        tracker.handleSystemEventForTesting(.lock, at: date)
        tracker.handleSystemEventForTesting(.unlock, at: date.addingTimeInterval(10), frontmostApp: app)
        store.checkpoint(foregroundTracker: tracker, domainTracker: domainTracker, at: date.addingTimeInterval(20))
        XCTAssertEqual(store.snapshot(at: date).appUsageByApp[app] ?? 0, 10, accuracy: 0.001)

        XCTAssertTrue(store.deleteAllData())
        tracker.resetRuntimeState(at: date.addingTimeInterval(30))
        tracker.handleSystemEventForTesting(.lock, at: date.addingTimeInterval(30))
        tracker.handleSystemEventForTesting(.unlock, at: date.addingTimeInterval(40), frontmostApp: app)
        store.checkpoint(foregroundTracker: tracker, domainTracker: domainTracker, at: date.addingTimeInterval(50))

        XCTAssertEqual(store.snapshot(at: date.addingTimeInterval(50)).appUsageByApp[app] ?? 0, 10, accuracy: 0.001)
    }

    func testDeleteFailurePreservesDataAndReportsDegradedStatus() {
        let calendar = fixedCalendar(timeZone: "UTC")
        var shouldFail = false
        let store = UsageStore(
            inMemory: true,
            calendarProvider: { calendar },
            saveHandler: { context in
                if shouldFail {
                    throw NSError(domain: "DayTraceTests", code: 99)
                }
                try context.save()
            }
        )
        let app = AppIdentity(bundleIdentifier: "com.example.delete-failure", displayName: "Delete Failure App")
        let date = makeDate(day: 30, hour: 13, minute: 0, second: 0, calendar: calendar)

        store.recordForegroundInterval(ForegroundInterval(
            id: UUID(), app: app, start: date, end: date.addingTimeInterval(10), duration: 10
        ))
        store.checkpoint(at: date.addingTimeInterval(10))
        shouldFail = true

        XCTAssertFalse(store.deleteAllData())
        XCTAssertEqual(store.snapshot(at: date).appUsageByApp[app] ?? 0, 10, accuracy: 0.001)
        XCTAssertTrue(store.status != .ready)

        shouldFail = false
        XCTAssertTrue(store.deleteAllData())
        XCTAssertTrue(store.snapshot(at: date).appUsageByApp.isEmpty)
    }

    func testExportContainsAggregateFieldsOnly() throws {
        let calendar = fixedCalendar(timeZone: "UTC")
        let store = UsageStore(inMemory: true, calendarProvider: { calendar })
        let app = AppIdentity(bundleIdentifier: "com.example.export", displayName: "Export App")
        let date = makeDate(day: 30, hour: 11, minute: 0, second: 0, calendar: calendar)

        store.recordForegroundInterval(ForegroundInterval(
            id: UUID(), app: app, start: date, end: date.addingTimeInterval(10), duration: 10
        ))
        store.recordTyping(category: .english, app: app, at: date)
        store.checkpoint(at: date.addingTimeInterval(10))

        let data = try XCTUnwrap(store.exportAggregatesJSON())
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(text.contains("appUsage"))
        XCTAssertTrue(text.contains("englishCharacters"))
        XCTAssertFalse(text.contains("keyCode"))
        XCTAssertFalse(text.contains("typedText"))
        XCTAssertFalse(text.contains("pageContent"))
    }

    func testTypingUsagePersistsAggregateAndMetricVersion() {
        let calendar = fixedCalendar(timeZone: "UTC")
        let store = UsageStore(inMemory: true, calendarProvider: { calendar })
        let app = AppIdentity(bundleIdentifier: "com.example.editor", displayName: "Editor")
        let date = makeDate(day: 30, hour: 13, minute: 0, second: 0, calendar: calendar)

        store.recordTyping(category: .english, app: app, at: date)
        store.recordTyping(category: .number, app: app, at: date.addingTimeInterval(2))
        store.checkpoint(at: date.addingTimeInterval(2))

        let snapshot = store.snapshot(at: date)
        XCTAssertEqual(snapshot.typingMetrics.typedCharacters, 2)
        XCTAssertEqual(snapshot.typingAppMetricsByApp[app]?.typedCharacters, 2)
        XCTAssertEqual(snapshot.metricVersion, UsageStore.currentMetricVersion)
    }

    func testTypingResetStartsNewAggregateSessionAfterDeleteBoundary() {
        let app = AppIdentity(bundleIdentifier: "com.example.typing-delete", displayName: "Typing Delete App")
        let counter = TypingCounter(appProvider: { app })
        let date = Date(timeIntervalSinceReferenceDate: 70_000)

        counter.record(category: .english, app: app, at: date)
        counter.record(category: .english, app: app, at: date.addingTimeInterval(2))
        counter.resetMetrics()
        counter.record(category: .number, app: app, at: date.addingTimeInterval(600))

        XCTAssertEqual(counter.metrics.typedCharacters, 1)
        XCTAssertEqual(counter.appMetricsByApp[app]?.typedCharacters, 1)
        XCTAssertEqual(counter.typingSessions, 1)
        XCTAssertEqual(counter.activeTypingDuration, 0, accuracy: 0.001)
        XCTAssertEqual(counter.lastTypingEventAt, date.addingTimeInterval(600))
    }

    func testTypingUsageSplitsAcrossLocalMidnight() {
        let calendar = fixedCalendar(timeZone: "UTC")
        let store = UsageStore(inMemory: true, calendarProvider: { calendar })
        let date1 = makeDate(day: 30, hour: 23, minute: 59, second: 59, calendar: calendar)
        let date2 = makeDate(day: 31, hour: 0, minute: 0, second: 2, calendar: calendar)

        store.recordTyping(category: .english, app: nil, at: date1)
        store.recordTyping(category: .number, app: nil, at: date2)
        store.checkpoint(at: date2)

        XCTAssertEqual(store.snapshot(at: date1).typingMetrics.typedCharacters, 1)
        XCTAssertEqual(store.snapshot(at: date2).typingMetrics.typedCharacters, 1)
        XCTAssertEqual(store.snapshot(at: date2).typingSessions, 1)
    }

    func testTypingCheckpointIsIdempotent() {
        let calendar = fixedCalendar(timeZone: "UTC")
        let store = UsageStore(inMemory: true, calendarProvider: { calendar })
        let date = makeDate(day: 30, hour: 14, minute: 0, second: 0, calendar: calendar)

        store.recordTyping(category: .english, app: nil, at: date)
        store.checkpoint(at: date)
        store.checkpoint(at: date)

        let snapshot = store.snapshot(at: date)
        XCTAssertEqual(snapshot.typingMetrics.typedCharacters, 1)
        XCTAssertEqual(snapshot.typingSessions, 1)
    }

    func testUsageStoreRestartsWithCurrentDayAndMergesRuntimeWithoutDuplication() {
        let calendar = fixedCalendar(timeZone: "UTC")
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("DayTrace-\(UUID().uuidString).sqlite")
        defer {
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: url.appendingPathExtension("shm"))
            try? FileManager.default.removeItem(at: url.appendingPathExtension("wal"))
        }
        let app = AppIdentity(bundleIdentifier: "com.example.editor", displayName: "Editor")
        let start = makeDate(day: 30, hour: 9, minute: 0, second: 0, calendar: calendar)

        do {
            let first = UsageStore(storeURL: url, calendarProvider: { calendar })
            first.recordForegroundInterval(ForegroundInterval(
                id: UUID(), app: app, start: start, end: start.addingTimeInterval(3600), duration: 3600
            ))
            first.checkpoint(at: start.addingTimeInterval(3600))
        }

        do {
            let second = UsageStore(storeURL: url, calendarProvider: { calendar })
            XCTAssertEqual(second.snapshot(at: start).appUsageByApp[app] ?? 0, 3600, accuracy: 0.001)
            second.recordForegroundInterval(ForegroundInterval(
                id: UUID(), app: app, start: start.addingTimeInterval(7200), end: start.addingTimeInterval(7265), duration: 65
            ))
            second.checkpoint(at: start.addingTimeInterval(7265))
            second.checkpoint(at: start.addingTimeInterval(7265))
        }

        do {
            let third = UsageStore(storeURL: url, calendarProvider: { calendar })
            XCTAssertEqual(third.snapshot(at: start).appUsageByApp[app] ?? 0, 3665, accuracy: 0.001)
        }
    }

    func testLocalCalendarDateGroupingUsesInjectedTimezone() {
        let calendar = fixedCalendar(timeZone: "America/Los_Angeles")
        let store = UsageStore(inMemory: true, calendarProvider: { calendar })
        let app = AppIdentity(bundleIdentifier: "com.example.editor", displayName: "Editor")
        let start = makeDate(day: 30, hour: 23, minute: 59, second: 59, calendar: calendar)
        let end = makeDate(day: 31, hour: 0, minute: 0, second: 1, calendar: calendar)

        store.recordForegroundInterval(ForegroundInterval(id: UUID(), app: app, start: start, end: end, duration: 2))
        XCTAssertEqual(store.snapshot(at: start).appUsageByApp[app] ?? 0, 1, accuracy: 0.001)
        XCTAssertEqual(store.snapshot(at: end).appUsageByApp[app] ?? 0, 1, accuracy: 0.001)
    }

    func testPersistenceFailureDoesNotPreventRuntimeSnapshot() {
        let calendar = fixedCalendar(timeZone: "UTC")
        let invalidURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("DayTrace-missing-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("DayTrace.sqlite")
        let store = UsageStore(storeURL: invalidURL, calendarProvider: { calendar })
        let app = AppIdentity(bundleIdentifier: "com.example.editor", displayName: "Editor")
        let date = makeDate(day: 30, hour: 15, minute: 0, second: 0, calendar: calendar)

        store.recordForegroundInterval(ForegroundInterval(
            id: UUID(), app: app, start: date, end: date.addingTimeInterval(12), duration: 12
        ))
        store.checkpoint(at: date.addingTimeInterval(12))

        XCTAssertEqual(store.snapshot(at: date).appUsageByApp[app] ?? 0, 12, accuracy: 0.001)
    }

    func testPersistenceSaveFailureRetriesOriginalDeltaExactlyOnce() {
        let calendar = fixedCalendar(timeZone: "UTC")
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("DayTrace-retry-\(UUID().uuidString).sqlite")
        defer {
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + "-shm"))
            try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + "-wal"))
        }
        var shouldFail = true
        let app = AppIdentity(bundleIdentifier: "com.example.retry", displayName: "Retry App")
        let start = makeDate(day: 30, hour: 16, minute: 0, second: 0, calendar: calendar)
        let store = UsageStore(
            storeURL: url,
            calendarProvider: { calendar },
            saveHandler: { context in
                if shouldFail {
                    throw NSError(domain: "DayTraceTests", code: 1)
                }
                try context.save()
            }
        )

        let tracker = ForegroundTracker()
        let domainTracker = DomainTracker(foregroundTracker: tracker)
        tracker.appendClosedIntervalForTesting(ForegroundInterval(
            id: UUID(), app: app, start: start, end: start.addingTimeInterval(30), duration: 30
        ))

        store.checkpoint(
            foregroundTracker: tracker,
            domainTracker: domainTracker,
            at: start.addingTimeInterval(30)
        )
        XCTAssertTrue(store.status.isReady)
        XCTAssertNil(store.lastCheckpointAt)
        XCTAssertEqual(
            store.liveSnapshot(
                at: start.addingTimeInterval(30),
                foregroundTracker: tracker,
                domainTracker: domainTracker
            ).appUsageByApp[app] ?? 0,
            30,
            accuracy: 0.001
        )

        shouldFail = false
        store.checkpoint(
            foregroundTracker: tracker,
            domainTracker: domainTracker,
            at: start.addingTimeInterval(30)
        )
        XCTAssertEqual(store.status, .ready)
        store.checkpoint(
            foregroundTracker: tracker,
            domainTracker: domainTracker,
            at: start.addingTimeInterval(30)
        )

        tracker.appendClosedIntervalForTesting(ForegroundInterval(
            id: UUID(), app: app, start: start.addingTimeInterval(30), end: start.addingTimeInterval(40), duration: 10
        ))
        store.checkpoint(
            foregroundTracker: tracker,
            domainTracker: domainTracker,
            at: start.addingTimeInterval(40)
        )

        let reloaded = UsageStore(storeURL: url, calendarProvider: { calendar })
        XCTAssertEqual(reloaded.snapshot(at: start).appUsageByApp[app] ?? 0, 40, accuracy: 0.001)
    }

    func testAppRenameKeepsOneUsageAndTypingAggregateAndUpdatesDisplayName() {
        let calendar = fixedCalendar(timeZone: "UTC")
        let store = UsageStore(inMemory: true, calendarProvider: { calendar })
        let oldApp = AppIdentity(bundleIdentifier: "com.example.rename", displayName: "Old Name")
        let newApp = AppIdentity(bundleIdentifier: "com.example.rename", displayName: "New Name")
        let start = makeDate(day: 30, hour: 17, minute: 0, second: 0, calendar: calendar)

        store.recordForegroundInterval(ForegroundInterval(
            id: UUID(), app: oldApp, start: start, end: start.addingTimeInterval(10), duration: 10
        ))
        store.recordForegroundInterval(ForegroundInterval(
            id: UUID(), app: newApp, start: start.addingTimeInterval(10), end: start.addingTimeInterval(25), duration: 15
        ))
        store.recordTyping(category: .english, app: oldApp, at: start)
        store.recordTyping(category: .english, app: newApp, at: start.addingTimeInterval(1))
        store.checkpoint(at: start.addingTimeInterval(25))

        let snapshot = store.snapshot(at: start)
        XCTAssertEqual(snapshot.appUsageByApp.count, 1)
        XCTAssertEqual(snapshot.appUsageByApp[newApp] ?? 0, 25, accuracy: 0.001)
        XCTAssertEqual(snapshot.appUsageByApp.keys.first?.displayName, "New Name")
        XCTAssertEqual(snapshot.typingAppMetricsByApp.count, 1)
        XCTAssertEqual(snapshot.typingAppMetricsByApp[newApp]?.typedCharacters, 2)
        XCTAssertEqual(snapshot.typingAppMetricsByApp.keys.first?.displayName, "New Name")
    }

    func testDifferentBundleIDsWithSameDisplayNameRemainSeparate() {
        let calendar = fixedCalendar(timeZone: "UTC")
        let store = UsageStore(inMemory: true, calendarProvider: { calendar })
        let appA = AppIdentity(bundleIdentifier: "com.example.a", displayName: "Same Name")
        let appB = AppIdentity(bundleIdentifier: "com.example.b", displayName: "Same Name")
        let start = makeDate(day: 30, hour: 18, minute: 0, second: 0, calendar: calendar)

        store.recordForegroundInterval(ForegroundInterval(id: UUID(), app: appA, start: start, end: start.addingTimeInterval(4), duration: 4))
        store.recordForegroundInterval(ForegroundInterval(id: UUID(), app: appB, start: start.addingTimeInterval(4), end: start.addingTimeInterval(9), duration: 5))

        XCTAssertEqual(store.snapshot(at: start).appUsageByApp.count, 2)
        XCTAssertEqual(store.snapshot(at: start).appUsageByApp[appA] ?? 0, 4, accuracy: 0.001)
        XCTAssertEqual(store.snapshot(at: start).appUsageByApp[appB] ?? 0, 5, accuracy: 0.001)
    }

    func testUnknownProcessFallbackIsStableWithinRuntimeButDifferentAcrossRuntimes() {
        let pid: Int32 = 4242
        let firstRuntime = UUID()
        let secondRuntime = UUID()

        let first = ForegroundTracker.processScopedFallbackIdentifier(
            processIdentifier: pid,
            runtimeID: firstRuntime
        )
        let sameProcess = ForegroundTracker.processScopedFallbackIdentifier(
            processIdentifier: pid,
            runtimeID: firstRuntime
        )
        let laterRuntime = ForegroundTracker.processScopedFallbackIdentifier(
            processIdentifier: pid,
            runtimeID: secondRuntime
        )

        XCTAssertEqual(first, sameProcess)
        XCTAssertNotEqual(first, laterRuntime)
        XCTAssertTrue(first.hasPrefix("unknown-process-"))
    }

    func testWakeWhileStillLockedDoesNotStartUsageUntilUnlock() {
        let tracker = ForegroundTracker()
        let app = AppIdentity(bundleIdentifier: "com.example.afterunlock", displayName: "After Unlock")
        let start = Date(timeIntervalSinceReferenceDate: 60_000)

        tracker.handleSystemEventForTesting(.lock, at: start)
        tracker.handleSystemEventForTesting(.sleep, at: start.addingTimeInterval(5))
        tracker.handleSystemEventForTesting(.wake, at: start.addingTimeInterval(65), frontmostApp: app)

        XCTAssertEqual(tracker.systemState.rawValue, TrackingSystemState.locked.rawValue)
        XCTAssertNil(tracker.currentApp)
        XCTAssertFalse(tracker.closedIntervals.contains { $0.app == app })

        tracker.handleSystemEventForTesting(.unlock, at: start.addingTimeInterval(95), frontmostApp: app)
        XCTAssertEqual(tracker.currentApp, app)
        XCTAssertEqual(tracker.currentIntervalStart, start.addingTimeInterval(95))
    }

    func testOrdinaryWakeWhileUnlockedResumesWithFreshInterval() {
        let tracker = ForegroundTracker()
        let app = AppIdentity(bundleIdentifier: "com.example.wake", displayName: "Wake App")
        let start = Date(timeIntervalSinceReferenceDate: 61_000)

        tracker.handleSystemEventForTesting(.sleep, at: start)
        tracker.handleSystemEventForTesting(.wake, at: start.addingTimeInterval(20), frontmostApp: app)

        XCTAssertEqual(tracker.systemState.rawValue, TrackingSystemState.awake.rawValue)
        XCTAssertEqual(tracker.currentApp, app)
        XCTAssertEqual(tracker.currentIntervalStart, start.addingTimeInterval(20))
    }

    func testLoginWindowActivationNeverBecomesUsage() {
        let tracker = ForegroundTracker()
        let loginWindow = AppIdentity(bundleIdentifier: "com.apple.loginwindow", displayName: "loginwindow")
        let app = AppIdentity(bundleIdentifier: "com.example.real", displayName: "Real App")
        let start = Date(timeIntervalSinceReferenceDate: 62_000)

        tracker.handleSystemEventForTesting(.lock, at: start)
        tracker.handleSystemEventForTesting(.wake, at: start.addingTimeInterval(10), frontmostApp: loginWindow)
        tracker.handleSystemEventForTesting(.unlock, at: start.addingTimeInterval(20), frontmostApp: loginWindow)
        XCTAssertNil(tracker.currentApp)
        XCTAssertFalse(tracker.closedIntervals.contains { $0.app == loginWindow })

        tracker.handleSystemEventForTesting(.unlock, at: start.addingTimeInterval(21), frontmostApp: app)
        XCTAssertEqual(tracker.currentApp, app)
    }

    func testMetricVersionSeparatesLegacyTypingRecords() {
        let calendar = fixedCalendar(timeZone: "UTC")
        let store = UsageStore(inMemory: true, calendarProvider: { calendar })
        let app = AppIdentity(bundleIdentifier: "com.example.metric", displayName: "Metric App")
        let date = makeDate(day: 30, hour: 19, minute: 0, second: 0, calendar: calendar)

        store.seedTypingRecordForTesting(at: date, metricVersion: 0, englishCharacters: 99)
        store.seedTypingAppRecordForTesting(at: date, app: app, metricVersion: 0, englishCharacters: 99)
        store.recordTyping(category: .english, app: app, at: date)

        let snapshot = store.snapshot(at: date)
        XCTAssertEqual(snapshot.metricVersion, UsageStore.currentMetricVersion)
        XCTAssertEqual(snapshot.typingMetrics.typedCharacters, 1)
        XCTAssertEqual(snapshot.typingAppMetricsByApp[app]?.typedCharacters, 1)
    }

    func testCalendarChangeReanchorsRuntimeWithoutDuplicatingDuration() {
        var calendar = fixedCalendar(timeZone: "UTC")
        let store = UsageStore(inMemory: true, calendarProvider: { calendar })
        let app = AppIdentity(bundleIdentifier: "com.example.calendar", displayName: "Calendar App")
        let start = makeDate(day: 30, hour: 20, minute: 0, second: 0, calendar: calendar)

        store.recordForegroundInterval(ForegroundInterval(
            id: UUID(), app: app, start: start, end: start.addingTimeInterval(10), duration: 10
        ))
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        store.calendarDidChange(at: start.addingTimeInterval(10))
        store.recordForegroundInterval(ForegroundInterval(
            id: UUID(), app: app, start: start.addingTimeInterval(10), end: start.addingTimeInterval(25), duration: 15
        ))

        let snapshot = store.snapshot(at: start.addingTimeInterval(25))
        XCTAssertEqual(snapshot.appUsageByApp[app] ?? 0, 25, accuracy: 0.001)
        XCTAssertEqual(store.snapshot(at: start).appUsageByApp[app] ?? 0, 25, accuracy: 0.001)
    }

    func testCurrentSessionPauseDoesNotAddPausedWallClockAndResumeStartsFreshInterval() {
        let calendar = fixedCalendar(timeZone: "UTC")
        let store = UsageStore(inMemory: true, calendarProvider: { calendar })
        let tracker = ForegroundTracker()
        let domains = DomainTracker(foregroundTracker: tracker)
        let app = AppIdentity(bundleIdentifier: "com.example.session", displayName: "Session App")
        let start = makeDate(day: 30, hour: 20, minute: 0, second: 0, calendar: calendar)

        tracker.handleSystemEventForTesting(.lock, at: start)
        tracker.handleSystemEventForTesting(.unlock, at: start.addingTimeInterval(10), frontmostApp: app)
        XCTAssertTrue(store.checkpoint(foregroundTracker: tracker, domainTracker: domains, at: start.addingTimeInterval(20)))

        tracker.handleSystemEventForTesting(.pause, at: start.addingTimeInterval(30))
        XCTAssertEqual(tracker.systemState.rawValue, TrackingSystemState.paused.rawValue)
        XCTAssertNil(tracker.currentApp)
        XCTAssertTrue(store.checkpoint(foregroundTracker: tracker, domainTracker: domains, at: start.addingTimeInterval(300)))
        XCTAssertEqual(store.snapshot(at: start.addingTimeInterval(300)).appUsageByApp[app] ?? 0, 10, accuracy: 0.001)

        tracker.handleSystemEventForTesting(.resume, at: start.addingTimeInterval(310), frontmostApp: app)
        XCTAssertTrue(store.checkpoint(foregroundTracker: tracker, domainTracker: domains, at: start.addingTimeInterval(320)))
        XCTAssertEqual(store.snapshot(at: start.addingTimeInterval(320)).appUsageByApp[app] ?? 0, 20, accuracy: 0.001)
    }

    private func makeKeyboardEvent(
        output: String? = nil,
        keyCode: CGKeyCode = 0,
        keyDown: Bool = true
    ) -> CGEvent {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: keyDown) else {
            fatalError("Unable to create test keyboard event")
        }

        if let units = output?.utf16.map({ UniChar($0) }) {
            units.withUnsafeBufferPointer { buffer in
                event.keyboardSetUnicodeString(
                    stringLength: buffer.count,
                    unicodeString: buffer.baseAddress
                )
            }
        }
        return event
    }

    private func fixedCalendar(timeZone: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone)!
        return calendar
    }

    private func makeDate(day: Int, hour: Int, minute: Int, second: Int, calendar: Calendar) -> Date {
        makeDate(year: 2026, month: 8, day: day, hour: hour, minute: minute, second: second, calendar: calendar)
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        second: Int,
        calendar: Calendar
    ) -> Date {
        calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            second: second
        ))!
    }

    func testDomainAttributionAggregatesOnlyWhileChromeIsForeground() {
        var now = Date(timeIntervalSinceReferenceDate: 10_000)
        var chromeForeground = true
        let tracker = DomainTracker(isChromeForeground: { chromeForeground }, now: { now })

        tracker.receive(domain: "chatgpt.com")
        now.addTimeInterval(60)
        XCTAssertEqual(tracker.aggregate(for: "chatgpt.com", at: now), 60, accuracy: 0.001)

        chromeForeground = false
        tracker.foregroundChanged(to: nil, at: now)
        now.addTimeInterval(30)
        XCTAssertEqual(tracker.aggregate(for: "chatgpt.com", at: now), 60, accuracy: 0.001)
    }

    func testDomainSwitchClosesPreviousChildWithoutDoubleCountingParent() {
        var now = Date(timeIntervalSinceReferenceDate: 20_000)
        let tracker = DomainTracker(isChromeForeground: { true }, now: { now })

        tracker.receive(domain: "chatgpt.com")
        now.addTimeInterval(60)
        tracker.receive(domain: "github.com")
        now.addTimeInterval(40)

        XCTAssertEqual(tracker.aggregate(for: "chatgpt.com", at: now), 60, accuracy: 0.001)
        XCTAssertEqual(tracker.aggregate(for: "github.com", at: now), 40, accuracy: 0.001)
        XCTAssertEqual(tracker.domainIntervals.count, 1)
        XCTAssertEqual(tracker.domainIntervals[0].domain, "chatgpt.com")
    }

    func testDomainReceivedInBackgroundIsUsedWhenChromeReturns() {
        var now = Date(timeIntervalSinceReferenceDate: 30_000)
        var chromeForeground = false
        let tracker = DomainTracker(isChromeForeground: { chromeForeground }, now: { now })

        tracker.receive(domain: "docs.google.com")
        now.addTimeInterval(20)
        XCTAssertEqual(tracker.aggregate(for: "docs.google.com", at: now), 0, accuracy: 0.001)

        chromeForeground = true
        tracker.foregroundChanged(to: AppIdentity(bundleIdentifier: "com.google.Chrome", displayName: "Google Chrome"), at: now)
        now.addTimeInterval(25)
        XCTAssertEqual(tracker.aggregate(for: "docs.google.com", at: now), 25, accuracy: 0.001)
    }

    func testUnsafeDomainPayloadIsRejectedAndDoesNotChangeState() {
        let now = Date(timeIntervalSinceReferenceDate: 40_000)
        let tracker = DomainTracker(isChromeForeground: { true }, now: { now })

        tracker.receive(domain: "https://chatgpt.com/full/path")

        XCTAssertEqual(tracker.currentDomain, "—")
        XCTAssertNil(tracker.lastDomainEventAt)
        XCTAssertEqual(tracker.lastMessageStatus, "Rejected non-domain payload")
    }

    func testChromeSwitchBackResumesCachedDomain() {
        var now = Date(timeIntervalSinceReferenceDate: 50_000)
        var chromeForeground = true
        let tracker = DomainTracker(isChromeForeground: { chromeForeground }, now: { now })

        tracker.receive(domain: "chatgpt.com")
        now.addTimeInterval(10)
        chromeForeground = false
        tracker.foregroundChanged(to: nil, at: now)
        now.addTimeInterval(15)
        chromeForeground = true
        tracker.foregroundChanged(to: AppIdentity(bundleIdentifier: "com.google.Chrome", displayName: "Google Chrome"), at: now)
        now.addTimeInterval(5)

        XCTAssertEqual(tracker.aggregate(for: "chatgpt.com", at: now), 15, accuracy: 0.001)
    }

    func testDomainConnectionCloseClearsStaleDomainBeforeChromeReturns() {
        var now = Date(timeIntervalSinceReferenceDate: 51_000)
        var chromeForeground = true
        let tracker = DomainTracker(isChromeForeground: { chromeForeground }, now: { now })

        tracker.receive(domain: "chatgpt.com")
        now.addTimeInterval(10)
        tracker.connectionDidClose(at: now)
        chromeForeground = false
        tracker.foregroundChanged(to: nil, at: now)
        chromeForeground = true
        now.addTimeInterval(20)
        tracker.foregroundChanged(
            to: AppIdentity(bundleIdentifier: "com.google.Chrome", displayName: "Google Chrome"),
            at: now
        )

        XCTAssertEqual(tracker.currentDomain, "—")
        XCTAssertEqual(tracker.aggregate(for: "chatgpt.com", at: now), 10, accuracy: 0.001)
    }

    func testAppLanguageOptionsHaveStablePersistenceAndLocaleMappings() {
        XCTAssertEqual(AppLanguage.storageKey, "daytrace.language")
        XCTAssertEqual(AppLanguage.system.rawValue, "system")
        XCTAssertEqual(AppLanguage.zhHans.rawValue, "zhHans")
        XCTAssertEqual(AppLanguage.english.rawValue, "english")
        XCTAssertEqual(AppLanguage(rawValue: "zhHans"), .zhHans)
        XCTAssertEqual(AppLanguage(rawValue: "english"), .english)
        XCTAssertEqual(AppLanguage.zhHans.locale.identifier, "zh-Hans")
        XCTAssertEqual(AppLanguage.english.locale.identifier, "en")
    }

    func testMenuBarDisplayModeHasVisibleDefaultAndStableResolution() {
        XCTAssertEqual(MenuBarDisplayMode.defaultValue.rawValue, MenuBarDisplayMode.usage.rawValue)
        XCTAssertEqual(MenuBarDisplayMode.resolved(rawValue: nil).rawValue, MenuBarDisplayMode.usage.rawValue)
        XCTAssertEqual(MenuBarDisplayMode.resolved(rawValue: "unknown").rawValue, MenuBarDisplayMode.usage.rawValue)

        for mode in MenuBarDisplayMode.allCases {
            XCTAssertEqual(MenuBarDisplayMode.resolved(rawValue: mode.rawValue).rawValue, mode.rawValue)
        }
    }

    func testMenuBarPauseAndResumeUsesSharedForegroundTrackingState() {
        let tracker = ForegroundTracker()
        XCTAssertTrue(tracker.isTracking)

        tracker.pause()
        XCTAssertFalse(tracker.isTracking)
        XCTAssertEqual(tracker.systemState.rawValue, TrackingSystemState.paused.rawValue)

        tracker.resume()
        XCTAssertTrue(tracker.isTracking)
        XCTAssertEqual(tracker.systemState.rawValue, TrackingSystemState.awake.rawValue)
    }

    func testAnalyticsComparisonCalculatesSafeDeltaAndPercentage() {
        let app = AppIdentity(bundleIdentifier: "com.example.editor", displayName: "Editor")
        var current = HistoryUsageSnapshot(range: .today, startDate: Date(), endDate: Date())
        current.appUsageByApp[app] = 180
        current.typingMetrics.record(.english)
        var previous = HistoryUsageSnapshot(range: .today, startDate: Date(), endDate: Date())
        previous.appUsageByApp[app] = 120
        previous.typingMetrics.record(.english)
        let comparison = UsagePeriodComparison(current: current, previous: previous)

        XCTAssertEqual(comparison.totalUsage.absolute, 60, accuracy: 0.001)
        XCTAssertEqual(comparison.totalUsage.percentage ?? 0, 50, accuracy: 0.001)
        XCTAssertEqual(comparison.typedCharacters.absolute, 0, accuracy: 0.001)
        XCTAssertEqual(comparison.topAppChanges.first?.delta ?? 0, 60, accuracy: 0.001)
    }

    func testAnalyticsComparisonDoesNotProduceInfinitePercentageForNewData() {
        var current = HistoryUsageSnapshot(range: .today, startDate: Date(), endDate: Date())
        current.typingMetrics.record(.english)
        let previous = HistoryUsageSnapshot(range: .today, startDate: Date(), endDate: Date())
        let comparison = UsagePeriodComparison(current: current, previous: previous)

        XCTAssertTrue(comparison.typedCharacters.isNew)
        XCTAssertNil(comparison.typedCharacters.percentage)
        XCTAssertTrue(DayTraceAnalytics.safePercentage(comparison.typedCharacters) == nil)
    }

    func testAnalyticsAverageUsesIncludedDaysOnly() {
        let first = HistoryDay(date: Date(timeIntervalSinceReferenceDate: 1), totalUsage: 120)
        let second = HistoryDay(date: Date(timeIntervalSinceReferenceDate: 86_401), totalUsage: 60)
        var snapshot = HistoryUsageSnapshot(range: .last7Days, startDate: first.date, endDate: second.date)
        snapshot.dailyTotals = [first, second]

        XCTAssertEqual(DayTraceAnalytics.average(snapshot.dailyTotals.map(\.totalUsage).reduce(0, +), over: 2), 90, accuracy: 0.001)
    }

    func testLast30DaysHistoryRangeHasThirtyCalendarDays() {
        let calendar = fixedCalendar(timeZone: "UTC")
        let date = makeDate(day: 30, hour: 12, minute: 0, second: 0, calendar: calendar)
        let start = HistoryRange.last30Days.startDate(at: date, calendar: calendar)
        XCTAssertEqual(calendar.dateComponents([.day], from: start, to: date).day, 29)
    }

    func testMetadataFavoritesAndCategoriesDoNotChangeAppIdentity() {
        let suiteName = "DayTraceTests-\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        let metadata = MetadataStore(defaults: suite)
        let app = AppIdentity(bundleIdentifier: "com.example.editor", displayName: "Editor")

        metadata.toggleFavorite(app: app)
        metadata.addCategory("Development")
        metadata.setCategory("Development", for: app)

        XCTAssertTrue(metadata.isFavorite(app: app))
        XCTAssertEqual(metadata.category(for: app), "Development")
        XCTAssertEqual(app.bundleIdentifier, "com.example.editor")

        metadata.deleteCategory("Development")
        XCTAssertNil(metadata.category(for: app))
        suite.removePersistentDomain(forName: suiteName)
    }

    func testMetadataCategoryLifecycleAndRenamePreserveUsageIdentity() {
        let suiteName = "DayTraceTests-\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        let metadata = MetadataStore(defaults: suite)
        let app = AppIdentity(bundleIdentifier: "com.example.category", displayName: "Category App")

        metadata.addCategory(" Development ")
        metadata.addCategory("Development")
        XCTAssertEqual(metadata.customCategories, ["Development"])
        metadata.setCategory("Development", for: app)
        metadata.renameCategory(from: "Development", to: "Work")
        XCTAssertEqual(metadata.category(for: app), "Work")
        XCTAssertEqual(metadata.customCategories, ["Work"])
        metadata.deleteCategory("Work")
        XCTAssertTrue(metadata.customCategories.isEmpty)
        XCTAssertNil(metadata.category(for: app))
        XCTAssertEqual(app.bundleIdentifier, "com.example.category")

        suite.removePersistentDomain(forName: suiteName)
    }

    func testFavoritesPersistIndependentlyForAppsAndWebsitesIncludingMissingItems() {
        let suiteName = "DayTraceTests-\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        let app = AppIdentity(bundleIdentifier: "com.example.favorite", displayName: "Favorite App")
        let metadata = MetadataStore(defaults: suite)
        metadata.toggleFavorite(app: app)
        metadata.toggleFavorite(website: "missing.example")

        let reloaded = MetadataStore(defaults: suite)
        XCTAssertTrue(reloaded.isFavorite(app: app))
        XCTAssertTrue(reloaded.isFavorite(website: "missing.example"))
        reloaded.toggleFavorite(app: app)
        reloaded.toggleFavorite(website: "missing.example")
        XCTAssertFalse(reloaded.isFavorite(app: app))
        XCTAssertFalse(reloaded.isFavorite(website: "missing.example"))

        suite.removePersistentDomain(forName: suiteName)
    }

    func testHistorySearchIsLocalCaseInsensitiveAndWhitespaceSafe() {
        let apps = [
            AppIdentity(bundleIdentifier: "com.example.editor", displayName: "Editor"),
            AppIdentity(bundleIdentifier: "com.example.editor-alt", displayName: "Editor"),
            AppIdentity(bundleIdentifier: "com.example.chat", displayName: "Chat")
        ]
        XCTAssertEqual(HistorySearch.apps(apps, matching: "  EDIT  ").count, 2)
        XCTAssertEqual(HistorySearch.apps(apps, matching: "   ").count, 3)
        XCTAssertTrue(HistorySearch.apps(apps, matching: "missing").isEmpty)
        XCTAssertEqual(HistorySearch.domains(["ChatGPT.com", "github.com"], matching: "  chatgpt.COM"), ["ChatGPT.com"])
    }

    func testDetailPercentagesAreSafeForZeroAndFiniteForValidTotals() {
        XCTAssertNil(UsageDetailMetrics.share(of: 10, total: 0))
        XCTAssertNil(UsageDetailMetrics.share(of: 10, total: .nan))
        XCTAssertEqual(UsageDetailMetrics.share(of: 25, total: 100) ?? 0, 25, accuracy: 0.001)
        XCTAssertEqual(UsageDetailMetrics.share(of: -10, total: 100) ?? 0, 0, accuracy: 0.001)
    }

    func testAutomaticBackupPolicyRunsOncePerLocalDay() {
        let calendar = fixedCalendar(timeZone: "UTC")
        let day = makeDate(day: 30, hour: 9, minute: 0, second: 0, calendar: calendar)
        XCTAssertTrue(AutomaticBackupPolicy.shouldCreateBackup(lastBackupAt: nil, at: day, calendar: calendar))
        XCTAssertFalse(AutomaticBackupPolicy.shouldCreateBackup(lastBackupAt: day, at: day.addingTimeInterval(3600), calendar: calendar))
        XCTAssertTrue(AutomaticBackupPolicy.shouldCreateBackup(lastBackupAt: day, at: day.addingTimeInterval(86_400), calendar: calendar))
    }

    func testBackupContainsVersionedAggregateEnvelopeAndUniqueFilenames() throws {
        let calendar = fixedCalendar(timeZone: "UTC")
        let store = UsageStore(inMemory: true, calendarProvider: { calendar })
        let app = AppIdentity(bundleIdentifier: "com.example.backup", displayName: "Backup App")
        let date = makeDate(day: 30, hour: 10, minute: 0, second: 0, calendar: calendar)
        store.recordForegroundInterval(ForegroundInterval(id: UUID(), app: app, start: date, end: date.addingTimeInterval(10), duration: 10))
        XCTAssertTrue(store.checkpoint(at: date.addingTimeInterval(10)))

        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("DayTrace-backup-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let suiteName = "DayTraceTests-\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        let manager = BackupManager(defaults: suite, directoryOverride: directory, now: { date })

        let first = try XCTUnwrap(manager.createBackup(using: store))
        let second = try XCTUnwrap(manager.createBackup(using: store))
        XCTAssertNotEqual(first.lastPathComponent, second.lastPathComponent)
        XCTAssertTrue(BackupManager.isManagedBackupFilename(first.lastPathComponent))

        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: first)) as? [String: Any])
        XCTAssertEqual(object["backupVersion"] as? Int, 1)
        XCTAssertEqual(object["schemaVersion"] as? Int, 1)
        XCTAssertNotNil(object["createdAt"] as? String)
        XCTAssertNotNil(object["aggregates"] as? [String: Any])
        let encoded = String(data: try Data(contentsOf: first), encoding: .utf8) ?? ""
        XCTAssertFalse(encoded.contains("keyCode"))
        XCTAssertFalse(encoded.contains("typedText"))
        XCTAssertFalse(encoded.contains("clipboard"))
        suite.removePersistentDomain(forName: suiteName)
    }

    func testBackupLastRunPersistsAcrossManagerInstances() throws {
        let calendar = fixedCalendar(timeZone: "UTC")
        let store = UsageStore(inMemory: true, calendarProvider: { calendar })
        let app = AppIdentity(bundleIdentifier: "com.example.backup.persistence", displayName: "Backup Persistence")
        let date = makeDate(day: 30, hour: 10, minute: 0, second: 0, calendar: calendar)
        store.recordForegroundInterval(ForegroundInterval(id: UUID(), app: app, start: date, end: date.addingTimeInterval(10), duration: 10))
        XCTAssertTrue(store.checkpoint(at: date.addingTimeInterval(10)))

        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("DayTrace-backup-persistence-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let suiteName = "DayTraceTests-\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        defer { suite.removePersistentDomain(forName: suiteName) }

        let first = BackupManager(defaults: suite, directoryOverride: directory, now: { date })
        XCTAssertNil(first.lastBackupAt)
        XCTAssertNotNil(first.createBackup(using: store))

        let second = BackupManager(defaults: suite, directoryOverride: directory, now: { date.addingTimeInterval(3600) })
        XCTAssertEqual(second.lastBackupAt, date)
        XCTAssertFalse(AutomaticBackupPolicy.shouldCreateBackup(
            lastBackupAt: second.lastBackupAt,
            at: date.addingTimeInterval(3600),
            calendar: calendar
        ))
    }

    func testBackupFailureDoesNotReportSuccessOrLeaveDestination() {
        let calendar = fixedCalendar(timeZone: "UTC")
        let store = UsageStore(inMemory: true, calendarProvider: { calendar })
        let app = AppIdentity(bundleIdentifier: "com.example.backup.failure", displayName: "Backup Failure")
        let date = makeDate(day: 30, hour: 11, minute: 0, second: 0, calendar: calendar)
        store.recordForegroundInterval(ForegroundInterval(id: UUID(), app: app, start: date, end: date.addingTimeInterval(10), duration: 10))
        XCTAssertTrue(store.checkpoint(at: date.addingTimeInterval(10)))

        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("DayTrace-backup-failure-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let suiteName = "DayTraceTests-\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        let manager = BackupManager(
            defaults: suite,
            directoryOverride: directory,
            dataWriter: { _, _ in throw NSError(domain: "DayTraceTests", code: 1) }
        )

        XCTAssertNil(manager.createBackup(using: store))
        XCTAssertNil(manager.lastBackupAt)
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.path))
        let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        XCTAssertEqual(files?.filter { BackupManager.isManagedBackupFilename($0.lastPathComponent) }.count, 0)
        suite.removePersistentDomain(forName: suiteName)
    }

    func testBackupRetentionPreservesOnlyManagedFiles() throws {
        let calendar = fixedCalendar(timeZone: "UTC")
        let store = UsageStore(inMemory: true, calendarProvider: { calendar })
        let app = AppIdentity(bundleIdentifier: "com.example.backup.retention", displayName: "Retention App")
        let date = makeDate(day: 30, hour: 12, minute: 0, second: 0, calendar: calendar)
        store.recordForegroundInterval(ForegroundInterval(id: UUID(), app: app, start: date, end: date.addingTimeInterval(10), duration: 10))
        XCTAssertTrue(store.checkpoint(at: date.addingTimeInterval(10)))

        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("DayTrace-backup-retention-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let suiteName = "DayTraceTests-\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        var now = date
        let manager = BackupManager(defaults: suite, directoryOverride: directory, now: {
            defer { now = now.addingTimeInterval(1) }
            return now
        })
        manager.retention = 5
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let unrelated = directory.appendingPathComponent("DayTrace-not-a-managed-backup.json")
        try Data("user file".utf8).write(to: unrelated)

        for _ in 0..<7 { XCTAssertNotNil(manager.createBackup(using: store)) }
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        XCTAssertEqual(files.filter { BackupManager.isManagedBackupFilename($0.lastPathComponent) }.count, 5)
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelated.path))
        suite.removePersistentDomain(forName: suiteName)
    }
}
