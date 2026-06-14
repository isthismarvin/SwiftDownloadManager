import Foundation
import Observation
import SwiftUI

enum SidebarSelection: Hashable, Identifiable {
    case allDownloads
    case queue
    case scheduled
    case downloading
    case paused
    case completed
    case failed
    case missingFile
    case today
    case largeFiles
    case allFiles
    case library(LibraryCategory)
    case customFolder(UUID)

    var id: String {
        switch self {
        case .allDownloads: return "all"
        case .queue: return "queue"
        case .scheduled: return "scheduled"
        case .downloading: return "downloading"
        case .paused: return "paused"
        case .completed: return "completed"
        case .failed: return "failed"
        case .missingFile: return "missing-file"
        case .today: return "today"
        case .largeFiles: return "large-files"
        case .allFiles: return "all-files"
        case .library(let category): return "library-\(category.rawValue)"
        case .customFolder(let id): return "folder-\(id.uuidString)"
        }
    }

    var displayName: String {
        switch self {
        case .allDownloads: return L10n.t(de: "Alle Downloads", en: "All Downloads")
        case .queue: return L10n.t(de: "Warteschlange", en: "Queue")
        case .scheduled: return L10n.t(de: "Geplant", en: "Scheduled")
        case .downloading: return L10n.t(de: "Laufend", en: "Downloading")
        case .paused: return L10n.t(de: "Pausiert", en: "Paused")
        case .completed: return L10n.t(de: "Abgeschlossen", en: "Completed")
        case .failed: return L10n.t(de: "Fehlgeschlagen", en: "Failed")
        case .missingFile: return L10n.t(de: "Datei fehlt", en: "File Missing")
        case .today: return L10n.t(de: "Heute", en: "Today")
        case .largeFiles: return L10n.t(de: "Große Dateien", en: "Large Files")
        case .allFiles: return L10n.t(de: "Alle Dateien", en: "All Files")
        case .library(let category): return category.displayName
        case .customFolder: return ""
        }
    }

    var icon: String {
        DownloadStatusAppearance.sidebarIcon(for: self)
    }

    var iconColor: Color {
        DownloadStatusAppearance.sidebarColor(for: self)
    }

    static var downloadFilters: [SidebarSelection] {
        [.allDownloads, .queue, .scheduled, .downloading, .paused, .completed, .failed]
    }

    static var smartFilters: [SidebarSelection] {
        [.missingFile, .today, .largeFiles]
    }

    static var folderFilters: [SidebarSelection] {
        [.allFiles] + LibraryCategory.allCases.map { .library($0) }
    }
}

struct SidebarBadgeCounts {
    var all: Int = 0
    var queue: Int = 0
    var scheduled: Int = 0
    var downloading: Int = 0
    var paused: Int = 0
    var completed: Int = 0
    var failed: Int = 0
    var missingFile: Int = 0
    var today: Int = 0
    var largeFiles: Int = 0
    var library: [LibraryCategory: Int] = [:]
    var customFolders: [UUID: Int] = [:]

    func count(for selection: SidebarSelection) -> Int? {
        switch selection {
        case .allDownloads: return all
        case .queue: return queue
        case .scheduled: return scheduled
        case .downloading: return downloading
        case .paused: return paused
        case .completed: return completed
        case .failed: return failed
        case .missingFile: return missingFile
        case .today: return today
        case .largeFiles: return largeFiles
        case .allFiles: return all
        case .library(let category): return library[category]
        case .customFolder(let id): return customFolders[id]
        }
    }
}

@Observable
@MainActor
final class DownloadListViewModel {
    var isShowingAddSheet = false
    var isShowingHistorySheet = false
    var isShowingSettingsSheet = false
    var settingsInitialSection: SettingsSection?
    var isShowingNewFolderAlert = false
    var newFolderName = ""
    var addError: String?
    var searchText = ""
    var isSearchPresented = false
    /// Incremented by menu shortcuts; `DownloadListView` reacts and deletes the current selection.
    private(set) var deleteSelectionTrigger = 0
    var selectedSidebarItem: SidebarSelection = .allDownloads
    var selectedDownloadIDs = Set<UUID>()
    private(set) var selectionAnchorID: UUID?
    /// Downloads awaiting delete confirmation (toolbar delete).
    var pendingDeletions: [DownloadItem] = []

