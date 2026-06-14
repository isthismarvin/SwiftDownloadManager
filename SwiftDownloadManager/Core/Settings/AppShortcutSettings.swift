import AppKit
import Observation
import SwiftUI

@Observable
@MainActor
final class AppShortcutSettings {
    static let shared = AppShortcutSettings()

    private enum StorageKey {
        static let overrides = "appShortcutOverrides"
    }

    private(set) var revision = 0
    private var overrides: [String: StoredShortcut] = [:]

    private init() {
        load()
    }

    func shortcut(for action: AppShortcutAction) -> KeyboardShortcut {
        storedShortcut(for: action).keyboardShortcut
    }

    func storedShortcut(for action: AppShortcutAction) -> StoredShortcut {
        overrides[action.rawValue] ?? action.defaultShortcut
    }

    @discardableResult
    func setShortcut(_ shortcut: StoredShortcut, for action: AppShortcutAction) -> AppShortcutAction? {
        guard shortcut.satisfiesRequirements(for: action) else { return nil }
        if let conflict = conflictingAction(for: shortcut, excluding: action) {
            return conflict
        }
        overrides[action.rawValue] = shortcut
        persist()
        return nil
    }

    func reset(_ action: AppShortcutAction) {
        overrides.removeValue(forKey: action.rawValue)
        persist()
    }

    func resetAll() {
        overrides.removeAll()
        persist()
    }

    func conflictingAction(for shortcut: StoredShortcut, excluding action: AppShortcutAction) -> AppShortcutAction? {
        for candidate in AppShortcutAction.allCases where candidate != action {
            if storedShortcut(for: candidate) == shortcut {
                return candidate
            }
        }
        return nil
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: StorageKey.overrides),
              let decoded = try? JSONDecoder().decode([String: StoredShortcut].self, from: data) else {
            return
        }
        overrides = decoded
    }

    private func persist() {
        if overrides.isEmpty {
            UserDefaults.standard.removeObject(forKey: StorageKey.overrides)
        } else if let data = try? JSONEncoder().encode(overrides) {
            UserDefaults.standard.set(data, forKey: StorageKey.overrides)
        }
        revision += 1
    }
}

@MainActor
final class ShortcutCaptureSession {
    static let shared = ShortcutCaptureSession()

    private var monitor: Any?
    private var completion: ((StoredShortcut?) -> Void)?

    func start(completion: @escaping (StoredShortcut?) -> Void) {
        stop()
        self.completion = completion
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == 53 {
                self.finish(with: nil)
                return nil
            }
            if let shortcut = StoredShortcut.from(event: event) {
                self.finish(with: shortcut)
                return nil
            }
            return event
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        completion = nil
    }

    private func finish(with shortcut: StoredShortcut?) {
        let handler = completion
        stop()
        handler?(shortcut)
    }
}

extension View {
    func appShortcut(_ action: AppShortcutAction) -> some View {
        keyboardShortcut(AppShortcutSettings.shared.shortcut(for: action))
    }
}
