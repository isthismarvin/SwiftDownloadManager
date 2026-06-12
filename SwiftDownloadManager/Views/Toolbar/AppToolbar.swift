import SwiftUI

struct AppToolbar: ToolbarContent {
    @Bindable var viewModel: DownloadListViewModel
    let downloads: [DownloadItem]

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            AppBrandHeader()
        }

        ToolbarItem(placement: .automatic) {
            toolbarButton(
                systemName: "plus",
                label: L10n.t(de: "Download hinzufügen", en: "Add Download"),
                help: L10n.t(de: "Download hinzufügen", en: "Add download")
            ) {
                viewModel.isShowingAddSheet = true
            }
        }

        ToolbarItem(placement: .automatic) {
            toolbarButton(
                systemName: "play",
                label: L10n.t(de: "Alle fortsetzen", en: "Resume All"),
                help: L10n.t(de: "Alle Downloads fortsetzen", en: "Resume all downloads")
            ) {
                viewModel.startAll()
            }
        }

        ToolbarItem(placement: .automatic) {
            toolbarButton(
                systemName: "pause",
                label: L10n.t(de: "Alle pausieren", en: "Pause All"),
                help: L10n.t(de: "Alle Downloads pausieren", en: "Pause all downloads")
            ) {
                viewModel.pauseAll()
            }
        }

        ToolbarItem(placement: .automatic) {
            toolbarButton(
                systemName: "trash",
                label: L10n.t(de: "Löschen", en: "Delete"),
                help: L10n.t(de: "Ausgewählten Download löschen", en: "Delete selected download")
            ) {
                viewModel.requestDeleteSelected(from: downloads)
            }
            .disabled(!viewModel.hasSelection)
        }

        ToolbarSpacer(.flexible)

        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button(L10n.t(de: "Einstellungen…", en: "Settings…")) {
                    viewModel.presentSettings()
                }

                Divider()

                Button(L10n.t(de: "Abgeschlossene löschen", en: "Clear Completed")) {
                    viewModel.clearCompleted()
                }
            } label: {
                AppToolbarIcon(systemName: "ellipsis.circle")
            }
            .help(L10n.t(de: "Weitere Optionen", en: "More options"))
            .accessibilityLabel(L10n.t(de: "Mehr", en: "More"))
        }
    }

    private func toolbarButton(
        systemName: String,
        label: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            AppToolbarIcon(systemName: systemName)
        }
        .help(help)
        .accessibilityLabel(label)
    }
}

/// Square icon bounds keep macOS unified-toolbar glass chips circular.
private struct AppToolbarIcon: View {
    let systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 13))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(.primary)
            .frame(width: 20, height: 20)
            .contentShape(Rectangle())
    }
}
