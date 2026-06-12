import SwiftUI

struct LanguagePickerSettings: View {
    @Bindable var appSettings: AppSettings

    var body: some View {
        SettingsRoundedCard {
            VStack(alignment: .leading, spacing: 10) {
                SettingsControlRow(alignment: .firstTextBaseline) {
                    Label(L10n.t(de: "Sprache", en: "Language"), systemImage: "globe")
                        .font(.subheadline.weight(.medium))
                } control: {
                    Picker(L10n.t(de: "Sprache", en: "Language"), selection: $appSettings.appLanguage) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .labelsHidden()
                }

                Text(
                    appSettings.appLanguage == .system
                        ? L10n.t(
                            de: "Verwendet die macOS-Systemsprache (\(appSettings.resolvedLanguageCode == "de" ? "Deutsch" : "Englisch")).",
                            en: "Uses the macOS system language (\(appSettings.resolvedLanguageCode == "de" ? "German" : "English"))."
                        )
                        : L10n.t(
                            de: "Die App-Oberfläche wird in der gewählten Sprache angezeigt.",
                            en: "The app interface is shown in the selected language."
                        )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .settingsPanelStack()
        .help(L10n.t(
            de: "Legt die Sprache für Menüs, Dialoge und Einstellungen fest.",
            en: "Sets the language for menus, dialogs, and settings."
        ))
    }
}
