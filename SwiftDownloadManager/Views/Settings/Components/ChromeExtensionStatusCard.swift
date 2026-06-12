import SwiftUI

struct ChromeExtensionStatusCard: View {
    let onOpenExtensionFolder: () -> Void

    var body: some View {
        SettingsRoundedCard {
            VStack(alignment: .leading, spacing: AppTheme.sectionSpacing) {
                HStack(spacing: AppTheme.itemSpacing) {
                    Image(systemName: "puzzlepiece.extension.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.blue)
                        .frame(width: 32, height: 32)
                        .appGlassChip(tint: .blue.opacity(0.35))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.t(de: "Chrome Extension", en: "Chrome Extension"))
                            .font(.subheadline.weight(.semibold))
                        Text(L10n.t(
                            de: "Verbindungsstatus findest du unten in der Sidebar.",
                            en: "Connection status is shown at the bottom of the sidebar."
                        ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(AppConstants.chromeExtensionVersionLabel)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, AppTheme.compactPadding)
                        .padding(.vertical, 4)
                        .appGlassChip()
                        .help(L10n.t(
                            de: "Version der Companion Extension.",
                            en: "Companion extension version."
                        ))
                }

                Text(L10n.t(
                    de: """
                    Installiere die Extension aus dem Ordner unten in Chrome \
                    (Entwicklermodus → Entpackte Erweiterung laden). \
                    Der lokale Server lauscht auf localhost:\(LocalHTTPServer.port).
                    """,
                    en: """
                    Install the extension from the folder below in Chrome \
                    (Developer mode → Load unpacked). \
                    The local server listens on localhost:\(LocalHTTPServer.port).
                    """
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: AppTheme.contentPadding) {
                    endpointLabel(
                        "/ping",
                        help: L10n.t(
                            de: "Health-Check — die Extension prüft, ob die App läuft.",
                            en: "Health check — the extension verifies the app is running."
                        )
                    )
                    endpointLabel(
                        "/add",
                        help: L10n.t(
                            de: "Neue Downloads von der Extension an die App senden.",
                            en: "Send new downloads from the extension to the app."
                        )
                    )
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: onOpenExtensionFolder) {
                    Label(
                        L10n.t(de: "Extension-Ordner öffnen", en: "Open Extension Folder"),
                        systemImage: "folder"
                    )
                }
                .controlSize(.small)
                .help(L10n.t(
                    de: "Öffnet den ChromeExtension-Ordner im Finder zur Installation in Chrome.",
                    en: "Opens the ChromeExtension folder in Finder for installation in Chrome."
                ))
            }
        }
        .settingsPanelStack()
    }

    private func endpointLabel(_ path: String, help: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "link")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(path)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
        }
        .settingsHelp(help)
    }
}
