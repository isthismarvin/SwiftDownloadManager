import SwiftUI

struct IntegrationSettingsPanel: View {
    @Bindable private var appSettings = AppSettings.shared
    @State private var domainRules: [DomainRule] = []

    var body: some View {
        SettingsPanelContainer(L10n.t(de: "Integration", en: "Integration")) {
            VStack(alignment: .leading, spacing: 16) {
                SettingsPanelSection(title: L10n.t(de: "Chrome Extension", en: "Chrome Extension")) {
                    ChromeExtensionStatusCard(onOpenExtensionFolder: openExtensionFolder)
                }

                SettingsPanelSection(title: L10n.t(de: "Browser-Metadaten", en: "Browser Metadata")) {
                    SettingsRoundedCard {
                        SettingsToggleRow(
                            title: L10n.t(de: "Cookies & Referrer mitsenden", en: "Send Cookies & Referrer"),
                            systemImage: "key",
                            isOn: $appSettings.sendBrowserHeadersByDefault,
                            subtitle: L10n.t(
                                de: "Standard im Bestätigungs-Dialog",
                                en: "Default in confirmation dialog"
                            ),
                            help: L10n.t(
                                de: """
                                    Sendet Browser-Session (Cookies, Referrer) mit — \
                                    wichtig für geschützte Downloads von der Extension.
                                    """,
                                en: """
                                    Sends browser session (cookies, referrer) — \
                                    important for protected downloads from the extension.
                                    """
                            )
                        )
                    }
                }

                SettingsPanelSection(
                    title: L10n.t(de: "Domain-Regeln", en: "Domain Rules"),
                    footer: L10n.t(
                        de: """
                            Wildcard: *.example.com — längere Muster haben Vorrang vor kürzeren.
                            """,
                        en: """
                            Wildcard: *.example.com — longer patterns take precedence over shorter ones.
                            """
                    )
                ) {
                    DomainRulesSettingsSection(rules: $domainRules)
                }

                SettingsPanelSection(
                    title: L10n.t(de: "Gelernte Regeln", en: "Learned Rules"),
                    footer: L10n.t(
                        de: """
                            Automatisch gespeicherte Vorschläge aus abgeschlossenen Downloads. \
                            Erfordert „Intelligente Funktionen“ unter Intelligenz.
                            """,
                        en: """
                            Automatically saved suggestions from completed downloads. \
                            Requires \"Enable smart features\" under Intelligence.
                            """
                    )
                ) {
                    SettingsRoundedCard {
                        LearnedRulesSettingsSection()
                    }
                }
                .disabled(!appSettings.smartFeaturesEnabled)
                .opacity(appSettings.smartFeaturesEnabled ? 1 : 0.55)
            }
            .settingsPanelStack()
            .onAppear(perform: reloadRules)
        }
    }

    private func reloadRules() {
        domainRules = DomainRuleStore.allRules()
    }

    private func openExtensionFolder() {
        if let url = ChromeExtensionLocator.directoryURL() {
            NSWorkspace.shared.open(url)
        }
    }
}
