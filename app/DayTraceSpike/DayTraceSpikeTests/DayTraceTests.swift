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
        let start = makeDate(day: 30, hour: 23, minute: 59, second: 55, calendar: calendar)
        let end = makeDate(day: 31, hour: 0, minute: 0, second: 10, calendar: calendar)

        store.recordWebsiteInterval(DomainInterval(domain: "chatgpt.com", start: start, end: end, duration: 15))
        store.checkpoint(at: end)

        XCTAssertEqual(store.snapshot(at: start).websiteUsageByDomain["chatgpt.com"] ?? 0, 5, accuracy: 0.001)
        XCTAssertEqual(store.snapshot(at: end).websiteUsageByDomain["chatgpt.com"] ?? 0, 10, accuracy: 0.001)
    }

    func testWebsiteUsageDoesNotIncreaseTotalUsage() {
        let calendar = fixedCalendar(timeZone: "UTC")
        let store = UsageStore(inMemory: true, calendarProvider: { calendar })
        let start = makeDate(day: 30, hour: 12, minute: 0, second: 0, calendar: calendar)

        store.recordWebsiteInterval(DomainInterval(
            domain: "github.com", start: start, end: start.addingTimeInterval(600), duration: 600
        ))
        store.checkpoint(at: start.addingTimeInterval(600))

        XCTAssertEqual(store.snapshot(at: start).totalUsage, 0, accuracy: 0.001)
        XCTAssertEqual(store.snapshot(at: start).websiteUsageByDomain["github.com"] ?? 0, 600, accuracy: 0.001)
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

    private func makeKeyboardEvent(
        output: String? = nil,
        keyCode: CGKeyCode = 0,
        keyDown: Bool = true
    ) -> CGEvent {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: keyDown) else {
            fatalError("Unable to create test keyboard event")
        }

        if var units = output?.utf16.map({ UniChar($0) }) {
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
        calendar.date(from: DateComponents(year: 2026, month: 8, day: day, hour: hour, minute: minute, second: second))!
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
}
