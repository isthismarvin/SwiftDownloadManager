import AppKit
import SwiftUI

struct StoredShortcut: Codable, Equatable, Hashable, Sendable {
    var key: String
    var modifiers: UInt

    var keyboardShortcut: KeyboardShortcut {
        KeyboardShortcut(keyEquivalent, modifiers: eventModifiers)
    }

    var displayString: String {
        var parts: [String] = []
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
            .intersection(.deviceIndependentFlagsMask)
        if flags.contains(.control) { parts.append("⌃") }
        if flags.contains(.option) { parts.append("⌥") }
        if flags.contains(.shift) { parts.append("⇧") }
        if flags.contains(.command) { parts.append("⌘") }
        parts.append(keyDisplaySymbol)
        return parts.joined()
    }

    private var keyEquivalent: KeyEquivalent {
        switch key.lowercased() {
        case "escape": return .escape
        case "delete", "backspace": return .delete
        case "return", "enter": return .return
        case "tab": return .tab
        case "space": return .space
        case "up": return .upArrow
        case "down": return .downArrow
        case "left": return .leftArrow
        case "right": return .rightArrow
        default:
            if let first = key.first {
                return KeyEquivalent(first)
            }
            return KeyEquivalent("a")
        }
    }

    private var eventModifiers: EventModifiers {
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
            .intersection(.deviceIndependentFlagsMask)
        var result = EventModifiers()
        if flags.contains(.command) { result.insert(.command) }
        if flags.contains(.shift) { result.insert(.shift) }
        if flags.contains(.option) { result.insert(.option) }
        if flags.contains(.control) { result.insert(.control) }
        return result
    }

    private var keyDisplaySymbol: String {
        switch key.lowercased() {
        case "escape": return "Esc"
        case "delete", "backspace": return "⌫"
        case "return", "enter": return "↩"
        case "tab": return "⇥"
        case "space": return "Space"
        case "up": return "↑"
        case "down": return "↓"
        case "left": return "←"
        case "right": return "→"
        default: return key.uppercased()
        }
    }

    func satisfiesRequirements(for action: AppShortcutAction) -> Bool {
        let flags = NSEvent.ModifierFlags(rawValue: modifiers)
            .intersection(.deviceIndependentFlagsMask)
        if action == .deselectAll {
            return key.lowercased() == "escape" && flags.isEmpty
        }
        return flags.contains(.command)
    }

    static func from(event: NSEvent) -> StoredShortcut? {
        guard event.type == .keyDown else { return nil }
        guard let key = keyToken(for: event) else { return nil }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            .intersection([.command, .shift, .option, .control])
        return StoredShortcut(key: key, modifiers: flags.rawValue)
    }

    static func cmd(_ key: String) -> StoredShortcut {
        StoredShortcut(key: key, modifiers: NSEvent.ModifierFlags.command.rawValue)
    }

    static func cmdShift(_ key: String) -> StoredShortcut {
        StoredShortcut(
            key: key,
            modifiers: NSEvent.ModifierFlags([.command, .shift]).rawValue
        )
    }

    static func cmdOption(_ key: String) -> StoredShortcut {
        StoredShortcut(
            key: key,
            modifiers: NSEvent.ModifierFlags([.command, .option]).rawValue
        )
    }

    static func escapeOnly() -> StoredShortcut {
        StoredShortcut(key: "escape", modifiers: 0)
    }

    private static func keyToken(for event: NSEvent) -> String? {
        switch event.keyCode {
        case 53: return "escape"
        case 51, 117: return "delete"
        case 36: return "return"
        case 48: return "tab"
        case 49: return "space"
        case 126: return "up"
        case 125: return "down"
        case 123: return "left"
        case 124: return "right"
        default:
            break
        }

        guard let chars = event.charactersIgnoringModifiers?.lowercased(),
              let first = chars.first else { return nil }
        if first.isLetter || first.isNumber {
            return String(first)
        }
        if "-=[]\\;'`,./".contains(first) {
            return String(first)
        }
        return nil
    }
}
