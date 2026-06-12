import SwiftUI

struct DialogBehaviorSection: View {
    @Bindable var appSettings: AppSettings

    var body: some View {
        SettingsRoundedCard {
            VStack(alignment: .leading, spacing: 4) {
                SettingsToggleRow(
                    title: L10n.t(de: "Completion-Dialog nach Download", en: "Completion dialog after download"),
                    systemImage: "checkmark.circle",
                    isOn: $appSettings.showCompletionDialog,
                    help: L10n.t(
                        de: "Zeigt nach jedem abgeschlossenen Download ein Fenster mit Öffnen-, Finder- und Entpacken-Optionen.",
                        en: "Shows a window after each completed download with open, Finder, and extract options."
                    )
                )
                Divider().padding(.leading, 28)
                SettingsToggleRow(
                    title: L10n.t(de: "Bestätigungs-Dialog vor Start", en: "Confirmation dialog before start"),
                    systemImage: "hand.raised",
                    isOn: $appSettings.showConfirmationDialog,
                    help: L10n.t(
                        de: """
                        Fragt vor dem Start externer Downloads (Extension, Drag & Drop) nach Bestätigung. \
                        Domain-Regeln „Immer nachfragen“ gelten immer.
                        """,
                        en: """
                        Asks for confirmation before starting external downloads (extension, drag & drop). \
                        Domain rules set to \"Always ask\" always apply.
                        """
                    )
                )
                Divider().padding(.leading, 28)
                SettingsToggleRow(
                    title: L10n.t(de: "Downloads beim Beenden pausieren", en: "Pause downloads on quit"),
                    systemImage: "pause.circle",
                    isOn: $appSettings.pauseDownloadsOnQuit,
                    help: L10n.t(
                        de: "Pausiert laufende Downloads beim Beenden der App, damit der Fortschritt gespeichert und später fortgesetzt werden kann.",
                        en: "Pauses active downloads when quitting so progress is saved and can be resumed later."
                    )
                )
            }
        }
        .settingsPanelStack()
    }
}
