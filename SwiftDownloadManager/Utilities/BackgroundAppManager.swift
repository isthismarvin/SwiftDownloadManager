import AppKit

/// Keeps the app alive in the menu bar when the main window is closed.
@MainActor
final class BackgroundAppManager {
    static let shared = BackgroundAppManager()

    private(set) var isMainWindowVisible = true

    private init() {}

    func showMainWindow() {
        isMainWindowVisible = true
        AppActivation.bringToForeground()
        applyActivationPolicy()
    }

    func hideMainWindow() {
        guard let window = mainWindow else { return }
        window.orderOut(nil)
        isMainWindowVisible = false
        applyActivationPolicy()
    }

    func applyActivationPolicy() {
        let settings = AppSettings.shared
        guard settings.showMenuBarIcon, settings.hideDockWhenInBackground else {
            NSApp.setActivationPolicy(.regular)
            return
        }

        NSApp.setActivationPolicy(isMainWindowVisible ? .regular : .accessory)
    }

    func applyStartupPresentation() {
        if AppSettings.shared.startInBackground {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.hideMainWindow()
            }
        } else {
            showMainWindow()
        }
    }

    func installMainWindowDelegate(retry: Int = 0) {
        if let window = mainWindow {
            window.delegate = MainWindowDelegate.shared
            return
        }

        guard retry < 20 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.installMainWindowDelegate(retry: retry + 1)
        }
    }

    func noteMainWindowBecameVisible() {
        isMainWindowVisible = true
        applyActivationPolicy()
    }

    private var mainWindow: NSWindow? {
        NSApp.windows.first { window in
            window.canBecomeMain && !window.isSheet && !(window is NSPanel)
        }
    }
}

// MARK: - Window delegate

final class MainWindowDelegate: NSObject, NSWindowDelegate {
    static let shared = MainWindowDelegate()

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        Task { @MainActor in
            BackgroundAppManager.shared.hideMainWindow()
        }
        return false
    }

    func windowDidDeminiaturize(_ notification: Notification) {
        Task { @MainActor in
            BackgroundAppManager.shared.noteMainWindowBecameVisible()
        }
    }
}
