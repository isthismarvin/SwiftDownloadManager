import SwiftUI

struct DownloadsSettingsPanel: View {
    @Bindable private var appSettings = AppSettings.shared

    var body: some View {
        SettingsPanelContainer(L10n.t(de: "Downloads", en: "Downloads")) {
            VStack(alignment: .leading, spacing: 16) {
                SettingsPanelSection(title: L10n.t(de: "Warteschlange", en: "Queue")) {
                    SettingsRoundedCard {
                        VStack(alignment: .leading, spacing: 4) {
                            SettingsStepperRow(
                                label: L10n.t(de: "Parallele Downloads", en: "Parallel downloads"),
                                value: $appSettings.maxConcurrentDownloads,
                                range: 1...8,
                                help: L10n.t(
                                    de: "Wie viele Downloads gleichzeitig aktiv sein dürfen.",
                                    en: "How many downloads may run at the same time."
                                )
                            )
                            Divider()
                            SettingsToggleRow(
                                title: L10n.t(de: "Neue Downloads pausiert hinzufügen", en: "Add new downloads paused"),
                                systemImage: "pause.circle",
                                isOn: $appSettings.addNewDownloadsPaused,
                                help: L10n.t(
                                    de: "Neue Downloads werden angelegt, starten aber nicht automatisch — du startest sie manuell.",
                                    en: "New downloads are created but do not start automatically — you start them manually."
                                )
                            )
                        }
                    }
                }

                SettingsPanelSection(
                    title: L10n.t(de: "Performance", en: "Performance")
                ) {
                    SettingsRoundedCard {
                        SettingsControlRow(alignment: .firstTextBaseline) {
                            Text(L10n.t(de: "Beschleunigung", en: "Acceleration"))
                        } control: {
                            Picker(
                                L10n.t(de: "Beschleunigung", en: "Acceleration"),
                                selection: $appSettings.accelerationLevel
                            ) {
                                ForEach(AccelerationLevel.allCases, id: \.self) { level in
                                    Text(level.displayName).tag(level)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 140)
                        }
                        .help(appSettings.accelerationLevel.description)
                    }
                }

                SettingsPanelSection(
                    title: L10n.t(de: "Dateibehandlung", en: "File Handling")
                ) {
                    PostDownloadActionPicker(selection: $appSettings.defaultPostDownloadAction)
                    ConflictPolicyPicker(selection: $appSettings.conflictPolicy)
                }

                SettingsPanelSection(
                    title: L10n.t(de: "Zuverlässigkeit", en: "Reliability")
                ) {
                    SettingsRoundedCard {
                        VStack(alignment: .leading, spacing: 4) {
                            SettingsToggleRow(
                                title: L10n.t(de: "Automatische Wiederholung", en: "Auto-retry on failure"),
                                systemImage: "arrow.clockwise",
                                isOn: $appSettings.autoRetryEnabled,
                                help: L10n.t(
                                    de: "Schlägt ein Download fehl, wird er automatisch neu gestartet.",
                                    en: "If a download fails, it will be retried automatically."
                                )
                            )
                            Divider()
                            SettingsToggleRow(
                                title: L10n.t(de: "Hänger-Erkennung", en: "Stall detection"),
                                systemImage: "hourglass",
                                isOn: $appSettings.stallDetectionEnabled,
                                help: L10n.t(
                                    de: "Erkennt Downloads ohne Fortschritt und kann sie neu anstoßen.",
                                    en: "Detects downloads with no progress and can restart them."
                                )
                            )
                        }
                    }
                }
            }
            .settingsPanelStack()
        }
    }
}