    var hasSelection: Bool { !selectedDownloadIDs.isEmpty }

    /// Primary selection for inspector and single-item actions.
    var selectedDownloadID: UUID? {
        get { selectionAnchorID ?? selectedDownloadIDs.first }
        set {
            if let id = newValue {
                selectedDownloadIDs = [id]
                selectionAnchorID = id
            } else {
                selectedDownloadIDs.removeAll()
                selectionAnchorID = nil
            }
        }
    }
    /// Download awaiting user confirmation before entering the queue.
    var pendingConfirmation: DownloadItem?
    /// Batch of downloads awaiting confirmation together.
    var pendingConfirmationBatch: [DownloadItem]?
    /// Duplicate of the active confirmation item, if any.
    var pendingConfirmationDuplicate: DownloadItem?
    /// Completed download shown in the completion dialog.
    var pendingCompletion: DownloadItem?

    private let downloadManager = DownloadManager.shared

    func presentSettings(section: SettingsSection? = nil) {
        if let section {
            settingsInitialSection = section
            if isShowingSettingsSheet {
                NotificationCenter.default.post(name: .openSettingsSection, object: section)
            }
        }
        isShowingSettingsSheet = true
    }

    func clearSettingsPresentationState() {
        settingsInitialSection = nil
    }

    func badgeCounts(from downloads: [DownloadItem]) -> SidebarBadgeCounts {
        var counts = SidebarBadgeCounts(all: downloads.count)

        for item in downloads {
            switch item.status {
            case .queued, .received, .pendingConfirmation:
                counts.queue += 1
            case .downloading:
                counts.downloading += 1
            case .paused:
                counts.paused += 1
            case .completed:
                counts.completed += 1
            case .failed, .cancelled:
                counts.failed += 1
            }

            if DownloadIntelligence.isScheduled(item) {
                counts.scheduled += 1
            }
            if item.status == .completed, FileLocationMonitor.shared.isMissing(id: item.id) {
                counts.missingFile += 1
            }
            if DownloadIntelligence.isToday(item) {
                counts.today += 1
            }
            if DownloadIntelligence.isLargeFile(item) {
                counts.largeFiles += 1
            }

            if let category = FileTypeHelper.category(for: item.fileName) {
                counts.library[category, default: 0] += 1
            }

            if let folderID = item.folder?.id {
                counts.customFolders[folderID, default: 0] += 1
            }
        }

        return counts
    }

    func filter(downloads: [DownloadItem]) -> [DownloadItem] {
        var result = downloads

        switch selectedSidebarItem {
        case .allDownloads, .allFiles:
            break
        case .queue:
            result = result.filter {
                $0.status == .queued || $0.status == .received || $0.status == .pendingConfirmation
            }
        case .scheduled:
            result = result.filter { DownloadIntelligence.isScheduled($0) }
        case .downloading:
            result = result.filter { $0.status == .downloading }
        case .paused:
            result = result.filter { $0.status == .paused }
        case .completed:
            result = result.filter { $0.status == .completed }
        case .failed:
            result = result.filter { $0.status == .failed || $0.status == .cancelled }
        case .missingFile:
            result = result.filter {
                $0.status == .completed && FileLocationMonitor.shared.isMissing(id: $0.id)
            }
        case .today:
            result = result.filter { DownloadIntelligence.isToday($0) }
        case .largeFiles:
            result = result.filter { DownloadIntelligence.isLargeFile($0) }
        case .library(let category):
            result = result.filter { FileTypeHelper.matches(category: category, fileName: $0.fileName) }
        case .customFolder(let folderID):
            result = result.filter { $0.folder?.id == folderID }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            result = result.filter {
                $0.fileName.lowercased().contains(query) ||
                $0.urlString.lowercased().contains(query)
            }
        }

        return downloadManager.sortedDownloads(result)
    }

