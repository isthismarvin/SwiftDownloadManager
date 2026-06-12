import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var entries: [HistoryEntry] = []
    @State private var searchText = ""

    private let downloadManager = DownloadManager.shared

    private var filteredEntries: [HistoryEntry] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return entries }
        return entries.filter {
            $0.fileName.lowercased().contains(query) ||
            $0.urlString.lowercased().contains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(L10n.t(de: "Download-Verlauf", en: "Download History"))
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                if !entries.isEmpty {
                    Button(L10n.t(de: "Verlauf löschen", en: "Clear History")) {
                        downloadManager.clearHistory()
                        reload()
                    }
                }
            }

            if entries.isEmpty {
                ContentUnavailableView(
                    L10n.t(de: "Kein Verlauf", en: "No History"),
                    systemImage: "clock",
                    description: Text(L10n.t(
                        de: "Abgeschlossene, gelöschte und abgebrochene Downloads erscheinen hier.",
                        en: "Completed, deleted, and cancelled downloads appear here."
                    ))
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredEntries.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredEntries) { entry in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.fileName)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)

                            Text(entry.urlString)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text(outcomeLabel(entry.outcome))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(outcomeColor(entry.outcome))

                            Text(entry.finishedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }

                        Button {
                            downloadManager.reDownload(from: entry)
                            dismiss()
                        } label: {
                            Image(systemName: "arrow.down.circle")
                        }
                        .buttonStyle(.plain)
                        .help(L10n.t(de: "Erneut herunterladen", en: "Re-download"))
                        .accessibilityLabel(L10n.t(de: "Erneut herunterladen", en: "Re-download"))
                    }
                    .padding(.vertical, 4)
                }
            }

            HStack {
                Spacer()
                Button(L10n.t(de: "Fertig", en: "Done")) {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(minWidth: 420, idealWidth: 560, maxWidth: 720, minHeight: 360, idealHeight: 420, maxHeight: 560)
        .searchable(
            text: $searchText,
            prompt: L10n.t(de: "Verlauf durchsuchen", en: "Search history")
        )
        .onAppear(perform: reload)
    }

    private func reload() {
        entries = downloadManager.fetchHistory()
    }

    private func outcomeLabel(_ outcome: HistoryOutcome) -> String {
        switch outcome {
        case .completed: return L10n.t(de: "Abgeschlossen", en: "Completed")
        case .deleted: return L10n.t(de: "Gelöscht", en: "Deleted")
        case .cancelled: return L10n.t(de: "Abgebrochen", en: "Cancelled")
        }
    }

    private func outcomeColor(_ outcome: HistoryOutcome) -> Color {
        switch outcome {
        case .completed: return .green
        case .deleted: return .secondary
        case .cancelled: return .orange
        }
    }
}

#Preview {
    HistoryView()
        .modelContainer(PersistenceController.preview.container)
}
