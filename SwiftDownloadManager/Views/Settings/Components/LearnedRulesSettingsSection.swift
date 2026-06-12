import SwiftUI

struct LearnedRulesSettingsSection: View {
    @State private var hosts: [(host: String, record: HostLearningRecord)] = []
    @State private var extensions: [(ext: String, rule: ExtensionLearningRule)] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            hostSection
            extensionSection
        }
        .onAppear(perform: reload)
    }

    private var hostSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(
                L10n.t(de: "Gelernte Hosts", en: "Learned hosts"),
                empty: hosts.isEmpty,
                emptyText: L10n.t(
                    de: "Noch keine Ordner oder Aktionen pro Domain gespeichert.",
                    en: "No folders or actions saved per domain yet."
                ),
                clearTitle: L10n.t(de: "Host-Daten löschen", en: "Clear host data"),
                clearAction: {
                    DownloadLearningStore.clearHostRecords()
                    reload()
                },
                clearEnabled: !hosts.isEmpty
            )

            if !hosts.isEmpty {
                VStack(spacing: 6) {
                    ForEach(hosts, id: \.host) { entry in
                        hostRow(entry)
                    }
                }
            }
        }
    }

    private var extensionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(
                L10n.t(de: "Gelernte Dateitypen", en: "Learned file types"),
                empty: extensions.isEmpty,
                emptyText: L10n.t(
                    de: "Noch keine Post-Download-Aktionen pro Endung gespeichert.",
                    en: "No post-download actions saved per extension yet."
                ),
                clearTitle: L10n.t(de: "Typ-Regeln löschen", en: "Clear type rules"),
                clearAction: {
                    DownloadLearningStore.clearExtensionRules()
                    reload()
                },
                clearEnabled: !extensions.isEmpty
            )

            if !extensions.isEmpty {
                VStack(spacing: 6) {
                    ForEach(extensions, id: \.ext) { entry in
                        extensionRow(entry)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func sectionHeader(
        _ title: String,
        empty: Bool,
        emptyText: String,
        clearTitle: String,
        clearAction: @escaping () -> Void,
        clearEnabled: Bool
    ) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            if clearEnabled {
                Button(clearTitle, role: .destructive, action: clearAction)
                    .buttonStyle(.link)
                    .font(.caption)
            }
        }

        if empty {
            Text(emptyText)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private func hostRow(_ entry: (host: String, record: HostLearningRecord)) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.host)
                    .font(.callout.weight(.medium))

                if let path = entry.record.saveDirectoryPath {
                    Text(path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                HStack(spacing: 8) {
                    Text(L10n.t(
                        de: "\(entry.record.downloadCount)× heruntergeladen",
                        en: "\(entry.record.downloadCount)× downloaded"
                    ))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                    if let raw = entry.record.lastCategoryRaw,
                       let category = LibraryCategory(rawValue: raw) {
                        Text(category.displayName)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    if let raw = entry.record.lastPostDownloadActionRaw,
                       let action = PostDownloadAction(rawValue: raw),
                       action != .none {
                        Text(action.displayName)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer(minLength: 0)

            Button {
                DownloadLearningStore.removeHost(entry.host)
                reload()
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(L10n.t(de: "Eintrag entfernen", en: "Remove entry"))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        }
    }

    private func extensionRow(_ entry: (ext: String, rule: ExtensionLearningRule)) -> some View {
        HStack(spacing: 10) {
            Text(".\(entry.ext)")
                .font(.callout.weight(.medium).monospaced())

            Spacer(minLength: 0)

            if let action = PostDownloadAction(rawValue: entry.rule.postDownloadActionRaw) {
                Text(action.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                DownloadLearningStore.removeExtension(entry.ext)
                reload()
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(L10n.t(de: "Regel entfernen", en: "Remove rule"))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        }
    }

    private func reload() {
        hosts = DownloadLearningStore.allHostsSorted()
        extensions = DownloadLearningStore.allExtensionsSorted()
    }
}
