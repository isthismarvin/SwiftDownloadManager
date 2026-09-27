import AppKit

@MainActor
enum AppActivation {
    /// Brings the main app window forward (e.g. when jumping to a duplicate).
    static func bringToForeground() {
        let app = NSApplication.shared
        app.activate(ignoringOtherApps: true)
        if app.isHidden { app.unhide(nil) }

        let target = BackgroundAppManager.shared.cachedMainWindow
            ?? app.windows.first(where: { !$0.isSheet && !($0 is NSPanel) })
        if let window = target {
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
        }
    }
}
