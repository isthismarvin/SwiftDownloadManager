import SwiftUI

struct HotkeysSettingsPanel: View {
    @Bindable private var shortcutSettings = AppShortcutSettings.shared
    @State private var recordingAction: AppShortcutAction?
    @State private var conflictMessage: String?

    var body: some View {
        let _ = shortcutSettings.revision

        SettingsPanelContainer(L10n.t(de: "Tastenkürzel", en: "Hotkeys")) {
            VStack(alignment: .leading, spacing: 16) {
                SettingsPanelSection(
                    title: L10n.t(de: "Menü-Shortcuts", en: "Menu Shortcuts"),
                    footer: L10n.t(
                        de: "Klicke auf ein Tastenkürzel und drücke die neue Kombination. Esc bricht die Aufnahme ab. ⌘ ist für die meisten Aktionen erforderlich.",
                        en: "Click a shortcut and press the new key combination. Esc cancels recording. ⌘ is required for most actions."
                    )
                ) {
                    SettingsRoundedCard {
                        VStack(spacing: 0) {
                            ForEach(AppShortcutCategory.allCases) { category in
                                if category != AppShortcutCategory.allCases.first {
                                    Divider()
                                        .padding(.vertical, 10)
                                }

                                Text(category.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.bottom, 6)

                                ForEach(category.actions) { action in
                                    HotkeySettingsRow(
                                        action: action,
                                        isRecording: recordingAction == action,
                                        onBeginRecording: {
                                            conflictMessage = nil
                                            recordingAction = action
                                            ShortcutCaptureSession.shared.start { shortcut in
                                                recordingAction = nil
                                                guard let shortcut else { return }
                                                applyCapturedShortcut(shortcut, for: action)
                                            }
                                        },
                                        onReset: {
                                            conflictMessage = nil
                                            shortcutSettings.reset(action)
                                        }
                                    )

                                    if action != category.actions.last {
                                        Divider()
                                            .padding(.vertical, 8)
                                    }
                                }
                            }
                        }
                    }
                }

                if let conflictMessage {
                    Text(conflictMessage)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                HStack {
                    Spacer()
                    Button(L10n.t(de: "Alle zurücksetzen", en: "Reset All")) {
                        conflictMessage = nil
                        recordingAction = nil
                        ShortcutCaptureSession.shared.stop()
                        shortcutSettings.resetAll()
                    }
                }
            }
            .settingsPanelStack()
        }
        .onDisappear {
            recordingAction = nil
            ShortcutCaptureSession.shared.stop()
        }
    }

    private func applyCapturedShortcut(_ shortcut: StoredShortcut, for action: AppShortcutAction) {
        guard shortcut.satisfiesRequirements(for: action) else {
            conflictMessage = L10n.t(
                de: "„\(action.title)“ benötigt ⌘ (Esc ist nur für „Auswahl aufheben“ ohne Modifier erlaubt).",
                en: "\"\(action.title)\" requires ⌘ (Esc is only allowed without modifiers for \"Deselect All\")."
            )
            return
        }

        if let conflict = shortcutSettings.setShortcut(shortcut, for: action) {
            conflictMessage = L10n.t(
                de: "Konflikt mit „\(conflict.title)“ (\(shortcut.displayString)).",
                en: "Conflicts with \"\(conflict.title)\" (\(shortcut.displayString))."
            )
        } else {
            conflictMessage = nil
        }
    }
}

private struct HotkeySettingsRow: View {
    let action: AppShortcutAction
    let isRecording: Bool
    let onBeginRecording: () -> Void
    let onReset: () -> Void

    @Bindable private var shortcutSettings = AppShortcutSettings.shared

    var body: some View {
        SettingsControlRow {
            Text(action.title)
                .font(.callout)
        } control: {
            HStack(spacing: 8) {
                Button {
                    onBeginRecording()
                } label: {
                    Text(labelText)
                        .font(.system(.callout, design: .monospaced))
                        .frame(minWidth: 96)
                }
                .buttonStyle(.bordered)
                .tint(isRecording ? .accentColor : nil)

                Button(action: onReset) {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
                .help(L10n.t(de: "Standard wiederherstellen", en: "Restore default"))
                .disabled(shortcutSettings.storedShortcut(for: action) == action.defaultShortcut)
            }
        }
    }

    private var labelText: String {
        if isRecording {
            return L10n.t(de: "Taste drücken…", en: "Press keys…")
        }
        return shortcutSettings.storedShortcut(for: action).displayString
    }
}
