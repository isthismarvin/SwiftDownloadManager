import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct AdvancedSettingsPanel: View {
    @Bindable private var appSettings = AppSettings.shared
    @State private var recentDestinations: [String] = []
    @State private var showResetConfirmation = false
    @State private var showEngineTuning = false

    private let downloadManager = DownloadManager.shared

    var body: some View {
        SettingsPanelContainer(L10n.t(de: "Erweitert", en: "Advanced")) {
            VStack(alignment: .leading, spacing: 16) {
                SettingsPanelSection(title: L10n.t(de: "Verlauf", en: "History")) {
                    SettingsRoundedCard {
                        VStack(alignment: .leading, spacing: 10) {
                            SettingsStepperRow(
                                label: L10n.t(de: "Verlauf aufbewahren", en: "Keep history for"),
                                value: $appSettings.historyRetentionDays,
                                range: 7...365,
                                step: 7,
                                unit: L10n.t(de: "Tage", en: "days"),
                                help: L10n.t(
                                    de: "Einträge im Download-Verlauf werden nach dieser Zeit automatisch gelöscht.",
                                    en: "Entries in the download history are automatically deleted after this period."
                                )
                            )
                            Divider()
                            Button(L10n.t(de: "Verlauf löschen", en: "Clear history"), role: .destructive) {
                                downloadManager.clearHistory()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .help(L10n.t(
                                de: "Löscht sofort alle Einträge im Download-Verlauf.",
                                en: "Immediately deletes all entries in the download history."
                            ))
                        }
                    }
                }

                SettingsPanelSection(title: L10n.t(de: "Zuletzt verwendete Zielordner", en: "Recently Used Destinations")) {
                    RecentDestinationsList(paths: $recentDestinations) {
                        RecentDestinationsStore.clearAll()
                        reloadRecentDestinations()
                    }
                }

                SettingsPanelSection(title: L10n.t(de: "Diagnose", en: "Diagnostics")) {
                    DiagnosticsPanel(
                        databasePath: databasePath,
                        onExport: exportDiagnostics,
                        onReset: { showResetConfirmation = true }
                    )
                }

                // MARK: - Engine Tuning (collapsible)

                DisclosureGroup(
                    isExpanded: $showEngineTuning,
                    content: {
                        VStack(alignment: .leading, spacing: 12) {
                            SettingsRoundedCard {
                                VStack(alignment: .leading, spacing: 4) {
                                    SettingsStepperRow(
                                        label: L10n.t(de: "Standard-Verbindungen", en: "Default connections"),
                                        value: $appSettings.defaultSegmentsCount,
                                        range: 1...8,
                                        help: L10n.t(
                                            de: "Verbindungen pro Download, wenn keine größenbasierte Regel greift.",
                                            en: "Connections per download when no size-based rule applies."
                                        )
                                    )
                                    Divider()
                                    SettingsStepperRow(
                                        label: L10n.t(de: "Probe-Timeout (Sekunden)", en: "Probe timeout (seconds)"),
                                        value: $appSettings.probeTimeoutSeconds,
                                        range: 5...120,
                                        step: 5,
                                        unit: "s",
                                        help: L10n.t(
                                            de: "Maximale Wartezeit beim Ermitteln von Dateigröße und Metadaten.",
                                            en: "Maximum wait time when determining file size and metadata."
                                        )
                                    )
                                    Divider()
                                    SettingsStepperRow(
                                        label: L10n.t(de: "Segment-Wiederholungen", en: "Segment retries"),
                                        value: $appSettings.segmentRetries,
                                        range: 1...10,
                                        help: L10n.t(
                                            de: "Wie oft ein fehlgeschlagenes Segment erneut versucht wird.",
                                            en: "How many times a failed segment is retried."
                                        )
                                    )
                                    if appSettings.stallDetectionEnabled {
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
                                    }
                                    Divider()
                                    SegmentCountBySizeSettingsSection()
                                }
                            }
                        }
                        .padding(.top, 8)
                    },
                    label: {
                        Label(
                            L10n.t(de: "Motor-Tuning", en: "Engine Tuning"),
                            systemImage: "engine.combustion"
                        )
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    }
                )
            }
            .settingsPanelStack()
            .onAppear(perform: reloadRecentDestinations)
            .confirmationDialog(
                L10n.t(de: "Alle Einstellungen zurücksetzen?", en: "Reset all settings?"),
                isPresented: $showResetConfirmation,
                titleVisibility: .visible
            ) {
                Button(L10n.t(de: "Zurücksetzen", en: "Reset"), role: .destructive) {
                    appSettings.resetAllSettings()
                    reloadRecentDestinations()
                }
                Button(L10n.t(de: "Abbrechen", en: "Cancel"), role: .cancel) {}
            } message: {
                Text(L10n.t(
                    de: "Domain-Regeln, Verlaufseinstellungen und Download-Optionen werden auf die Standardwerte gesetzt.",
                    en: "Domain rules, history settings, and download options will be restored to their defaults."
                ))
            }
        }
    }

    private var databasePath: String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return appSupport?.appendingPathComponent("default.store").path ?? "—"
    }

    private func reloadRecentDestinations() {
        recentDestinations = RecentDestinationsStore.all()
    }

    private func exportDiagnostics() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "SwiftDownloadManager-Diagnose.txt"
        panel.prompt = L10n.t(de: "Speichern", en: "Save")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let report = SandboxDiagnostics.exportDiagnosticReport()
        try? report.write(to: url, atomically: true, encoding: .utf8)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}
