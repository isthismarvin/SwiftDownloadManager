import AppKit

/// Keeps the app alive in the menu bar when the main window is closed.
@MainActor
final class BackgroundAppManager {
    static let shared = BackgroundAppManager()

    private(set) var isMainWindowVisible = true
    weak var cachedMainWindow: NSWindow?

    private init() {}

    func showMainWindow() {
        isMainWindowVisible = true
        applyActivationPolicy()
        if let window = mainWindow {
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
        }
        AppActivation.bringToForeground()
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
            cachedMainWindow = window
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
        if let cached = cachedMainWindow {
            return cached
        }
        let found = NSApp.windows.first { window in
            !window.isSheet && !(window is NSPanel)
        }
        if let found {
            cachedMainWindow = found
        }
        return found
    }
}

// MARK: - Window delegate

final class MainWindowDelegate: NSObject, NSWindowDelegate {
    static let shared = MainWindowDelegate()

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        Task { @MainActor in
            switch AppSettings.shared.windowCloseBehavior {
            case .hideToMenuBar:
                BackgroundAppManager.shared.hideMainWindow()
            case .minimize:
                sender.miniaturize(nil)
            case .quitIfIdle:
                if DownloadManager.shared.hasActiveDownloads {
                    BackgroundAppManager.shared.hideMainWindow()
                } else {
                    NSApp.terminate(nil)
                }
            }
        }
        return false
    }

    func windowDidDeminiaturize(_ notification: Notification) {
        Task { @MainActor in
            BackgroundAppManager.shared.noteMainWindowBecameVisible()
        }
    }
}
