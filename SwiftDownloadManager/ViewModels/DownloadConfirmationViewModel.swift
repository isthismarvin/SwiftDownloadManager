import Foundation
import Observation
import AppKit

@Observable
@MainActor
final class DownloadConfirmationViewModel {
    let item: DownloadItem
    let duplicateItem: DownloadItem?
    let folders: [DownloadFolder]

    var editedFileName: String
    var editedURL: String
    var segmentsCount: Int
    var selectedCategory: LibraryCategory?
    var selectedFolder: DownloadFolder?
    var selectedDestinationPath: String?
    var domainPolicy: DomainPolicy = .default
    var postDownloadAction: PostDownloadAction = .none
    var scheduleDate: Date?
    var useSchedule: Bool = false
    var startWhenOnWiFi: Bool = false
    var useBrowserHeaders: Bool = true
    var showAdvanced: Bool = false
    var isReprobing = false
    var selectedConflictPolicy: DestinationConflictPolicy?

    private let downloadManager = DownloadManager.shared

    init(item: DownloadItem, duplicateItem: DownloadItem?, folders: [DownloadFolder]) {
        self.item = item
        self.duplicateItem = duplicateItem
        self.folders = folders
        self.editedFileName = item.fileName
        self.editedURL = item.urlString
        let settings = AppSettings.shared
        self.segmentsCount = item.preferredSegmentsCount
        self.selectedCategory = item.libraryCategory
        self.selectedFolder = item.folder
        self.selectedDestinationPath = item.saveDirectoryPath
        self.postDownloadAction = item.postDownloadAction == .none
            ? settings.defaultPostDownloadAction
            : item.postDownloadAction
        self.startWhenOnWiFi = item.startWhenOnWiFi
        self.useBrowserHeaders = item.requestHeadersJSON != nil && settings.sendBrowserHeadersByDefault

        if let host = DomainRuleStore.host(from: item.urlString) {
            domainPolicy = DomainRuleStore.policy(forHost: host)
        }

        DownloadIntelligence.enrichConfirmationViewModel(
            segmentsCount: &segmentsCount,
            selectedCategory: &selectedCategory,
            selectedDestinationPath: &selectedDestinationPath,
            postDownloadAction: &postDownloadAction,
            for: item
        )
    }

    var contentDuplicateItem: DownloadItem? {
        guard item.bytesTotal > 0 else { return nil }
        return downloadManager.findContentDuplicate(
            fileName: editedFileName,
            bytesTotal: item.bytesTotal,
            saveDirectoryPath: selectedDestinationPath,
            excluding: item.id
        )
    }

    var sourceText: String {
        item.source?.displayName ?? L10n.unknown
    }

    var sourceIcon: String {
        item.source?.icon ?? "questionmark.circle"
    }

    var domain: String? {
        DomainRuleStore.host(from: editedURL)
    }

    var destinationPath: String {
        selectedDestinationPath ?? DownloadPathResolver.preferredDefaultDirectory().path
    }

    var fileTypeText: String {
        if let category = selectedCategory ?? item.libraryCategory {
            return category.displayName
        }
        let ext = URL(fileURLWithPath: editedFileName).pathExtension
        return ext.isEmpty ? L10n.unknown : ext.uppercased()
    }

    var sizeText: String {
        item.bytesTotal > 0 ? ByteFormatter.format(item.bytesTotal) : L10n.unknown
    }

    var resumeText: String {
        item.supportsResume ? L10n.yes : L10n.no
    }

    var isProbing: Bool {
        item.status == .received || isReprobing
    }

    var probeErrorText: String? {
        item.probeErrorMessage
    }

    var hasBrowserHeaders: Bool {
        !item.requestHeaders.isEmpty
    }

    var conflictMessage: String? {
        guard AppSettings.shared.conflictPolicy != .ask || selectedConflictPolicy != nil else {
            if needsConflictChoice {
                return L10n.t(
                    de: "Datei existiert bereits — bitte unten wählen.",
                    en: "File already exists — choose an action below."
                )
            }
            return nil
        }
        let tempName = FileNameSanitizer.sanitize(editedFileName)
        let policy = selectedConflictPolicy ?? AppSettings.shared.conflictPolicy
        guard let preview = DestinationConflictResolver.preview(
            for: item,
            fileName: tempName,
            policy: policy
        ) else {
            return nil
        }
        return DestinationConflictResolver.message(for: preview)
    }

    var needsConflictChoice: Bool {
        AppSettings.shared.conflictPolicy == .ask
            && DestinationConflictResolver.fileExists(for: item, fileName: editedFileName)
    }

    var canSubmit: Bool {
        !editedFileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (!needsConflictChoice || selectedConflictPolicy != nil)
    }

    var estimatedDurationText: String? {
        guard item.bytesTotal > 0 else { return nil }
        let speed = max(AppSettings.shared.effectiveSpeedLimitBytesPerSecond, 0)
        let effectiveSpeed: Int64 = speed > 0 ? speed : 2_000_000
        return TimeFormatter.formatETA(TimeInterval(item.bytesTotal) / TimeInterval(effectiveSpeed))
    }

    /// Single-line summary for the compact metadata row.
    var metadataSummary: String {
        if isProbing { return L10n.t(de: "Metadaten werden ermittelt…", en: "Fetching metadata…") }
        var parts = [
            sizeText,
            L10n.t(de: "Resume \(resumeText)", en: "Resume \(resumeText)"),
            fileTypeText
        ]
        if let eta = estimatedDurationText { parts.append("~\(eta)") }
        return parts.joined(separator: " · ")
    }

    var quickDestinations: [URL] {
        RecentDestinationsStore.quickPickURLs()
    }

    var buildOptions: DownloadConfirmationOptions {
        var saveDirectory: URL?
        if let path = selectedDestinationPath {
            saveDirectory = URL(fileURLWithPath: path, isDirectory: true)
        }

        return DownloadConfirmationOptions(
            fileName: editedFileName,
            urlString: editedURL,
            preferredSegmentsCount: segmentsCount,
            libraryCategory: selectedCategory,
            folder: selectedFolder,
            saveDirectory: saveDirectory,
            domainPolicy: domainPolicy == .default ? nil : domainPolicy,
            startImmediately: true,
            postDownloadAction: postDownloadAction,
            scheduledStartAt: useSchedule ? scheduleDate : nil,
            startWhenOnWiFi: startWhenOnWiFi,
            useBrowserHeaders: useBrowserHeaders,
            conflictPolicyOverride: selectedConflictPolicy
        )
    }

    func buildQueueOnlyOptions() -> DownloadConfirmationOptions {
        var options = buildOptions
        options.startImmediately = false
        return options
    }

    func buildScheduledOptions() -> DownloadConfirmationOptions {
        var options = buildOptions
        options.startImmediately = false
        options.scheduledStartAt = scheduleDate ?? Date().addingTimeInterval(3600)
        return options
    }

    func setDestination(_ url: URL?) {
        if let url {
            selectedDestinationPath = url.path
            downloadManager.updatePendingDestination(id: item.id, saveDirectory: url)
        } else {
            selectedDestinationPath = nil
            downloadManager.updatePendingDestination(id: item.id, saveDirectory: nil)
        }
    }

    func reprobe() {
        guard !isReprobing else { return }
        isReprobing = true
        Task { @MainActor in
            await downloadManager.reprobePendingDownload(id: item.id, urlString: editedURL)
            isReprobing = false
        }
    }

    func copyURL() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(editedURL, forType: .string)
    }
}
