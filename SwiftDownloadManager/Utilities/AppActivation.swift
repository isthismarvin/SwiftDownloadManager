import AppKit

@MainActor
enum AppActivation {
    /// Brings the main app window forward (e.g. when jumping to a duplicate).
    static func bringToForeground() {
        let app = NSApplication.shared
        app.activate(ignoringOtherApps: true)
        if app.isHidden { app.unhide(nil) }

        guard let window = app.windows.first(where: { $0.canBecomeKey && !$0.isSheet }) else { return }
        if window.isMiniaturized { window.deminiaturize(nil) }
        window.makeKeyAndOrderFront(nil)
    }
}
