import SwiftUI

struct AboutAppHero: View {
    private var appVersion: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        VStack(spacing: 16) {
            SettingsRoundedCard(padding: 20) {
                VStack(spacing: 10) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 64, height: 64)

                    Text("Swift Download Manager")
                        .font(.title3.weight(.semibold))

                    Text(L10n.t(de: "Version \(appVersion)", en: "Version \(appVersion)"))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(L10n.t(
                        de: "Chrome Extension Companion \(AppConstants.chromeExtensionVersionLabel)",
                        en: "Chrome Extension Companion \(AppConstants.chromeExtensionVersionLabel)"
                    ))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
            }

            SettingsRoundedCard {
                VStack(spacing: 10) {
                    metaRow(
                        label: L10n.t(de: "Entwickler", en: "Developer"),
                        value: "Marvin"
                    )
                    Divider()
                    metaRow(
                        label: L10n.t(de: "Plattform", en: "Platform"),
                        value: "macOS"
                    )
                }
            }

            SettingsRoundedCard {
                Text(L10n.t(
                    de: "Mehrsegment-Downloads, Browser-Integration und Bestätigungsdialoge für sichere Downloads.",
                    en: "Multi-segment downloads, browser integration, and confirmation dialogs for safe downloads."
                ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func metaRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .font(.callout)
    }
}
