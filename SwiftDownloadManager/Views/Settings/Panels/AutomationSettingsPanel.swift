import SwiftUI

struct AutomationSettingsPanel: View {
    @Bindable private var appSettings = AppSettings.shared

    private var startTimeBinding: Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = appSettings.schedulerStartHour
                components.minute = appSettings.schedulerStartMinute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newDate in
                let calendar = Calendar.current
                appSettings.schedulerStartHour = calendar.component(.hour, from: newDate)
                appSettings.schedulerStartMinute = calendar.component(.minute, from: newDate)
            }
        )
    }

    private var stopTimeBinding: Binding<Date> {
        Binding(
            get: {
                var components = DateComponents()
                components.hour = appSettings.schedulerStopHour
                components.minute = appSettings.schedulerStopMinute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newDate in
                let calendar = Calendar.current
                appSettings.schedulerStopHour = calendar.component(.hour, from: newDate)
                appSettings.schedulerStopMinute = calendar.component(.minute, from: newDate)
            }
        )
    }

    var body: some View {
        SettingsPanelContainer(L10n.t(de: "Automatisierung", en: "Automation")) {
            VStack(alignment: .leading, spacing: 16) {
                // MARK: - Suggestions
                SettingsPanelSection(
                    title: L10n.t(de: "Vorschläge", en: "Suggestions")
                ) {
                    SettingsRoundedCard {
                        VStack(alignment: .leading, spacing: 4) {
                            SettingsToggleRow(
                                title: L10n.t(de: "Ordner pro Domain merken", en: "Remember folder per domain"),
                                systemImage: "folder.badge.gearshape",
                                isOn: $appSettings.rememberFolderPerDomain,
                                help: L10n.t(
                                    de: "Schlägt beim Bestätigungsdialog den zuletzt genutzten Speicherort pro Host vor.",
                                    en: "Suggests the last used save location per host in the confirmation dialog."
                                )
                            )
                            Divider()
                            SettingsToggleRow(
                                title: L10n.t(de: "Aktionen pro Dateityp merken", en: "Remember actions per file type"),
                                systemImage: "doc.badge.gearshape",
                                isOn: $appSettings.rememberFileTypeActions,
                                help: L10n.t(
                                    de: "Schlägt beim Bestätigungsdialog die bevorzugte Nach-Download-Aktion pro Dateiendung vor.",
                                    en: "Suggests the preferred post-download action per file extension in the confirmation dialog."
                                )
                            )
                            Divider()
                            SettingsToggleRow(
                                title: L10n.t(de: "Doppelte Downloads erkennen", en: "Detect duplicate downloads"),
                                systemImage: "doc.on.doc.fill",
                                isOn: $appSettings.detectDuplicateDownloads,
                                help: L10n.t(
                                    de: "Warnt, wenn derselbe Inhalt bereits heruntergeladen wurde.",
                                    en: "Warns when the same content has already been downloaded."
                                )
                            )
                            Divider()
                            SettingsToggleRow(
                                title: L10n.t(de: "Intelligente Nach-Download-Aktionen", en: "Smart post-download actions"),
                                systemImage: "archivebox",
                                isOn: $appSettings.smartPostDownloadActions,
                                help: L10n.t(
                                    de: "Schlägt z. B. Entpacken für Archive oder Öffnen für DMG vor.",
                                    en: "Suggests e.g. extract for archives or open for DMG files."
                                )
                            )
                        }
                    }
                }

                // MARK: - Auto-Extract Archives
                SettingsPanelSection(
                    title: L10n.t(de: "Archiv-Verwaltung", en: "Archive Extraction"),
                    footer: L10n.t(
                        de: "Unterstützte Formate: ZIP, TAR, GZ, TGZ, BZ2, 7Z, RAR.",
                        en: "Supported formats: ZIP, TAR, GZ, TGZ, BZ2, 7Z, RAR."
                    )
                ) {
                    SettingsRoundedCard {
                        VStack(alignment: .leading, spacing: 8) {
                            SettingsToggleRow(
                                title: L10n.t(de: "Archive automatisch entpacken", en: "Automatically extract archives"),
                                systemImage: "archivebox.fill",
                                isOn: $appSettings.autoExtractArchives,
                                help: L10n.t(
                                    de: "Entpackt heruntergeladene Archive sofort nach Abschluss in einen Zielordner.",
                                    en: "Extracts downloaded archives into a destination folder immediately after completion."
                                )
                            )
                            if appSettings.autoExtractArchives {
                                Divider()
                                SettingsToggleRow(
                                    title: L10n.t(de: "Original in den Papierkorb legen", en: "Move original to Trash"),
                                    systemImage: "trash",
                                    isOn: $appSettings.trashArchiveAfterExtraction,
                                    help: L10n.t(
                                        de: "Verschiebt die Archivdatei nach erfolgreichem Entpacken in den Papierkorb.",
                                        en: "Moves the archive file to the Trash after successful extraction."
                                    )
                                )
                            }
                        }
                    }
                }

                // MARK: - IDM Scheduler
                SettingsPanelSection(
                    title: L10n.t(de: "Zeitplan (Scheduler)", en: "Scheduler"),
                    footer: L10n.t(
                        de: "Downloads werden nur innerhalb des konfigurierten Zeitfensters aktiv heruntergeladen.",
                        en: "Downloads will only run within the configured time window."
                    )
                ) {
                    SettingsRoundedCard {
                        VStack(alignment: .leading, spacing: 10) {
                            SettingsToggleRow(
                                title: L10n.t(de: "Zeitplan aktivieren", en: "Enable scheduler"),
                                systemImage: "clock.badge.checkmark",
                                isOn: $appSettings.schedulerEnabled,
                                help: L10n.t(
                                    de: "Hält Downloads außerhalb des Zeitfensters pausiert.",
                                    en: "Keeps downloads paused outside of the time window."
                                )
                            )

                            if appSettings.schedulerEnabled {
                                Divider()
                                HStack {
                                    DatePicker(
                                        L10n.t(de: "Startzeit:", en: "Start time:"),
                                        selection: startTimeBinding,
                                        displayedComponents: .hourAndMinute
                                    )
                                    Spacer()
                                    DatePicker(
                                        L10n.t(de: "Stoppzeit:", en: "Stop time:"),
                                        selection: stopTimeBinding,
                                        displayedComponents: .hourAndMinute
                                    )
                                }
                                .padding(.horizontal, 4)
                            }
                        }
                    }
                }

                // MARK: - On Queue Complete Action
                SettingsPanelSection(
                    title: L10n.t(de: "Nach Fertigstellung aller Downloads", en: "On Queue Completion"),
                    footer: L10n.t(
                        de: "Aktion, die ausgeführt wird, sobald alle aktiven Downloads abgeschlossen sind.",
                        en: "Action to take when all active downloads in the queue have completed."
                    )
                ) {
                    SettingsRoundedCard {
                        HStack {
                            Image(systemName: "power")
                                .foregroundStyle(.secondary)
                            Text(L10n.t(de: "Aktion:", en: "Action:"))
                            Spacer()
                            Picker("", selection: $appSettings.onQueueCompleteAction) {
                                ForEach(OnQueueCompleteAction.allCases) { action in
                                    Text(action.displayName).tag(action)
                                }
                            }
                            .frame(minWidth: 200)
                        }
                    }
                }

                // MARK: - Power & Network Behavior
                SettingsPanelSection(
                    title: L10n.t(de: "Energie & Netzwerk", en: "Power & Network"),
                    footer: L10n.t(
                        de: "Steuert, wie sich das System bei aktiven Downloads und Verbindungsabbrüchen verhält.",
                        en: "Controls system behavior during active downloads and connection losses."
                    )
                ) {
                    SettingsRoundedCard {
                        VStack(alignment: .leading, spacing: 8) {
                            SettingsToggleRow(
                                title: L10n.t(de: "Ruhezustand bei Downloads verhindern", en: "Prevent Mac sleep during downloads"),
                                systemImage: "moon.zzz.fill",
                                isOn: $appSettings.preventIdleSleepWhileDownloading,
                                help: L10n.t(
                                    de: "Hält eine macOS-Power-Assertion aktiv, damit der Mac bei großen Downloads nicht einschläft.",
                                    en: "Holds a macOS power assertion so your Mac will not sleep mid-transfer."
                                )
                            )
                            Divider()
                            SettingsToggleRow(
                                title: L10n.t(de: "Downloads bei Wiederverbindung fortsetzen", en: "Auto-resume on reconnect"),
                                systemImage: "wifi.badge.plus",
                                isOn: $appSettings.autoResumeOnNetworkRestore,
                                help: L10n.t(
                                    de: "Nimmt durch Netzwerkunterbrechungen pausierte oder fehlgeschlagene Downloads automatisch wieder auf.",
                                    en: "Automatically resumes downloads interrupted by Wi-Fi or network outages when connected."
                                )
                            )
                        }
                    }
                }

                // MARK: - Window & Lifecycle Behavior
                SettingsPanelSection(
                    title: L10n.t(de: "Fenster & Beenden", en: "Window & Quitting"),
                    footer: L10n.t(
                        de: "Verhalten des roten Schließen-Buttons und Sicherheitsabfrage beim Beenden.",
                        en: "Behavior of the red close button and quit safety prompt."
                    )
                ) {
                    SettingsRoundedCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "xmark.circle")
                                    .foregroundStyle(.secondary)
                                Text(L10n.t(de: "Schließen-Button:", en: "Close button:"))
                                Spacer()
                                Picker("", selection: $appSettings.windowCloseBehavior) {
                                    ForEach(WindowCloseBehavior.allCases) { behavior in
                                        Text(behavior.displayName).tag(behavior)
                                    }
                                }
                                .frame(minWidth: 220)
                            }
                            Divider()
                            SettingsToggleRow(
                                title: L10n.t(de: "Bestätigen vor dem Beenden mit aktiven Downloads", en: "Confirm before quit with active downloads"),
                                systemImage: "questionmark.circle",
                                isOn: $appSettings.confirmQuitWhenDownloading,
                                help: L10n.t(
                                    de: "Fragt nach, ob Downloads im Hintergrund weiterlaufen oder pausiert werden sollen.",
                                    en: "Asks whether to continue downloading in the background or pause before quitting."
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
