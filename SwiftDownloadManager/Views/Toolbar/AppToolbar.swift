import SwiftUI

struct AppToolbar: ToolbarContent {
    @Bindable var viewModel: DownloadListViewModel
    @Bindable private var appSettings = AppSettings.shared
    let downloads: [DownloadItem]

    private var canResumeAny: Bool {
        viewModel.canResumeAll
    }

    private var canPauseAny: Bool {
        viewModel.canPauseAll
    }

    private var canClearCompleted: Bool {
        downloads.contains { $0.status == .completed }
    }

    private var downloadsFolderIcon: String {
        appSettings.defaultSaveDirectoryBookmark == nil ? "folder" : "folder.fill"
    }

    private var downloadsFolderHelp: String {
        L10n.t(
            de: "Downloads-Ordner im Finder öffnen:\n\(appSettings.defaultSaveDirectoryPath)",
            en: "Open downloads folder in Finder:\n\(appSettings.defaultSaveDirectoryPath)"
        )
    }

    var body: some ToolbarContent {
        // Group 1: Logo, app name, current speed (custom glass pill)
        ToolbarItem(placement: .navigation) {
            ToolbarBrandSpeedGroup()
        }

        // Group 2: Download queue actions (native chips)
        ToolbarItemGroup(placement: .automatic) {
            toolbarButton(
                systemName: "plus",
                label: L10n.t(de: "Download hinzufügen", en: "Add Download"),
                help: L10n.t(de: "Download hinzufügen", en: "Add download")
            ) {
                viewModel.isShowingAddSheet = true
            }
        }

        ToolbarItemGroup(placement: .automatic) {
            toolbarButton(
                systemName: "play",
                label: L10n.t(de: "Alle fortsetzen", en: "Resume All"),
                help: L10n.t(de: "Alle Downloads fortsetzen", en: "Resume all downloads")
            ) {
                viewModel.startAll()
            }
            .disabled(!canResumeAny)

            toolbarButton(
                systemName: "pause",
                label: L10n.t(de: "Alle pausieren", en: "Pause All"),
                help: L10n.t(de: "Alle Downloads pausieren", en: "Pause all downloads")
            ) {
                viewModel.pauseAll()
            }
            .disabled(!canPauseAny)
        }

        ToolbarItemGroup(placement: .automatic) {
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

        // Group 3: Utilities (native chips)
        ToolbarItemGroup(placement: .primaryAction) {
            ToolbarSpeedLimitPopover()
        }

        ToolbarItemGroup(placement: .primaryAction) {
            toolbarButton(
                systemName: downloadsFolderIcon,
                label: L10n.t(de: "Downloads-Ordner", en: "Downloads Folder"),
                help: downloadsFolderHelp
            ) {
                FinderHelper.openDefaultSaveDirectory()
            }

            toolbarButton(
                systemName: "clock",
                label: L10n.t(de: "Verlauf", en: "History"),
                help: L10n.t(de: "Download-Verlauf anzeigen", en: "Show download history")
            ) {
                viewModel.isShowingHistorySheet = true
            }
        }

        ToolbarItemGroup(placement: .primaryAction) {
            toolbarButton(
                systemName: "checkmark.circle.badge.xmark",
                label: L10n.t(de: "Abgeschlossene löschen", en: "Clear Completed"),
                help: L10n.t(
                    de: "Alle abgeschlossenen Downloads aus der Liste entfernen",
                    en: "Remove all completed downloads from the list"
                )
            ) {
                viewModel.clearCompleted()
            }
            .disabled(!canClearCompleted)

            toolbarButton(
                systemName: "gearshape",
                label: L10n.t(de: "Einstellungen", en: "Settings"),
                help: L10n.t(de: "Einstellungen", en: "Settings")
            ) {
                viewModel.presentSettings()
            }
        }

        // Group 4: Search — provided by `.searchable(placement: .toolbar)` on DownloadListView
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
struct AppToolbarIcon: View {
    let systemName: String
    var foregroundStyle: AnyShapeStyle = AnyShapeStyle(.primary)

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 13))
            .symbolRenderingMode(.monochrome)
            .foregroundStyle(foregroundStyle)
            .frame(width: 20, height: 20)
            .contentShape(Rectangle())
    }
}
