import AppKit
import Combine
import SwiftUI

@MainActor
final class DashboardWindowController {
    private var openWindowAction: (() -> Void)?

    func register(openWindow: @escaping () -> Void) {
        openWindowAction = openWindow
    }

    func openDashboard() {
        if let openWindowAction {
            openWindowAction()
        } else {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first(where: { $0.identifier?.rawValue.contains("dashboard") == true })?
                .makeKeyAndOrderFront(nil)
        }
    }
}

@MainActor
final class MenuBarStatusItemController: NSObject {
    private let model: DayTraceViewModel
    private let dashboardWindowController: DashboardWindowController
    private var statusItem: NSStatusItem?
    private var refreshTimer: Timer?
    private var modelCancellable: AnyCancellable?
    private var defaultsObserver: NSObjectProtocol?

    init(model: DayTraceViewModel, dashboardWindowController: DashboardWindowController) {
        self.model = model
        self.dashboardWindowController = dashboardWindowController
        super.init()
    }

    deinit {
        refreshTimer?.invalidate()
        if let defaultsObserver {
            NotificationCenter.default.removeObserver(defaultsObserver)
        }
    }

    func install() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.menu = makeMenu()
        item.isVisible = true
        item.button?.toolTip = "DayTrace"
        item.button?.setAccessibilityLabel("DayTrace")
        item.button?.isHidden = false
        statusItem = item
        refreshButton()

        modelCancellable = model.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in
                self?.refreshButton()
                self?.refreshMenu()
            }
        }
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshButton()
                self?.refreshMenu()
                self?.updateRefreshTimer()
            }
        }

        updateRefreshTimer()
    }

    private func updateRefreshTimer() {
        guard currentDisplayMode.requiresLiveRefresh else {
            refreshTimer?.invalidate()
            refreshTimer = nil
            return
        }

        guard refreshTimer == nil else { return }

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshButton()
            }
        }
        timer.tolerance = 0.1
        refreshTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func refreshButton() {
        guard let button = statusItem?.button else { return }
        let mode = currentDisplayMode
        let icon = NSImage(
            systemSymbolName: "clock.arrow.circlepath",
            accessibilityDescription: "DayTrace"
        )
        icon?.isTemplate = true
        button.image = icon
        button.imagePosition = .imageLeading
        button.title = title(for: mode)
        button.isHidden = false
        button.toolTip = "DayTrace"
    }

    private func refreshMenu() {
        statusItem?.menu = makeMenu()
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false

        menu.addItem(actionItem(localized("menuBar.openDashboard"), action: #selector(openDashboard)))
        menu.addItem(actionItem(
            localized(model.foregroundTracker.isTracking ? "tracking.pause" : "tracking.resume"),
            action: #selector(toggleTracking)
        ))

        let displayItem = NSMenuItem(title: localized("menuBar.display.title"), action: nil, keyEquivalent: "")
        let displayMenu = NSMenu()
        displayMenu.autoenablesItems = false
        for mode in MenuBarDisplayMode.allCases {
            let item = NSMenuItem(title: localized(mode.localizationKey), action: #selector(changeDisplayMode), keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            item.state = mode == currentDisplayMode ? .on : .off
            displayMenu.addItem(item)
        }
        displayItem.submenu = displayMenu
        menu.addItem(displayItem)

        menu.addItem(.separator())
        let typing = model.typingActivity().metrics.typedCharacters
        let typingItem = NSMenuItem(
            title: "\(localized("menuBar.typingValue"))  \(typing.formatted())",
            action: nil,
            keyEquivalent: ""
        )
        typingItem.isEnabled = false
        menu.addItem(typingItem)

        menu.addItem(actionItem(localized("menuBar.settings"), action: #selector(showSettings)))
        menu.addItem(.separator())
        menu.addItem(actionItem(localized("menuBar.quit"), action: #selector(quit)))
        return menu
    }

    private func actionItem(_ title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    private var currentDisplayMode: MenuBarDisplayMode {
        MenuBarDisplayMode.resolved(
            rawValue: UserDefaults.standard.string(forKey: MenuBarDisplayMode.storageKey)
        )
    }

    private var selectedLocale: Locale {
        (AppLanguage(rawValue: UserDefaults.standard.string(forKey: AppLanguage.storageKey) ?? AppLanguage.system.rawValue) ?? .system).locale
    }

    private func title(for mode: MenuBarDisplayMode) -> String {
        switch mode {
        case .iconOnly:
            return ""
        case .usage:
            return DayTraceDurationFormatter.string(seconds: model.totalUsage(), locale: selectedLocale)
        case .typing:
            return model.typingActivity().metrics.typedCharacters.formatted()
        case .usageAndTyping:
            return "\(DayTraceDurationFormatter.string(seconds: model.totalUsage(), locale: selectedLocale)) · \(model.typingActivity().metrics.typedCharacters)"
        }
    }

    private func localized(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), locale: selectedLocale)
    }

    @objc private func openDashboard(_ sender: Any?) {
        dashboardWindowController.openDashboard()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func toggleTracking(_ sender: Any?) {
        if model.foregroundTracker.isTracking {
            model.foregroundTracker.pause()
        } else {
            model.foregroundTracker.resume()
        }
        refreshButton()
        refreshMenu()
    }

    @objc private func changeDisplayMode(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String else { return }
        UserDefaults.standard.set(rawValue, forKey: MenuBarDisplayMode.storageKey)
        refreshButton()
        refreshMenu()
        updateRefreshTimer()
    }

    @objc private func showSettings(_ sender: Any?) {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    @objc private func quit(_ sender: Any?) {
        NSApp.terminate(nil)
    }
}

struct DashboardWindowBridge: View {
    let controller: DashboardWindowController
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                controller.register {
                    openWindow(id: "dashboard")
                }
            }
    }
}
