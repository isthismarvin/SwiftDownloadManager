import SwiftUI

struct GeneralSettingsPanel: View {
    @Bindable private var appSettings = AppSettings.shared

    var body: some View {
        SettingsPanelContainer(L10n.t(de: "Allgemein", en: "General")) {
            VStack(alignment: .leading, spacing: 16) {
                LanguagePickerSettings(appSettings: appSettings)

                DefaultSaveDirectoryPicker(appSettings: appSettings)

                SettingsPanelSection(
                    title: L10n.t(de: "Start & Menüleiste", en: "Startup & Menu Bar"),
                    footer: L10n.t(
                        de: "Schließen des Fensters beendet die App nicht — sie läuft weiter in der Menüleiste.",
                        en: "Closing the window does not quit the app — it keeps running from the menu bar."
                    )
                ) {
                    StartupMenuBarSection(appSettings: appSettings)
                }

                SettingsPanelSection(
                    title: L10n.t(de: "Dialoge", en: "Dialogs"),
                    footer: L10n.t(
                        de: "„Immer nachfragen“-Domain-Regeln zeigen den Bestätigungs-Dialog unabhängig von dieser Einstellung.",
                        en: "Domain rules set to \"Always ask\" show the confirmation dialog regardless of this setting."
                    )
                ) {
                    DialogBehaviorSection(appSettings: appSettings)
                }
            }
            .settingsPanelStack()
        }
    }
}
