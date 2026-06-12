import SwiftUI

private extension PostDownloadAction {
    var settingsIcon: String {
        switch self {
        case .none: return "minus.circle"
        case .revealInFinder: return "folder"
        case .openFile: return "arrow.up.right.square"
        case .extractArchive: return "archivebox"
        }
    }

    @MainActor
    func shortName() -> String {
        switch self {
        case .none: return L10n.t(de: "Keine", en: "None")
        case .revealInFinder: return L10n.t(de: "Finder", en: "Finder")
        case .openFile: return L10n.t(de: "Öffnen", en: "Open")
        case .extractArchive: return L10n.t(de: "Entpacken", en: "Extract")
        }
    }

    @MainActor
    func settingsHelp() -> String {
        switch self {
        case .none:
            return L10n.t(
                de: "Nach dem Download keine automatische Aktion ausführen.",
                en: "Perform no automatic action after the download."
            )
        case .revealInFinder:
            return L10n.t(
                de: "Zeigt die heruntergeladene Datei nach Abschluss im Finder.",
                en: "Shows the downloaded file in Finder after completion."
            )
        case .openFile:
            return L10n.t(
                de: "Öffnet die Datei nach dem Download mit der Standard-App.",
                en: "Opens the file with the default app after download."
            )
        case .extractArchive:
            return L10n.t(
                de: "Öffnet Archive nach dem Download zum Entpacken (z. B. ZIP).",
                en: "Opens archives after download for extraction (e.g. ZIP)."
            )
        }
    }
}

struct PostDownloadActionPicker: View {
    @Binding var selection: PostDownloadAction

    var body: some View {
        SettingsControlRow(alignment: .firstTextBaseline) {
            Text(L10n.t(de: "Nach-Download-Aktion", en: "Post-download action"))
                .font(.subheadline.weight(.medium))
                .settingsHelp(L10n.t(
                    de: "Standardaktion nach erfolgreichem Download, wenn der Completion-Dialog aus ist oder als Voreinstellung im Bestätigungs-Dialog.",
                    en: "Default action after a successful download when the completion dialog is off, or as the preset in the confirmation dialog."
                ))
        } control: {
            Picker(L10n.t(de: "Nach-Download-Aktion", en: "Post-download action"), selection: $selection) {
                ForEach(PostDownloadAction.allCases, id: \.self) { action in
                    Label(action.shortName(), systemImage: action.settingsIcon).tag(action)
                }
            }
            .labelsHidden()
        }
        .settingsRoundedCard()
    }
}
