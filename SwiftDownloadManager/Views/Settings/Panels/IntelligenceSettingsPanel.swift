import SwiftUI

struct IntelligenceSettingsPanel: View {
    @Bindable private var appSettings = AppSettings.shared

    var body: some View {
        SettingsPanelContainer(L10n.t(de: "Intelligenz", en: "Intelligence")) {
            VStack(alignment: .leading, spacing: 16) {
                SettingsPanelSection(title: L10n.t(de: "Allgemein", en: "General")) {
                    SettingsRoundedCard {
                        SettingsToggleRow(
                            title: L10n.t(de: "Intelligente Funktionen aktivieren", en: "Enable smart features"),
                            systemImage: "sparkles",
                            isOn: $appSettings.smartFeaturesEnabled,
                            help: L10n.t(
                                de: "Master-Schalter für alle intelligenten Vorschläge, Filter und Automatismen.",
                                en: "Master switch for all smart suggestions, filters, and automations."
                            )
                        )
                    }
                }

                Group {
                    SettingsPanelSection(title: L10n.t(de: "Lernen & Vorschläge", en: "Learning & Suggestions")) {
                        SettingsRoundedCard {
                            VStack(alignment: .leading, spacing: 4) {
                                SettingsToggleRow(
                                    title: L10n.t(de: "Ordner pro Domain merken", en: "Remember folder per domain"),
                                    systemImage: "folder.badge.gearshape",
                                    isOn: $appSettings.rememberFolderPerHost,
                                    help: L10n.t(
                                        de: "Schlägt beim Bestätigungsdialog den zuletzt genutzten Speicherort pro Host vor.",
                                        en: "Suggests the last used save location per host in the confirmation dialog."
                                    )
                                )
                                Divider()
                                SettingsToggleRow(
                                    title: L10n.t(de: "Inhalts-Duplikate erkennen", en: "Detect content duplicates"),
                                    systemImage: "doc.on.doc.fill",
                                    isOn: $appSettings.detectContentDuplicates,
                                    help: L10n.t(
                                        de: "Warnt bei gleichem Dateinamen und gleicher Größe im selben Zielordner.",
                                        en: "Warns when filename and size match an existing completed download."
                                    )
                                )
                                Divider()
                                SettingsToggleRow(
                                    title: L10n.t(de: "Post-Download-Aktionen nach Typ", en: "Post-download actions by type"),
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

                    SettingsPanelSection(title: L10n.t(de: "Download-Engine", en: "Download Engine")) {
                        SettingsRoundedCard {
                            VStack(alignment: .leading, spacing: 4) {
                                SettingsToggleRow(
                                    title: L10n.t(de: "Faire Bandbreitenverteilung", en: "Fair bandwidth sharing"),
                                    systemImage: "gauge.with.needle",
                                    isOn: $appSettings.fairBandwidthSharing,
                                    help: L10n.t(
                                        de: "Teilt das globale Speed-Limit gleichmäßig auf aktive Downloads auf.",
                                        en: "Splits the global speed limit evenly across active downloads."
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
                                Divider()
                                SettingsStepperRow(
                                    label: L10n.t(de: "Hänger-Timeout (Sekunden)", en: "Stall timeout (seconds)"),
                                    value: $appSettings.stallTimeoutSeconds,
                                    range: 30...600,
                                    step: 30,
                                    help: L10n.t(
                                        de: "Zeit ohne Fortschritt, nach der ein Download als hängend gilt.",
                                        en: "Time without progress before a download is considered stalled."
                                    )
                                )
                                Divider()
                                SettingsToggleRow(
                                    title: L10n.t(de: "Bei Hänger automatisch neu starten", en: "Auto-retry on stall"),
                                    systemImage: "arrow.clockwise",
                                    isOn: $appSettings.stallAutoRetry,
                                    help: L10n.t(
                                        de: "Pausiert und setzt hängende Downloads automatisch fort.",
                                        en: "Pauses and automatically resumes stalled downloads."
                                    )
                                )
                            }
                        }
                    }

                    SettingsPanelSection(title: L10n.t(de: "Oberfläche & Filter", en: "UI & Filters")) {
                        SettingsRoundedCard {
                            VStack(alignment: .leading, spacing: 4) {
                                SettingsToggleRow(
                                    title: L10n.t(de: "Inspector-Einblicke", en: "Inspector insights"),
                                    systemImage: "lightbulb",
                                    isOn: $appSettings.showInspectorInsights,
                                    help: L10n.t(
                                        de: "Zeigt kontextbezogene Hinweise im Download-Inspector.",
                                        en: "Shows contextual hints in the download inspector."
                                    )
                                )
                                Divider()
                                SettingsToggleRow(
                                    title: L10n.t(de: "Smarte Sidebar-Filter", en: "Smart sidebar filters"),
                                    systemImage: "line.3.horizontal.decrease.circle",
                                    isOn: $appSettings.showSmartSidebarFilters,
                                    help: L10n.t(
                                        de: "Zeigt Filter wie „Datei fehlt“, „Heute“ und „Große Dateien“.",
                                        en: "Shows filters like File Missing, Today, and Large Files."
                                    )
                                )
                                Divider()
                                SettingsStepperRow(
                                    label: L10n.t(de: "Große Dateien ab (GB)", en: "Large files from (GB)"),
                                    value: $appSettings.largeFileThresholdGB,
                                    range: 1...50,
                                    help: L10n.t(
                                        de: "Schwellwert für den Sidebar-Filter „Große Dateien“.",
                                        en: "Threshold for the Large Files sidebar filter."
                                    )
                                )
                            }
                        }
                    }
                }
                .disabled(!appSettings.smartFeaturesEnabled)
                .opacity(appSettings.smartFeaturesEnabled ? 1 : 0.55)
            }
            .settingsPanelStack()
        }
    }
}
