import SwiftUI

struct DiagnosticsPanel: View {
    let databasePath: String
    var onExport: () -> Void
    var onReset: () -> Void

    var body: some View {
        SettingsRoundedCard {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Label(L10n.t(de: "Datenbank", en: "Database"), systemImage: "externaldrive")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(databasePath)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }
                .settingsHelp(L10n.t(
                    de: "Speicherort der SwiftData-Datenbank mit Downloads, Verlauf und Ordnern.",
                    en: "Location of the SwiftData database containing downloads, history, and folders."
                ))

                Divider()

                SettingsActionButtonRow(
                    title: L10n.t(de: "Diagnose exportieren…", en: "Export diagnostics…"),
                    systemImage: "doc.text",
                    help: L10n.t(
                        de: "Speichert Systeminfos, Pfade und Einstellungen als Textdatei zur Fehlersuche.",
                        en: "Saves system info, paths, and settings as a text file for troubleshooting."
                    ),
                    action: onExport
                )

                Divider()

                Button(role: .destructive) {
                    onReset()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                            .frame(width: 18)
                        Text(L10n.t(de: "Alle Einstellungen zurücksetzen…", en: "Reset all settings…"))
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .help(L10n.t(
                    de: "Setzt alle App-Einstellungen, Domain-Regeln und Zielordner-Liste auf Standardwerte zurück.",
                    en: "Resets all app settings, domain rules, and destination folder list to defaults."
                ))
            }
        }
        .settingsPanelStack()
    }
}
