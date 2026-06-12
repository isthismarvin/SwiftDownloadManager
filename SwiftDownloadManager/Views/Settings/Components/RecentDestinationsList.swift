import SwiftUI
import AppKit

struct RecentDestinationsList: View {
    @Binding var paths: [String]
    var onReset: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if paths.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(.tertiary)
                    Text(L10n.t(de: "Keine zuletzt verwendeten Ordner", en: "No recently used folders"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            } else {
                VStack(spacing: 6) {
                    ForEach(paths, id: \.self) { path in
                        destinationRow(path)
                    }
                }
            }

            Button(L10n.t(de: "Liste zurücksetzen", en: "Reset list")) {
                onReset()
            }
            .controlSize(.small)
            .disabled(paths.isEmpty)
            .help(L10n.t(
                de: "Löscht die Liste der zuletzt im Bestätigungs-Dialog gewählten Zielordner.",
                en: "Clears the list of destination folders recently chosen in the confirmation dialog."
            ))
        }
        .settingsPanelStack()
        .settingsRoundedCard()
        .settingsHelp(L10n.t(
            de: "Schnellauswahl im Bestätigungs-Dialog — bis zu 5 zuletzt verwendete Ordner.",
            en: "Quick pick in the confirmation dialog — up to 5 recently used folders."
        ))
    }

    private func destinationRow(_ path: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "folder.fill")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 18)

            Text(path)
                .font(.caption.monospaced())
                .lineLimit(1)
                .truncationMode(.middle)
                .help(path)

            Spacer()

            Button {
                let url = URL(fileURLWithPath: path, isDirectory: true)
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help(L10n.t(de: "Ordner im Finder anzeigen", en: "Show folder in Finder"))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
