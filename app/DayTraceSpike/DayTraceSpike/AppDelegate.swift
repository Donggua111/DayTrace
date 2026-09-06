import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model: DayTraceViewModel
    let dashboardWindowController: DashboardWindowController
    private let menuBarStatusItemController: MenuBarStatusItemController

    override init() {
        model = DayTraceViewModel()
        dashboardWindowController = DashboardWindowController()
        menuBarStatusItemController = MenuBarStatusItemController(
            model: model,
            dashboardWindowController: dashboardWindowController
        )
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarStatusItemController.install()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
