import SwiftUI

private extension DestinationConflictPolicy {
    var settingsIcon: String {
        switch self {
        case .rename: return "doc.badge.plus"
        case .overwrite: return "arrow.triangle.2.circlepath"
        case .ask: return "questionmark.circle"
        }
    }

    @MainActor
    func subtitle() -> String {
        switch self {
        case .rename: return L10n.t(de: "Datei (1), (2)…", en: "File (1), (2)…")
        case .overwrite: return L10n.t(de: "Bestehende ersetzen", en: "Replace existing")
        case .ask: return L10n.t(de: "Später per Dialog", en: "Ask later via dialog")
        }
    }

    @MainActor
    func settingsHelp() -> String {
        switch self {
        case .rename:
            return L10n.t(
                de: "Legt eine neue Datei an, wenn der Name bereits existiert (z. B. datei (1).zip).",
                en: "Creates a new file when the name already exists (e.g. file (1).zip)."
            )
        case .overwrite:
            return L10n.t(
                de: "Überschreibt eine vorhandene Datei mit demselben Namen im Zielordner.",
                en: "Overwrites an existing file with the same name in the destination folder."
            )
        case .ask:
            return L10n.t(
                de: "Soll später pro Download gefragt werden — vorerst wird sicher umbenannt.",
                en: "Should ask per download later — for now, safely renames."
            )
        }
    }
}

struct ConflictPolicyPicker: View {
    @Binding var selection: DestinationConflictPolicy

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsControlRow(alignment: .firstTextBaseline) {
                Text(L10n.t(de: "Dateikonflikte", en: "File conflicts"))
                    .font(.subheadline.weight(.medium))
                    .settingsHelp(L10n.t(
                        de: "Verhalten, wenn im Zielordner bereits eine Datei mit demselben Namen liegt.",
                        en: "Behavior when a file with the same name already exists in the destination folder."
                    ))
            } control: {
                Picker(L10n.t(de: "Dateikonflikte", en: "File conflicts"), selection: $selection) {
                    ForEach(DestinationConflictPolicy.allCases) { policy in
                        Label(policy.displayName, systemImage: policy.settingsIcon).tag(policy)
                    }
                }
                .labelsHidden()
                .settingsHelp(selection.settingsHelp())
            }

            if selection == .ask {
                Text(L10n.t(
                    de: "„Jedes Mal fragen“ nutzt vorerst sicheres Umbenennen.",
                    en: "\"Ask every time\" currently uses safe renaming."
                ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .settingsRoundedCard()
    }
}
