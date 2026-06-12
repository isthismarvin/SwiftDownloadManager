import SwiftUI

struct DownloadsSettingsPanel: View {
    @Bindable private var appSettings = AppSettings.shared

    var body: some View {
        SettingsPanelContainer(L10n.t(de: "Downloads", en: "Downloads")) {
            VStack(alignment: .leading, spacing: 16) {
                SettingsPanelSection(title: L10n.t(de: "Warteschlange", en: "Queue")) {
                    SettingsRoundedCard {
                        SettingsStepperRow(
                            label: L10n.t(de: "Parallele Downloads", en: "Parallel downloads"),
                            value: $appSettings.maxConcurrentDownloads,
                            range: 1...8,
                            help: L10n.t(de: "Wie viele Downloads gleichzeitig aktiv sein dürfen.", en: "How many downloads may run at the same time.")
                        )
                    }
                }

                SettingsPanelSection(title: L10n.t(de: "Verbindungen", en: "Connections")) {
                    VStack(alignment: .leading, spacing: 12) {
                        SettingsRoundedCard {
                            VStack(alignment: .leading, spacing: 4) {
                                SettingsStepperRow(
                                    label: L10n.t(de: "Standard-Verbindungen", en: "Default connections"),
                                    value: $appSettings.defaultSegmentsCount,
                                    range: 1...8,
                                    help: L10n.t(
                                        de: "Fallback, wenn die Dateigröße noch unbekannt ist oder die größenbasierte Regel deaktiviert ist.",
                                        en: "Fallback when file size is not yet known or size-based rules are disabled."
                                    )
                                )
                                Divider()
                                SegmentCountBySizeSettingsSection()
                            }
                        }

                        SettingsRoundedCard {
                            SettingsToggleRow(
                                title: L10n.t(de: "Neue Downloads in Warteschlange halten", en: "Hold new downloads in queue"),
                                systemImage: "tray",
                                isOn: $appSettings.holdNewDownloadsInQueue,
                                help: L10n.t(
                                    de: "Neue Downloads werden angelegt, starten aber nicht automatisch — du startest sie manuell.",
                                    en: "New downloads are created but do not start automatically — you start them manually."
                                )
                            )
                        }

                        PostDownloadActionPicker(selection: $appSettings.defaultPostDownloadAction)
                    }
                }

                SettingsPanelSection(title: L10n.t(de: "Zieldatei", en: "Destination File")) {
                    ConflictPolicyPicker(selection: $appSettings.conflictPolicy)
                }
            }
            .settingsPanelStack()
        }
    }
}
