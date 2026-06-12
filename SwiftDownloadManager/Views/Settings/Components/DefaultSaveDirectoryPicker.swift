import SwiftUI
import AppKit

struct DefaultSaveDirectoryPicker: View {
    @Bindable var appSettings: AppSettings

    var body: some View {
        SettingsRoundedCard {
            HStack(spacing: 12) {
                Image(systemName: appSettings.defaultSaveDirectoryBookmark == nil ? "folder" : "folder.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(L10n.t(de: "Standard-Zielordner", en: "Default destination folder"))
                            .font(.subheadline.weight(.medium))
                        if appSettings.defaultSaveDirectoryBookmark != nil {
                            Text(L10n.t(de: "Benutzerdefiniert", en: "Custom"))
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .appGlassChip(tint: .blue.opacity(0.35))
                                .foregroundStyle(.blue)
                                .help(L10n.t(
                                    de: "Ein eigener Ordner wurde per Sicherheits-Bookmark gewählt.",
                                    en: "A custom folder was selected via security-scoped bookmark."
                                ))
                        }
                    }

                    Text(appSettings.defaultSaveDirectoryPath)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer(minLength: 8)

                VStack(spacing: 6) {
                    Button(L10n.t(de: "Ändern…", en: "Change…")) {
                        chooseDirectory()
                    }
                    .controlSize(.small)
                    .help(L10n.t(de: "Wählt den Standardordner für neue Downloads.", en: "Selects the default folder for new downloads."))

                    if appSettings.defaultSaveDirectoryBookmark != nil {
                        Button(L10n.t(de: "Zurücksetzen", en: "Reset")) {
                            appSettings.clearDefaultSaveDirectory()
                        }
                        .controlSize(.small)
                        .help(L10n.t(de: "Verwendet wieder den System-Downloads-Ordner.", en: "Uses the system Downloads folder again."))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .settingsPanelStack()
        .settingsHelp(L10n.t(
            de: "Zielordner für neue Downloads, wenn kein anderer Ordner im Bestätigungs-Dialog gewählt wird.",
            en: "Destination folder for new downloads when no other folder is chosen in the confirmation dialog."
        ))
    }

    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = L10n.t(de: "Auswählen", en: "Choose")
        panel.message = L10n.t(de: "Standard-Zielordner für neue Downloads", en: "Default destination folder for new downloads")
        panel.directoryURL = appSettings.resolvedDefaultSaveDirectory()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        appSettings.setDefaultSaveDirectory(url)
    }
}
