import SwiftUI
import AppKit

struct NotificationsSettingsPanel: View {
    @Bindable private var appSettings = AppSettings.shared

    var body: some View {
        SettingsPanelContainer(L10n.t(de: "Benachrichtigungen", en: "Notifications")) {
            VStack(alignment: .leading, spacing: 16) {
                SettingsPanelSection(title: L10n.t(de: "System-Benachrichtigungen", en: "System Notifications")) {
                    SettingsRoundedCard {
                        VStack(alignment: .leading, spacing: 4) {
                            SettingsToggleRow(
                                title: L10n.t(de: "Download abgeschlossen", en: "Download completed"),
                                systemImage: "checkmark.circle",
                                isOn: $appSettings.notifyOnComplete,
                                help: L10n.t(
                                    de: "macOS-Benachrichtigung, wenn ein Download erfolgreich beendet wurde.",
                                    en: "macOS notification when a download finishes successfully."
                                )
                            )
                            Divider().padding(.leading, 28)
                            SettingsToggleRow(
                                title: L10n.t(de: "Download fehlgeschlagen", en: "Download failed"),
                                systemImage: "exclamationmark.circle",
                                isOn: $appSettings.notifyOnFailed,
                                help: L10n.t(
                                    de: "macOS-Benachrichtigung bei Fehlern mit Dateiname und Fehlermeldung.",
                                    en: "macOS notification on errors with file name and error message."
                                )
                            )
                            Divider().padding(.leading, 28)
                            SettingsToggleRow(
                                title: L10n.t(de: "Download hängt", en: "Download stalled"),
                                systemImage: "hourglass",
                                isOn: $appSettings.notifyOnStall,
                                help: L10n.t(
                                    de: "Benachrichtigung, wenn ein Download zu lange keinen Fortschritt macht.",
                                    en: "Notification when a download stops making progress."
                                )
                            )
                            Divider().padding(.leading, 28)
                            SettingsToggleRow(
                                title: L10n.t(de: "Volle Warteschlange", en: "Queue backlog"),
                                systemImage: "tray.full",
                                isOn: $appSettings.notifyOnQueueBacklog,
                                help: L10n.t(
                                    de: "Hinweis, wenn viele Downloads auf Bestätigung oder Start warten.",
                                    en: "Notification when many downloads are waiting to confirm or start."
                                )
                            )
                            if appSettings.notifyOnQueueBacklog {
                                Divider().padding(.leading, 28)
                                SettingsStepperRow(
                                    label: L10n.t(de: "Schwellwert", en: "Threshold"),
                                    value: $appSettings.queueBacklogThreshold,
                                    range: 3...20,
                                    help: L10n.t(
                                        de: "Anzahl wartender Downloads, ab der eine Benachrichtigung erscheint.",
                                        en: "Number of waiting downloads before a notification is shown."
                                    )
                                )
                            }
                            Divider().padding(.leading, 28)
                            SettingsToggleRow(
                                title: L10n.t(de: "Ton abspielen", en: "Play sound"),
                                systemImage: "speaker.wave.2",
                                isOn: $appSettings.playNotificationSound,
                                help: L10n.t(
                                    de: "Spielt den Systemton bei Benachrichtigungen ab.",
                                    en: "Plays the system sound for notifications."
                                )
                            )
                        }
                    }
                }

                SettingsPanelSection(title: L10n.t(de: "Dock", en: "Dock")) {
                    SettingsRoundedCard {
                        VStack(alignment: .leading, spacing: 8) {
                            SettingsToggleRow(
                                title: L10n.t(de: "Aktive Downloads im Dock anzeigen", en: "Show active downloads in Dock"),
                                systemImage: "app.dock",
                                isOn: $appSettings.showDockBadge,
                                subtitle: L10n.t(de: "Badge & Fortschritt auf dem App-Icon", en: "Badge & progress on the app icon"),
                                help: L10n.t(
                                    de: "Zeigt Download-Informationen live auf dem macOS Dock-Icon an.",
                                    en: "Displays live download metrics directly on the macOS Dock icon."
                                )
                            )
                            if appSettings.showDockBadge {
                                Divider()
                                HStack {
                                    Image(systemName: "number.circle")
                                        .foregroundStyle(.secondary)
                                    Text(L10n.t(de: "Badge-Typ:", en: "Badge type:"))
                                    Spacer()
                                    Picker("", selection: $appSettings.dockBadgeDisplayMode) {
                                        ForEach(DockBadgeDisplayMode.allCases) { mode in
                                            Text(mode.displayName).tag(mode)
                                        }
                                    }
                                    .frame(minWidth: 200)
                                }
                                Divider()
                                SettingsToggleRow(
                                    title: L10n.t(de: "Fortschrittsbalken im Dock anzeigen", en: "Show progress bar on Dock icon"),
                                    systemImage: "chart.bar.fill",
                                    isOn: $appSettings.dockShowProgressBar,
                                    help: L10n.t(
                                        de: "Zeichnet einen abgerundeten Gesamtfortschrittsbalken unten auf das Dock-Icon.",
                                        en: "Draws a sleek overall progress bar overlay at the bottom of the Dock icon."
                                    )
                                )
                            }
                        }
                    }
                }

                SettingsPanelSection(title: L10n.t(de: "Systemeinstellungen", en: "System Settings")) {
                    SettingsRoundedCard {
                        SettingsActionButtonRow(
                            title: L10n.t(de: "Benachrichtigungen in Systemeinstellungen", en: "Notifications in System Settings"),
                            systemImage: "gearshape",
                            help: L10n.t(
                                de: "Öffnet die macOS-Systemeinstellungen für Benachrichtigungsberechtigungen.",
                                en: "Opens macOS System Settings for notification permissions."
                            ),
                            action: openSystemNotificationSettings
                        )
                    }
                }
            }
            .settingsPanelStack()
        }
    }

    private func openSystemNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }
}
