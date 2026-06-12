import SwiftUI

struct StartupMenuBarSection: View {
    @Bindable var appSettings: AppSettings
    @State private var loginStatusFootnote: String?

    var body: some View {
        SettingsRoundedCard {
            VStack(alignment: .leading, spacing: 4) {
                SettingsToggleRow(
                    title: L10n.t(de: "Beim Anmelden starten", en: "Launch at login"),
                    systemImage: "power",
                    isOn: $appSettings.launchAtLogin,
                    help: L10n.t(
                        de: "Startet Swift Download Manager im Hintergrund, damit die Chrome Extension und geplante Downloads verfügbar bleiben.",
                        en: "Starts Swift Download Manager in the background so the Chrome extension and scheduled downloads stay available."
                    )
                )

                if let loginStatusFootnote {
                    Text(loginStatusFootnote)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 28)
                }

                Divider().padding(.leading, 28)

                SettingsToggleRow(
                    title: L10n.t(de: "Im Hintergrund starten", en: "Start in background"),
                    systemImage: "menubar.rectangle",
                    isOn: $appSettings.startInBackground,
                    subtitle: L10n.t(de: "Kein Fenster beim Start", en: "No window on launch"),
                    help: L10n.t(
                        de: "Öffnet beim Start nur das Menüleisten-Icon — sinnvoll zusammen mit „Beim Anmelden starten“.",
                        en: "Shows only the menu bar icon on launch — useful with \"Launch at login\"."
                    )
                )

                Divider().padding(.leading, 28)

                SettingsToggleRow(
                    title: L10n.t(de: "Menüleisten-Icon anzeigen", en: "Show menu bar icon"),
                    systemImage: "arrow.down.circle",
                    isOn: $appSettings.showMenuBarIcon,
                    help: L10n.t(
                        de: "Zeigt Swift Download Manager in der macOS-Menüleiste. Empfohlen für Hintergrundbetrieb.",
                        en: "Shows Swift Download Manager in the macOS menu bar. Recommended for background operation."
                    )
                )

                Divider().padding(.leading, 28)

                SettingsToggleRow(
                    title: L10n.t(de: "Dock ausblenden bei geschlossenem Fenster", en: "Hide Dock icon when window closed"),
                    systemImage: "dock.rectangle",
                    isOn: $appSettings.hideDockWhenInBackground,
                    help: L10n.t(
                        de: "Blendet das Dock-Icon aus, wenn nur die Menüleiste aktiv ist — spart Ablenkung und hält die App im Hintergrund.",
                        en: "Hides the Dock icon when only the menu bar is active — keeps the app running quietly in the background."
                    )
                )
                .disabled(!appSettings.showMenuBarIcon)
                .opacity(appSettings.showMenuBarIcon ? 1 : 0.5)
            }
        }
        .settingsPanelStack()
        .onAppear(perform: refreshLoginStatus)
        .onChange(of: appSettings.launchAtLogin) { _, _ in
            refreshLoginStatus()
        }
    }

    private func refreshLoginStatus() {
        loginStatusFootnote = LaunchAtLoginManager.statusFootnote
    }
}