    func addDownload(
        urlString: String,
        preferredSegmentsCount: Int = 4,
        saveDirectory: URL? = nil,
        fileNameOverride: String? = nil,
        category: LibraryCategory? = nil,
        folder: DownloadFolder? = nil
    ) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") else {
            addError = L10n.t(
                de: "Ungültige URL. Bitte eine gültige HTTP- oder HTTPS-Adresse eingeben.",
                en: "Invalid URL. Please enter a valid HTTP or HTTPS address."
            )
            return
        }

        addError = nil
        isShowingAddSheet = false
        downloadManager.addDownload(
            url: url,
            preferredSegmentsCount: preferredSegmentsCount,
            saveDirectory: saveDirectory,
            fileNameOverride: fileNameOverride,
            category: category,
            folder: folder
        )
    }

    func createFolder() {
        let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if let folder = downloadManager.createFolder(name: name) {
            selectedSidebarItem = .customFolder(folder.id)
        }
        newFolderName = ""
        isShowingNewFolderAlert = false
    }

    func renameFolder(_ folder: DownloadFolder, to name: String) {
        downloadManager.renameFolder(folder, to: name)
    }

    func deleteFolder(_ folder: DownloadFolder) {
        if case .customFolder(let id) = selectedSidebarItem, id == folder.id {
            selectedSidebarItem = .allDownloads
        }
        downloadManager.deleteFolder(folder)
    }

    func moveDownload(_ item: DownloadItem, to folder: DownloadFolder?) {
        downloadManager.moveDownload(item, to: folder)
    }

    func handleDownloadSelection(
        id: UUID,
        in visibleDownloads: [DownloadItem],
        commandPressed: Bool,
        shiftPressed: Bool
    ) {
        if shiftPressed,
           let anchor = selectionAnchorID,
           let anchorIndex = visibleDownloads.firstIndex(where: { $0.id == anchor }),
           let clickIndex = visibleDownloads.firstIndex(where: { $0.id == id }) {
            let range = min(anchorIndex, clickIndex)...max(anchorIndex, clickIndex)
            selectedDownloadIDs = Set(visibleDownloads[range].map(\.id))
            return
        }

        if commandPressed {
            if selectedDownloadIDs.contains(id) {
                selectedDownloadIDs.remove(id)
                if selectionAnchorID == id {
                    selectionAnchorID = selectedDownloadIDs.first
                }
            } else {
                selectedDownloadIDs.insert(id)
                selectionAnchorID = id
            }
            return
        }

        selectedDownloadIDs = [id]
        selectionAnchorID = id
    }

    func pruneSelection(to visibleIDs: Set<UUID>) {
        selectedDownloadIDs.formIntersection(visibleIDs)
        if let anchor = selectionAnchorID, !visibleIDs.contains(anchor) {
            selectionAnchorID = selectedDownloadIDs.first
        }
    }

    func deleteDownload(_ item: DownloadItem) {
        selectedDownloadIDs.remove(item.id)
        if selectionAnchorID == item.id {
            selectionAnchorID = selectedDownloadIDs.first
        }
        downloadManager.deleteDownload(item: item)
    }

    /// Context-menu delete for a single row.
    func requestDelete(_ item: DownloadItem) {
        requestDeleteItems([item])
    }

    /// Toolbar delete: asks for confirmation before destroying active
    /// downloads; everything else is deleted directly.
    func requestDeleteSelected(from downloads: [DownloadItem]) {
        let selected = downloads.filter { selectedDownloadIDs.contains($0.id) }
        guard !selected.isEmpty else { return }
        requestDeleteItems(selected)
    }

    func triggerDeleteSelectionFromShortcut() {
        guard canUseMainShortcuts else { return }
        deleteSelectionTrigger += 1
    }

    // MARK: - Keyboard shortcuts

    var canUseMainShortcuts: Bool {
        !isShowingAddSheet
            && !isShowingHistorySheet
            && !isShowingSettingsSheet
            && pendingConfirmation == nil
            && pendingConfirmationBatch == nil
            && pendingCompletion == nil
    }

    private func primarySelectedRow() -> DownloadRowViewModel? {
        guard let id = selectedDownloadID,
              let item = downloadManager.fetchItemForUI(id: id) else { return nil }
        return DownloadRowViewModel(item: item)
    }

    var canOpenSelected: Bool {
        primarySelectedRow()?.canOpenFile == true
    }

    var canRevealSelectedInFinder: Bool {
        primarySelectedRow()?.canRevealInFinder == true
    }

    var canCopySelectedURL: Bool {
        selectedDownloadID != nil
    }

    var canPauseSelected: Bool {
        primarySelectedRow()?.canPause == true
    }

    var canResumeSelected: Bool {
        primarySelectedRow()?.canResume == true
    }

    var canCancelSelected: Bool {
        primarySelectedRow()?.canCancel == true
    }

    var canTogglePauseResumeSelected: Bool {
        canPauseSelected || canResumeSelected
    }

    var canResumeAll: Bool {
        downloadManager.fetchAllItemsForUI().contains { DownloadRowViewModel(item: $0).canResume }
    }

    var canPauseAll: Bool {
        downloadManager.fetchAllItemsForUI().contains { DownloadRowViewModel(item: $0).canPause }
    }

    func openSelectedFile() {
        guard canUseMainShortcuts else { return }
        primarySelectedRow()?.openFile()
    }

    func revealSelectedInFinder() {
        guard canUseMainShortcuts else { return }
        primarySelectedRow()?.revealInFinder()
    }

    func copySelectedURL() {
        guard canUseMainShortcuts else { return }
        primarySelectedRow()?.copyURL()
    }

    func pauseSelected() {
        guard canUseMainShortcuts else { return }
        guard let id = selectedDownloadID else { return }
        downloadManager.pauseDownload(id: id)
    }

    func selectAllVisible() {
        guard canUseMainShortcuts else { return }
        let visible = filter(downloads: downloadManager.fetchAllItemsForUI())
        selectedDownloadIDs = Set(visible.map(\.id))
        selectionAnchorID = visible.first?.id
    }

    func clearSelection() {
        guard canUseMainShortcuts else { return }
        selectedDownloadIDs.removeAll()
        selectionAnchorID = nil
    }

    func showHistory() {
        guard canUseMainShortcuts else { return }
        isShowingHistorySheet = true
    }

    func openDownloadsFolder() {
        FinderHelper.openDefaultSaveDirectory()
    }

    func showNewFolderAlert() {
        guard canUseMainShortcuts else { return }
        isShowingNewFolderAlert = true
    }

    func selectSidebarFilter(_ filter: SidebarSelection) {
        guard canUseMainShortcuts else { return }
        selectedSidebarItem = filter
    }

    func toggleInspector() {
        guard canUseMainShortcuts else { return }
        withAnimation(AppTheme.inspectorSpring) {
            AppSettings.shared.inspectorCollapsed.toggle()
        }
    }

    func performSearch() {
        guard canUseMainShortcuts else { return }
        isSearchPresented = true
    }

    private func requestDeleteItems(_ items: [DownloadItem]) {
        let hasActive = items.contains { $0.status == .downloading || $0.status == .queued }
        if hasActive {
            pendingDeletions = items
            return
        }
        performDeletion(of: items)
    }

    func confirmPendingDeletion() {
        let items = pendingDeletions
        pendingDeletions = []
        performDeletion(of: items)
    }

    private func performDeletion(of items: [DownloadItem]) {
        for item in items {
            if item.status == .received || item.status == .pendingConfirmation {
                downloadManager.rejectDownload(id: item.id)
                if pendingConfirmation?.id == item.id {
                    dismissPendingConfirmation()
                }
                selectedDownloadIDs.remove(item.id)
                if selectionAnchorID == item.id {
                    selectionAnchorID = selectedDownloadIDs.first
                }
            } else {
                deleteDownload(item)
            }
        }
    }

    func togglePauseResumeSelected() {
        guard canUseMainShortcuts else { return }
        guard let id = selectedDownloadID else { return }
        downloadManager.togglePauseResume(id: id)
    }

    func resumeSelected() {
        guard canUseMainShortcuts else { return }
        guard let id = selectedDownloadID,
              let item = downloadManager.fetchItemForUI(id: id) else { return }
        let row = DownloadRowViewModel(item: item)
        guard row.canResume else { return }
        row.resume()
    }

    func cancelSelected() {
        guard canUseMainShortcuts else { return }
        guard let id = selectedDownloadID,
              let item = downloadManager.fetchItemForUI(id: id) else { return }
        let row = DownloadRowViewModel(item: item)
        guard row.canCancel else { return }
        row.cancel()
    }

    func resumeAllSelected(from downloads: [DownloadItem]) {
        for item in downloads where selectedDownloadIDs.contains(item.id) {
            let row = DownloadRowViewModel(item: item)
            if row.canResume { row.resume() }
        }
    }

    func pauseAllSelected(from downloads: [DownloadItem]) {
        for item in downloads where selectedDownloadIDs.contains(item.id) {
            let row = DownloadRowViewModel(item: item)
            if row.canPause { row.pause() }
        }
    }

    func cancelAllSelected(from downloads: [DownloadItem]) {
        for item in downloads where selectedDownloadIDs.contains(item.id) {
            let row = DownloadRowViewModel(item: item)
            if row.canCancel { row.cancel() }
        }
    }

    func hasSelectionActions(in downloads: [DownloadItem]) -> Bool {
        downloads.contains { item in
            guard selectedDownloadIDs.contains(item.id) else { return false }
            let row = DownloadRowViewModel(item: item)
            return row.canResume || row.canPause || row.canCancel
        }
    }

    func handleDroppedURLs(_ urls: [URL]) -> Bool {
        let webURLs = urls.filter { $0.scheme == "http" || $0.scheme == "https" }
        guard !webURLs.isEmpty else { return false }
        for url in webURLs {
            receiveDownload(url: url, source: .dragDrop)
        }
        return true
    }

    func receiveDownload(
        url: URL,
        fileNameOverride: String? = nil,
        source: DownloadSource = .chromeExtension,
        requestHeaders: [String: String] = [:],
        referrer: String? = nil
    ) {
        switch downloadManager.receiveDownload(
            url: url,
            fileNameOverride: fileNameOverride,
            source: source,
            requestHeaders: requestHeaders,
            referrer: referrer
        ) {
        case .duplicateAwaitingConfirmation(let newID, let existingID):
            presentConfirmation(for: newID, duplicateID: existingID, from: downloadManager)
        case .awaitingConfirmation(let id):
            presentConfirmation(for: id, duplicateID: nil, from: downloadManager)
        case .blocked, .queued, nil:
            break
        }
    }

    /// Presents the next download(s) that still need confirmation.
    func refreshPendingConfirmation(from downloads: [DownloadItem]) {
        guard pendingConfirmation == nil, pendingConfirmationBatch == nil else { return }

        let awaiting = downloads
            .filter { $0.status == .received || $0.status == .pendingConfirmation }
            .sorted { $0.createdAt < $1.createdAt }

        guard !awaiting.isEmpty else { return }

        if awaiting.count >= 2 {
            pendingConfirmationBatch = awaiting
            return
        }

        guard let next = awaiting.first else { return }
        let duplicate = downloadManager.findActiveDuplicate(
            urlString: next.urlString,
            excluding: next.id
        )
        presentConfirmation(for: next.id, duplicateID: duplicate?.id, from: downloadManager)
    }

    func confirmPendingDownload(options: DownloadConfirmationOptions) {
        guard let item = pendingConfirmation else { return }
        downloadManager.confirmDownload(id: item.id, options: options)
        dismissPendingConfirmation()
    }

    func queuePendingDownloadLater(options: DownloadConfirmationOptions) {
        var queueOptions = options
        queueOptions.startImmediately = false
        confirmPendingDownload(options: queueOptions)
    }

    func confirmPendingBatch(ids: [UUID], startImmediately: Bool, from downloads: [DownloadItem]) {
        if startImmediately {
            downloadManager.confirmDownloads(ids: ids, startImmediately: true)
        } else {
            downloadManager.confirmDownloads(ids: ids, startImmediately: false)
        }
        dismissPendingConfirmation()
        refreshPendingConfirmation(from: downloads)
    }

    func rejectPendingBatch(from downloads: [DownloadItem]) {
        if let batch = pendingConfirmationBatch {
            downloadManager.rejectDownloads(ids: batch.map(\.id))
        }
        dismissPendingConfirmation()
        refreshPendingConfirmation(from: downloads)
    }

    func rejectPendingDownload() {
        if let item = pendingConfirmation {
            downloadManager.rejectDownload(id: item.id)
        }
        dismissPendingConfirmation()
    }

    func showDuplicateDownload(id: UUID) {
        selectedDownloadIDs = [id]
        selectionAnchorID = id
        dismissPendingConfirmation()
        AppActivation.bringToForeground()
    }

    func refreshCompletionDialog(from downloads: [DownloadItem]) {
        guard pendingCompletion == nil else { return }
        guard pendingConfirmation == nil, pendingConfirmationBatch == nil else { return }

        guard let nextID = downloadManager.completionDialogQueue.first,
              let item = downloadManager.fetchItemForUI(id: nextID),
              item.status == .completed else { return }

        pendingCompletion = item
    }

    func dismissCompletionDialog() {
        if let item = pendingCompletion {
            downloadManager.dismissCompletionDialog(id: item.id)
        }
        pendingCompletion = nil
    }

    func showCompletedDownloadInApp(id: UUID) {
        selectedDownloadIDs = [id]
        selectionAnchorID = id
        selectedSidebarItem = .completed
        dismissCompletionDialog()
        AppActivation.bringToForeground()
    }

    private func presentConfirmation(
        for id: UUID,
        duplicateID: UUID?,
        from manager: DownloadManager
    ) {
        guard pendingConfirmation == nil, pendingConfirmationBatch == nil else { return }
        guard let item = manager.fetchItemForUI(id: id) else { return }

        pendingConfirmation = item
        pendingConfirmationDuplicate = duplicateID.flatMap { manager.fetchItemForUI(id: $0) }
    }

    private func dismissPendingConfirmation() {
        pendingConfirmation = nil
        pendingConfirmationBatch = nil
        pendingConfirmationDuplicate = nil
    }

    /// Drops confirmation/completion UI state when underlying downloads were removed or changed.
    func clearStaleDialogState(from downloads: [DownloadItem]) {
        if let item = pendingConfirmation {
            let stillValid = downloads.contains {
                $0.id == item.id && ($0.status == .received || $0.status == .pendingConfirmation)
            }
            if !stillValid {
                dismissPendingConfirmation()
            }
        }

        if let batch = pendingConfirmationBatch {
            let validItems = batch.filter { batchItem in
                downloads.contains {
                    $0.id == batchItem.id && ($0.status == .received || $0.status == .pendingConfirmation)
                }
            }
            if validItems.count < 2 {
                dismissPendingConfirmation()
            } else if validItems.count != batch.count {
                pendingConfirmationBatch = validItems
            }
        }

        if let item = pendingCompletion {
            let stillValid = downloads.contains {
                $0.id == item.id && $0.status == .completed
            }
            if !stillValid {
                dismissCompletionDialog()
            }
        }
    }

    /// ⌘⇧V: starts a download from a URL on the clipboard; opens the add
    /// sheet when the clipboard has no usable URL.
    func pasteAndDownload() {
        let pasted = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let lowered = pasted.lowercased()
        if lowered.hasPrefix("http://") || lowered.hasPrefix("https://"),
           let url = URL(string: pasted) {
            receiveDownload(url: url, source: .paste)
        } else {
            isShowingAddSheet = true
        }
    }

    func startAll() {
        downloadManager.resumeAll()
    }

    func pauseAll() {
        downloadManager.pauseAll()
    }

    func clearCompleted() {
        downloadManager.clearCompleted()
    }

    var sortOrder: DownloadSortOrder {
        get { AppSettings.shared.sortOrder }
        set { AppSettings.shared.sortOrder = newValue }
    }

    var tableSortOrder: DownloadSortOrder {
        AppSettings.shared.sortOrder
    }

    var tableSortAscending: Bool {
        AppSettings.shared.sortAscending
    }

    func toggleTableSort(for column: DownloadTableColumn) {
        let settings = AppSettings.shared
        let order = column.sortOrder
        if settings.sortOrder == order {
            settings.sortAscending.toggle()
        } else {
            settings.sortOrder = order
        }
    }

    var tableColumnOrder: [DownloadTableColumn] {
        DownloadTableColumn.normalizedOrder(
            AppSettings.shared.tableColumnOrder.compactMap(DownloadTableColumn.init(rawValue:))
        )
    }

    func moveTableColumn(from source: DownloadTableColumn, to target: DownloadTableColumn) {
        AppSettings.shared.moveTableColumn(from: source.rawValue, to: target.rawValue)
    }
}
