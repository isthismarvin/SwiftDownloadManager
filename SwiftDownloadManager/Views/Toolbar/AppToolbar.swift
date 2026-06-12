import SwiftUI

struct AppToolbar: ToolbarContent {
    @Bindable var viewModel: DownloadListViewModel
    let downloads: [DownloadItem]

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            AppBrandHeader()
        }

        ToolbarSpacer(.fixed)

        ToolbarItemGroup(placement: .automatic) {
            Button {
                viewModel.isShowingAddSheet = true
            } label: {
                Label(L10n.t(de: "Download hinzufügen", en: "Add Download"), systemImage: "plus")
                    .appToolbarLabelStyle()
            }
            .help(L10n.t(de: "Download hinzufügen", en: "Add download"))
        }

        ToolbarSpacer(.fixed)

        ToolbarItemGroup(placement: .automatic) {
            Button {
                viewModel.startAll()
            } label: {
                Label(L10n.t(de: "Alle fortsetzen", en: "Resume All"), systemImage: "play")
                    .appToolbarLabelStyle()
            }
            .help(L10n.t(de: "Alle Downloads fortsetzen", en: "Resume all downloads"))

            Button {
                viewModel.pauseAll()
            } label: {
                Label(L10n.t(de: "Alle pausieren", en: "Pause All"), systemImage: "pause")
                    .appToolbarLabelStyle()
            }
            .help(L10n.t(de: "Alle Downloads pausieren", en: "Pause all downloads"))
        }

        ToolbarSpacer(.fixed)

        ToolbarItem(placement: .automatic) {
            Button {
                viewModel.requestDeleteSelected(from: downloads)
            } label: {
                Label(L10n.t(de: "Löschen", en: "Delete"), systemImage: "trash")
                    .appToolbarLabelStyle()
            }
            .help(L10n.t(de: "Ausgewählten Download löschen", en: "Delete selected download"))
            .disabled(!viewModel.hasSelection)
        }

        ToolbarSpacer(.flexible)

        ToolbarItemGroup(placement: .primaryAction) {
            Menu {
                Button(L10n.t(de: "Einstellungen…", en: "Settings…")) {
                    viewModel.presentSettings()
                }

                Divider()

                Button(L10n.t(de: "Abgeschlossene löschen", en: "Clear Completed")) {
                    viewModel.clearCompleted()
                }
            } label: {
                Label(L10n.t(de: "Mehr", en: "More"), systemImage: "ellipsis.circle")
                    .appToolbarLabelStyle()
            }
            .help(L10n.t(de: "Weitere Optionen", en: "More options"))
        }
    }
}
