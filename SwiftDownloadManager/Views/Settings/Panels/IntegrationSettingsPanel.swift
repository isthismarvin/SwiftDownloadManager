import SwiftUI

struct IntegrationSettingsPanel: View {
    @Bindable private var appSettings = AppSettings.shared
    @State private var domainRules: [DomainRule] = []

    var body: some View {
        SettingsPanelContainer(L10n.t(de: "Integration", en: "Integration")) {
            VStack(alignment: .leading, spacing: 16) {
                SettingsPanelSection(title: L10n.t(de: "Browser-Integration", en: "Browser Integration")) {
                    SettingsRoundedCard {
                        VStack(alignment: .leading, spacing: 6) {
                            browserRow(browser: "Safari", iconName: "safari", isOn: $appSettings.safariEnabled)
                            Divider()
                            browserRow(browser: "Chrome", iconName: "globe", isOn: $appSettings.chromeEnabled)
                            Divider()
                            browserRow(browser: "Firefox", iconName: "flame", isOn: $appSettings.firefoxEnabled)
                            Divider()
                            browserRow(browser: "Edge", iconName: "arrow.triangle.branch", isOn: $appSettings.edgeEnabled)
                        }
                    }
                }

                SettingsPanelSection(title: L10n.t(de: "Erfassung", en: "Capture")) {
                    SettingsRoundedCard {
                        VStack(alignment: .leading, spacing: 4) {
                            SettingsToggleRow(
                                title: L10n.t(de: "Cookies & Referrer mitsenden", en: "Send Cookies & Referrer"),
                                systemImage: "key",
                                isOn: $appSettings.sendBrowserHeadersByDefault,
                                subtitle: L10n.t(de: "Standard im Bestätigungs-Dialog", en: "Default in confirmation dialog"),
                                help: L10n.t(
                                    de: "Sendet Browser-Session (Cookies, Referrer) mit — wichtig für geschützte Downloads.",
                                    en: "Sends browser session (cookies, referrer) — important for protected downloads."
                                )
                            )
                            Divider()
                            SettingsToggleRow(
                                title: L10n.t(de: "Zwischenablage überwachen", en: "Monitor clipboard"),
                                systemImage: "clipboard",
                                isOn: $appSettings.clipboardMonitoringEnabled,
                                help: L10n.t(
                                    de: "Erkennt kopierte URLs und schlägt einen Download vor.",
                                    en: "Detects copied URLs and suggests adding a download."
                                )
                            )
                        }
                    }
                }

                SettingsPanelSection(
                    title: L10n.t(de: "Domain-Regeln", en: "Domain Rules"),
                    footer: L10n.t(
                        de: "Wildcard: *.example.com — längere Muster haben Vorrang vor kürzeren.",
                        en: "Wildcard: *.example.com — longer patterns take precedence over shorter ones."
                    )
                ) {
                    DomainRulesSettingsSection(rules: $domainRules)
                }

                SettingsPanelSection(
                    title: L10n.t(de: "Gelernte Regeln", en: "Learned Rules"),
                    footer: L10n.t(
                        de: "Automatisch gespeicherte Vorschläge aus abgeschlossenen Downloads.",
                        en: "Automatically saved suggestions from completed downloads."
                    )
                ) {
                    SettingsRoundedCard {
                        LearnedRulesSettingsSection()
                    }
                }
            }
            .settingsPanelStack()
            .onAppear(perform: reloadRules)
        }
    }

    private func reloadRules() {
        domainRules = DomainRuleStore.allRules()
    }

    private func browserRow(browser: String, iconName: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(browser)
                .font(.callout)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .padding(.vertical, 2)
    }
}
