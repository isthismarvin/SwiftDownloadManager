import SwiftUI

struct NetworkSettingsPanel: View {
    @Bindable private var appSettings = AppSettings.shared

    var body: some View {
        SettingsPanelContainer(L10n.t(de: "Netzwerk", en: "Network")) {
            VStack(alignment: .leading, spacing: 16) {
                SettingsPanelSection(title: L10n.t(de: "Geschwindigkeit", en: "Speed")) {
                    SpeedLimitControl(appSettings: appSettings)
                }

                SettingsPanelSection(title: L10n.t(de: "Verbindung", en: "Connection")) {
                    SettingsRoundedCard {
                        SettingsToggleRow(
                            title: L10n.t(de: "Downloads nur bei WLAN starten", en: "Start downloads on Wi-Fi only"),
                            systemImage: "wifi",
                            isOn: $appSettings.defaultStartWhenOnWiFi,
                            subtitle: L10n.t(de: "Standard für neue Downloads", en: "Default for new downloads"),
                            help: L10n.t(
                                de: "Neue Downloads warten, bis eine WLAN-Verbindung verfügbar ist. Mobilfunk-Daten werden vermieden.",
                                en: "New downloads wait until a Wi-Fi connection is available. Cellular data is avoided."
                            )
                        )
                    }
                }

                SettingsPanelSection(title: L10n.t(de: "Sicherheit", en: "Security")) {
                    SettingsRoundedCard {
                        HStack(spacing: 10) {
                            Image(systemName: "lock.open")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.t(de: "HTTP (Klartext)", en: "HTTP (Plaintext)"))
                                    .font(.callout.weight(.medium))
                                Text(L10n.t(de: "Über App Transport Security erlaubt", en: "Allowed via App Transport Security"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(L10n.t(de: "Erlaubt", en: "Allowed"))
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .appGlassChip(tint: .orange.opacity(0.35))
                                .foregroundStyle(.orange)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .settingsHelp(L10n.t(
                            de: "HTTP-Downloads ohne Verschlüsselung sind erlaubt — nötig für viele ältere oder lokale URLs.",
                            en: "Unencrypted HTTP downloads are allowed — required for many older or local URLs."
                        ))
                    }
                }

                SettingsPanelSection(title: L10n.t(de: "Erweitert", en: "Advanced")) {
                    SettingsRoundedCard {
                        VStack(alignment: .leading, spacing: 4) {
                            SettingsStepperRow(
                                label: L10n.t(de: "Probe-Timeout", en: "Probe timeout"),
                                value: $appSettings.probeTimeoutSeconds,
                                range: 5...120,
                                step: 5,
                                unit: "s",
                                help: L10n.t(
                                    de: "Maximale Wartezeit beim Ermitteln von Dateigröße und Metadaten vor dem Download.",
                                    en: "Maximum wait time when determining file size and metadata before the download."
                                )
                            )
                            Divider()
                            SettingsStepperRow(
                                label: L10n.t(de: "Segment-Wiederholungen", en: "Segment retries"),
                                value: $appSettings.segmentRetries,
                                range: 1...10,
                                help: L10n.t(
                                    de: "Wie oft ein fehlgeschlagenes Segment erneut versucht wird, bevor der Download abbricht.",
                                    en: "How many times a failed segment is retried before the download is aborted."
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
