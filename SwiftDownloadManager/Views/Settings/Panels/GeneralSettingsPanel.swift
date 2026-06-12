import SwiftUI

struct GeneralSettingsPanel: View {
    @Bindable private var appSettings = AppSettings.shared

    var body: some View {
        SettingsPanelContainer(L10n.t(de: "Allgemein", en: "General")) {
            VStack(alignment: .leading, spacing: 16) {
                LanguagePickerSettings(appSettings: appSettings)

                DefaultSaveDirectoryPicker(appSettings: appSettings)

                SettingsPanelSection(title: L10n.t(de: "Download-Liste", en: "Download List")) {
                    SettingsRoundedCard {
                        VStack(alignment: .leading, spacing: 12) {
                            SettingsControlRow(alignment: .firstTextBaseline) {
                                Text(L10n.t(de: "Sortierung", en: "Sort By"))
                            } control: {
                                Picker(L10n.t(de: "Sortierung", en: "Sort By"), selection: $appSettings.sortOrder) {
                                    ForEach(DownloadSortOrder.allCases) { order in
                                        Text(order.displayName).tag(order)
                                    }
                                }
                                .labelsHidden()
                            }
                            .help(L10n.t(
                                de: "Standard-Sortierung der Download-Tabelle. Spaltenköpfe sortieren per Klick.",
                                en: "Default sort order for the download table. Click column headers to sort."
                            ))

                            Divider()

                            SettingsControlRow(alignment: .firstTextBaseline) {
                                Text(L10n.t(de: "Sortierrichtung", en: "Sort direction"))
                            } control: {
                                Picker(L10n.t(de: "Sortierrichtung", en: "Sort direction"), selection: $appSettings.sortAscending) {
                                    Text(L10n.t(de: "Absteigend", en: "Descending")).tag(false)
                                    Text(L10n.t(de: "Aufsteigend", en: "Ascending")).tag(true)
                                }
                                .labelsHidden()
                                .pickerStyle(.segmented)
                                .frame(maxWidth: 220)
                            }
                            .help(L10n.t(
                                de: "Richtung für die aktuelle Sortierung. Spaltenköpfe schalten die Richtung beim Klick um.",
                                en: "Direction for the current sort. Column headers toggle direction when clicked."
                            ))

                            Divider()

                            TableColumnOrderSettingsSection()
                        }
                    }
                }

                SettingsPanelSection(
                    title: L10n.t(de: "Start & Menüleiste", en: "Startup & Menu Bar"),
                    footer: L10n.t(
                        de: "Schließen des Fensters beendet die App nicht — sie läuft weiter in der Menüleiste weiter.",
                        en: "Closing the window does not quit the app — it keeps running from the menu bar."
                    )
                ) {
                    StartupMenuBarSection(appSettings: appSettings)
                }

                SettingsPanelSection(
                    title: L10n.t(de: "Dialoge & Beenden", en: "Dialogs & Quit"),
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
