import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let isPrimaryInstance: Bool
    lazy var model = DayTraceViewModel()
    lazy var dashboardWindowController = DashboardWindowController()
    private lazy var menuBarStatusItemController = MenuBarStatusItemController(
        model: model,
        dashboardWindowController: dashboardWindowController
    )
    private let instanceGuard: DayTraceSingleInstanceGuard

    override init() {
        DayTracePreferencesMigration.migrateIfNeeded()
        let instanceGuard = DayTraceSingleInstanceGuard()
        self.instanceGuard = instanceGuard
        self.isPrimaryInstance = instanceGuard.acquire()
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard isPrimaryInstance else {
            NSApp.terminate(nil)
            return
        }
        menuBarStatusItemController.install()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) {
        guard isPrimaryInstance else { return }
        model.terminate()
    }
}
