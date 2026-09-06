import AppKit
import Combine
import Foundation

@MainActor
final class DomainTracker: ObservableObject {
    @Published private(set) var currentDomain: String = "—"
    @Published private(set) var domainIntervals: [DomainInterval] = []
    @Published private(set) var domainAggregateByDomain: [String: TimeInterval] = [:]
    @Published private(set) var lastDomainEventAt: Date?
    @Published private(set) var lastMessageStatus = "Waiting for Chrome domain"

    private weak var foregroundTracker: ForegroundTracker?
    private let chromeForegroundProvider: () -> Bool
    private let nowProvider: () -> Date
    private var cachedDomain: String?
    private var activeDomain: String?
    private var activeStart: Date?

    init(foregroundTracker: ForegroundTracker, now: @escaping () -> Date = Date.init) {
        self.foregroundTracker = foregroundTracker
        self.chromeForegroundProvider = { [weak foregroundTracker] in
            foregroundTracker?.currentApp?.bundleIdentifier == "com.google.Chrome"
        }
        self.nowProvider = now
    }

    init(isChromeForeground: @escaping () -> Bool, now: @escaping () -> Date = Date.init) {
        self.chromeForegroundProvider = isChromeForeground
        self.nowProvider = now
    }

    func receive(domain: String) {
        guard Self.isSafeDomainToken(domain) else {
            invalidateCurrentDomain()
            lastMessageStatus = "Rejected non-domain payload"
            return
        }
        cachedDomain = domain
        let date = nowProvider()
        lastDomainEventAt = date
        lastMessageStatus = "Received sanitized domain"
        guard isChromeForeground else {
            currentDomain = "—"
            return
        }
        currentDomain = domain
        switchDomain(to: domain, at: date)
    }

    func foregroundChanged(to app: AppIdentity?, at date: Date) {
        guard app?.bundleIdentifier == "com.google.Chrome" else {
            closeActiveDomain(at: date)
            currentDomain = "—"
            return
        }
        guard let cachedDomain else {
            currentDomain = "—"
            return
        }
        currentDomain = cachedDomain
        switchDomain(to: cachedDomain, at: date)
    }

    /// Clears the current attribution when the extension/native-host channel
    /// is gone. The next Chrome signal must establish a new domain interval;
    /// an old domain is never resumed from stale connection state.
    func connectionDidClose(at date: Date? = nil) {
        closeActiveDomain(at: date ?? nowProvider())
        cachedDomain = nil
        currentDomain = "—"
        lastMessageStatus = "Waiting for Chrome domain"
    }

    func resetRuntimeState(at date: Date = Date()) {
        let domain = isChromeForeground ? activeDomain ?? cachedDomain : nil
        activeDomain = nil
        activeStart = nil
        domainIntervals.removeAll()
        domainAggregateByDomain.removeAll()
        currentDomain = domain ?? "—"
        if let domain {
            activeDomain = domain
            activeStart = date
        }
    }

    func aggregate(for domain: String, at date: Date = Date()) -> TimeInterval {
        let closed = domainAggregateByDomain[domain, default: 0]
        let active = activeDomain == domain ? max(0, date.timeIntervalSince(activeStart ?? date)) : 0
        return closed + active
    }

    func activeIntervalSnapshot(at date: Date = Date()) -> DomainInterval? {
        guard let activeDomain, let activeStart else { return nil }
        return DomainInterval(
            domain: activeDomain,
            start: activeStart,
            end: date,
            duration: max(0, date.timeIntervalSince(activeStart))
        )
    }

    private var isChromeForeground: Bool {
        chromeForegroundProvider()
    }

    private func switchDomain(to domain: String, at date: Date) {
        guard activeDomain != domain else { return }
        closeActiveDomain(at: date)
        activeDomain = domain
        activeStart = date
    }

    private func closeActiveDomain(at date: Date) {
        guard let domain = activeDomain, let start = activeStart else {
            activeDomain = nil
            activeStart = nil
            return
        }
        let duration = max(0, date.timeIntervalSince(start))
        domainIntervals.append(DomainInterval(domain: domain, start: start, end: date, duration: duration))
        domainAggregateByDomain[domain, default: 0] += duration
        activeDomain = nil
        activeStart = nil
    }

    private func invalidateCurrentDomain() {
        closeActiveDomain(at: nowProvider())
        cachedDomain = nil
        currentDomain = "—"
    }

    private static func isSafeDomainToken(_ value: String) -> Bool {
        if ["Browser Internal", "Local File", "Unknown"].contains(value) { return true }
        guard value.count <= 253, !value.contains("/"), !value.contains(":"), !value.contains("?") else { return false }
        return value.split(separator: ".").allSatisfy { label in
            !label.isEmpty && label.count <= 63 && label.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" }
        }
    }
}
