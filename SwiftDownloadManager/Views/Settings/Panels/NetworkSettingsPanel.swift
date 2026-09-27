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
                        VStack(alignment: .leading, spacing: 4) {
                            SettingsToggleRow(
                                title: L10n.t(de: "Nur bei WLAN/Ethernet starten", en: "Only on Wi-Fi/Ethernet"),
                                systemImage: "wifi",
                                isOn: $appSettings.defaultStartWhenOnWiFi,
                                subtitle: L10n.t(de: "Standard für neue Downloads", en: "Default for new downloads"),
                                help: L10n.t(
                                    de: "Neue Downloads warten, bis eine WLAN- oder Ethernet-Verbindung verfügbar ist.",
                                    en: "New downloads wait until a Wi-Fi or Ethernet connection is available."
                                )
                            )
                            Divider()
                            SettingsControlRow(alignment: .firstTextBaseline) {
                                Text(L10n.t(de: "Bandbreitenverteilung", en: "Bandwidth sharing"))
                            } control: {
                                Picker(
                                    L10n.t(de: "Bandbreitenverteilung", en: "Bandwidth sharing"),
                                    selection: $appSettings.bandwidthSharingMode
                                ) {
                                    ForEach(BandwidthSharingMode.allCases, id: \.self) { mode in
                                        Text(mode.displayName).tag(mode)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 140)
                            }
                            .help(appSettings.bandwidthSharingMode.description)
                        }
                    }
                }
            }
            .settingsPanelStack()
        }
    }
}
