import SwiftUI
import SwiftData

struct DownloadListView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable private var downloadManager = DownloadManager.shared
    @Bindable private var appSettings = AppSettings.shared
    @Bindable var viewModel: DownloadListViewModel
    @Query(sort: \DownloadItem.createdAt, order: .reverse) private var downloads: [DownloadItem]
    @Query(sort: \DownloadFolder.createdAt) private var folders: [DownloadFolder]

    private var filteredDownloads: [DownloadItem] {
        viewModel.filter(downloads: downloads)
    }

    private var badgeCounts: SidebarBadgeCounts {
        viewModel.badgeCounts(from: downloads)
    }

    private var inspectorDownload: DownloadItem? {
        if let id = viewModel.selectedDownloadID,
           let selected = downloads.first(where: { $0.id == id }) {
            return selected
        }
        return filteredDownloads.first
    }

    var body: some View {
        let _ = appSettings.appLanguage
        let _ = appSettings.sortOrder
        let _ = appSettings.sortAscending
        let _ = appSettings.tableColumnOrder
        NavigationSplitView {
            SidebarView(viewModel: viewModel, badgeCounts: badgeCounts)
        } detail: {
            ZStack(alignment: .bottom) {
                DownloadTableView(
                    viewModel: viewModel,
                    downloads: filteredDownloads,
                    folders: folders,
                    hasAnyDownloads: !downloads.isEmpty
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                VStack(spacing: 10) {
                    SelectionActionBar(viewModel: viewModel, downloads: downloads)

                    if let item = inspectorDownload {
                        DownloadDetailInspector(
                            item: item,
                            isCollapsed: $appSettings.inspectorCollapsed,
                            expandedHeight: $appSettings.inspectorExpandedHeight
                        )
                        .id(item.id)
                        .frame(maxWidth: .infinity)
                    }
                }
                .animation(AppTheme.inspectorSpring, value: appSettings.inspectorCollapsed)
                .padding(.horizontal, AppTheme.contentPadding)
                .padding(.bottom, AppTheme.contentPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .allowsHitTesting(
                    inspectorDownload != nil || viewModel.hasSelectionActions(in: downloads)
                )
            }
            .animation(.snappy(duration: 0.25), value: viewModel.hasSelectionActions(in: downloads))
            .toolbar {
                AppToolbar(viewModel: viewModel, downloads: downloads)
            }
            .searchable(
                text: $viewModel.searchText,
                isPresented: $viewModel.isSearchPresented,
                placement: .toolbar,
                prompt: L10n.t(de: "Downloads suchen", en: "Search downloads")
            )
        }
        .sheet(isPresented: $viewModel.isShowingAddSheet) {
            AddDownloadView(viewModel: viewModel, folders: folders)
        }
        .sheet(isPresented: $viewModel.isShowingHistorySheet) {
            HistoryView()
        }
        .sheet(isPresented: $viewModel.isShowingSettingsSheet, onDismiss: {
            viewModel.clearSettingsPresentationState()
        }) {
            SettingsView(initialSection: viewModel.settingsInitialSection)
        }
        .onReceive(NotificationCenter.default.publisher(for: .openSettings)) { notification in
            viewModel.presentSettings(section: notification.object as? SettingsSection)
        }
        .confirmationDialog(
            deleteConfirmationTitle(for: viewModel.pendingDeletions),
            isPresented: Binding(
                get: { !viewModel.pendingDeletions.isEmpty },
                set: { if !$0 { viewModel.pendingDeletions = [] } }
            )
        ) {
            Button(deleteConfirmationButtonTitle(count: viewModel.pendingDeletions.count), role: .destructive) {
                viewModel.confirmPendingDeletion()
            }
            Button(L10n.t(de: "Abbrechen", en: "Cancel"), role: .cancel) {
                viewModel.pendingDeletions = []
            }
        } message: {
            Text(deleteConfirmationMessage(for: viewModel.pendingDeletions))
        }
        .dropDestination(for: URL.self) { urls, _ in
            viewModel.handleDroppedURLs(urls)
        }
        .onChange(of: viewModel.deleteSelectionTrigger) { _, _ in
            viewModel.requestDeleteSelected(from: downloads)
        }
        .onChange(of: filteredDownloads.map(\.id)) { _, ids in
            viewModel.pruneSelection(to: Set(ids))
        }
        .onAppear {
            downloadManager.setup(modelContext: modelContext)
        }
        .downloadDialogCoordinator(
            downloadManager: downloadManager,
            viewModel: viewModel,
            downloads: downloads,
            folders: folders
        )
        .frame(minWidth: 680, idealWidth: 900, minHeight: 520, idealHeight: 600)
        .background { MainWindowConfigurator() }
    }
}

private func deleteConfirmationTitle(for items: [DownloadItem]) -> String {
    if items.count == 1, let name = items.first?.fileName {
        return L10n.t(de: "„\(name)“ löschen?", en: "Delete \"\(name)\"?")
    }
    return L10n.t(
        de: "\(items.count) Downloads löschen?",
        en: "Delete \(items.count) downloads?"
    )
}

private func deleteConfirmationButtonTitle(count: Int) -> String {
    if count == 1 {
        return L10n.t(de: "Download löschen", en: "Delete Download")
    }
    return L10n.t(de: "\(count) Downloads löschen", en: "Delete \(count) Downloads")
}

private func deleteConfirmationMessage(for items: [DownloadItem]) -> String {
    let activeCount = items.filter { $0.status == .downloading || $0.status == .queued }.count
    if activeCount == 0 {
        if items.count == 1 {
            return L10n.t(
                de: "Dieser Download wird aus der Liste entfernt.",
                en: "This download will be removed from the list."
            )
        }
        return L10n.t(
            de: "Diese Downloads werden aus der Liste entfernt.",
            en: "These downloads will be removed from the list."
        )
    }
    if items.count == 1 {
        return L10n.t(
            de: "Dieser Download läuft noch. Beim Löschen gehen alle bereits heruntergeladenen Daten verloren.",
            en: "This download is still in progress. Deleting it discards all downloaded data."
        )
    }
    if activeCount == items.count {
        return L10n.t(
            de: "Diese Downloads laufen noch. Beim Löschen gehen alle bereits heruntergeladenen Daten verloren.",
            en: "These downloads are still in progress. Deleting them discards all downloaded data."
        )
    }
    return L10n.t(
        de: "\(activeCount) der ausgewählten Downloads laufen noch. Beim Löschen gehen alle bereits heruntergeladenen Daten verloren.",
        en: "\(activeCount) of the selected downloads are still in progress. Deleting them discards all downloaded data."
    )
}

#Preview {
    DownloadListView(viewModel: DownloadListViewModel())
        .modelContainer(PersistenceController.preview.container)
}
