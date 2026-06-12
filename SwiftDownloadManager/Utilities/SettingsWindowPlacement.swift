import AppKit
import SwiftUI

@MainActor
enum SettingsWindowPlacement {
    static let defaultSize = NSSize(
        width: SettingsShared.windowIdealWidth,
        height: SettingsShared.windowIdealHeight
    )
    static let windowIdentifier = NSUserInterfaceItemIdentifier("app-settings")

    static func mainWindow() -> NSWindow? {
        NSApp.windows.first { $0.identifier?.rawValue == "main" }
            ?? NSApp.mainWindow
    }

    static func configureMainWindow() {
        guard let window = mainWindow() else { return }
        window.title = ""
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
    }

    static func settingsWindow() -> NSWindow? {
        if let tagged = NSApp.windows.first(where: { $0.identifier == windowIdentifier }) {
            return tagged
        }
        return NSApp.windows.first { isSettingsWindow($0) }
    }

    static func configureWindow() {
        guard let window = settingsWindow() else { return }
        window.identifier = windowIdentifier
        window.title = ""
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        removeSidebarToggle(from: window)
    }

    static func removeSidebarToggle(from window: NSWindow) {
        guard let toolbar = window.toolbar else { return }
        let sidebarIdentifiers: [NSToolbarItem.Identifier] = [
            .toggleSidebar,
            .sidebarTrackingSeparator,
        ]
        for identifier in sidebarIdentifiers where toolbar.items.contains(where: { $0.itemIdentifier == identifier }) {
            toolbar.removeItem(identifier: identifier)
        }
    }

    static func centerOnMainWindow() {
        guard let main = mainWindow(),
              let settings = settingsWindow(),
              settings !== main else { return }

        configureWindow()

        var frame = settings.frame
        if frame.width < 100 || frame.height < 100 {
            frame.size = defaultSize
        }

        frame.origin.x = main.frame.midX - frame.width / 2
        frame.origin.y = main.frame.midY - frame.height / 2
        settings.setFrame(frame, display: true)
    }

    private static func isSettingsWindow(_ window: NSWindow) -> Bool {
        if window === mainWindow() { return false }
        if window.isSheet || !window.isVisible { return false }
        if window.identifier == windowIdentifier { return true }

        if let id = window.identifier?.rawValue.lowercased(), id.contains("settings") {
            return true
        }

        let title = window.title.lowercased()
        if title.contains("settings") || title.contains("einstellungen") || title.contains("preferences") {
            return true
        }

        return NSStringFromClass(type(of: window)).localizedCaseInsensitiveContains("settings")
    }
}

/// Hides the system window title so only the in-app brand header is shown.
struct MainWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        apply()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        apply()
    }

    private func apply() {
        DispatchQueue.main.async {
            SettingsWindowPlacement.configureMainWindow()
        }
    }
}

/// Configures the settings window chrome and centers it on the main app window.
struct SettingsWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        apply()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        apply()
    }

    private func apply() {
        DispatchQueue.main.async {
            SettingsWindowPlacement.centerOnMainWindow()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            SettingsWindowPlacement.centerOnMainWindow()
        }
    }
}
