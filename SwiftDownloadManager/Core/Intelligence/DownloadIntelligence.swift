import Foundation

/// Advises defaults, detects patterns, and surfaces contextual hints.
@MainActor
enum DownloadIntelligence {
    static func enrichConfirmationOptions(_ options: inout DownloadConfirmationOptions, for item: DownloadItem) {
        let settings = AppSettings.shared

        if settings.sizeBasedSegmentCountEnabled, item.bytesTotal > 0 {
            options.preferredSegmentsCount = recommendedSegmentCount(
                bytesTotal: item.bytesTotal,
                defaultCount: options.preferredSegmentsCount
            )
        }

        guard settings.smartFeaturesEnabled else { return }

        guard let host = DomainRuleStore.host(from: item.urlString) else { return }

        if settings.rememberFolderPerHost,
           options.saveDirectory == nil,
           let learned = DownloadLearningStore.suggestedSaveDirectory(for: host) {
            options.saveDirectory = learned
        }

        if options.libraryCategory == nil,
           let category = DownloadLearningStore.suggestedCategory(for: host) {
            options.libraryCategory = category
        }

        if settings.smartPostDownloadActions, options.postDownloadAction == .none {
            if let hostAction = DownloadLearningStore.suggestedPostDownloadAction(for: host) {
                options.postDownloadAction = hostAction
            } else if let extAction = DownloadLearningStore.recommendedPostDownloadAction(for: item.fileName) {
                options.postDownloadAction = extAction
            } else {
                options.postDownloadAction = settings.defaultPostDownloadAction
            }
        }

    }

    static func enrichConfirmationViewModel(
        segmentsCount: inout Int,
        selectedCategory: inout LibraryCategory?,
        selectedDestinationPath: inout String?,
        postDownloadAction: inout PostDownloadAction,
        for item: DownloadItem
    ) {
        var options = AppSettings.shared.defaultConfirmationOptions(for: item)
        enrichConfirmationOptions(&options, for: item)

        if let dir = options.saveDirectory {
            selectedDestinationPath = dir.path
        }
        if let category = options.libraryCategory {
            selectedCategory = category
        }
        if options.postDownloadAction != .none {
            postDownloadAction = options.postDownloadAction
        }
        segmentsCount = options.preferredSegmentsCount
    }

    static func recordCompletedDownload(_ item: DownloadItem) {
        guard AppSettings.shared.smartFeaturesEnabled else { return }
        guard let host = DomainRuleStore.host(from: item.urlString) else { return }

        DownloadLearningStore.recordDownload(
            host: host,
            saveDirectoryPath: item.saveDirectoryPath,
            saveDirectoryBookmark: item.saveDirectoryBookmark,
            category: item.libraryCategory,
            postDownloadAction: item.postDownloadAction
        )

        let ext = URL(fileURLWithPath: item.fileName).pathExtension.lowercased()
        if !ext.isEmpty, item.postDownloadAction != .none {
            DownloadLearningStore.setExtensionRule(fileExtension: ext, action: item.postDownloadAction)
        }
    }

    static func recommendedSegmentCount(bytesTotal: Int64, defaultCount: Int) -> Int {
        AppSettings.shared.recommendedSegmentsCount(for: bytesTotal, fallback: defaultCount)
    }

    static func statusDetail(for item: DownloadItem, metrics: DownloadMetricsTracker) -> String? {
        guard AppSettings.shared.smartFeaturesEnabled else { return nil }

        if item.status == .completed,
           FileLocationMonitor.shared.isMissing(id: item.id) {
            return L10n.t(de: "Datei im Finder nicht gefunden", en: "File not found in Finder")
        }

        if item.startWhenOnWiFi, item.status == .queued || item.status == .paused {
            return L10n.t(de: "Wartet auf WLAN", en: "Waiting for Wi‑Fi")
        }

        if let scheduled = item.scheduledStartAt, scheduled > Date(),
           item.status == .queued || item.status == .paused {
            return L10n.t(
                de: "Geplant: \(L10n.formatRelativeDateTime(scheduled))",
                en: "Scheduled: \(L10n.formatRelativeDateTime(scheduled))"
            )
        }

        if item.holdInQueue, item.status == .queued {
            return L10n.t(de: "Manuell in Warteschlange gehalten", en: "Held manually in queue")
        }

        if item.status == .downloading, metrics.currentSpeed <= 0, metrics.liveBytesReceived > 0 {
            return L10n.t(de: "Verbindung wird aufgebaut…", en: "Establishing connection…")
        }

        if let probe = item.probeErrorMessage, !probe.isEmpty,
           item.status == .received || item.status == .pendingConfirmation {
            return probe
        }

        if item.status == .failed, let error = item.errorMessage {
            return recoveryHint(for: error) ?? error
        }

        return nil
    }

    static func inspectorInsight(
        item: DownloadItem,
        samples: [SpeedSample],
        averageSpeed: Double,
        peakSpeed: Double
    ) -> String? {
        guard AppSettings.shared.smartFeaturesEnabled,
              AppSettings.shared.showInspectorInsights else { return nil }

        if item.status == .completed, FileLocationMonitor.shared.isMissing(id: item.id) {
            return L10n.t(
                de: "Die Datei wurde verschoben oder gelöscht. Ziehe sie erneut per Drag & Drop oder lade sie neu herunter.",
                en: "The file was moved or deleted. Drag it back in or re-download."
            )
        }

        guard item.status == .downloading || !samples.isEmpty else { return nil }

        if peakSpeed > 0, averageSpeed > 0, peakSpeed > averageSpeed * 2.5 {
            return L10n.t(
                de: "Spitze deutlich über Durchschnitt — Server oder Netzwerk limitiert vermutlich.",
                en: "Peak well above average — server or network may be throttling."
            )
        }

        if !item.supportsResume, item.bytesTotal > 100_000_000 {
            return L10n.t(
                de: "Server unterstützt kein Resume — bei Abbruch startet der Download von vorn.",
                en: "Server does not support resume — interruption restarts from the beginning."
            )
        }

        return nil
    }

    static func isLargeFile(_ item: DownloadItem) -> Bool {
        let threshold = Int64(AppSettings.shared.largeFileThresholdGB) * 1_000_000_000
        let size = item.bytesTotal > 0 ? item.bytesTotal : item.bytesReceived
        return size >= threshold
    }

    static func isToday(_ item: DownloadItem) -> Bool {
        let date = item.completedAt ?? item.createdAt
        return Calendar.current.isDateInToday(date)
    }

    static func isScheduled(_ item: DownloadItem) -> Bool {
        guard let scheduled = item.scheduledStartAt else { return false }
        return scheduled > Date() && (item.status == .queued || item.status == .paused)
    }

    private static func recoveryHint(for error: String) -> String? {
        let lower = error.lowercased()
        if lower.contains("internet") || lower.contains("offline") || lower.contains("verbindung") {
            return L10n.t(de: "Netzwerk prüfen und erneut versuchen.", en: "Check your network and try again.")
        }
        if lower.contains("403") || lower.contains("forbidden") {
            return L10n.t(
                de: "Zugriff verweigert — Browser-Header in den Einstellungen aktivieren.",
                en: "Access denied — enable browser headers in Settings."
            )
        }
        if lower.contains("404") || lower.contains("not found") {
            return L10n.t(de: "URL existiert nicht mehr.", en: "The URL no longer exists.")
        }
        if lower.contains("timed out") || lower.contains("abgelaufen") {
            return L10n.t(de: "Probe-Timeout in den Einstellungen erhöhen.", en: "Increase probe timeout in Settings.")
        }
        return nil
    }
}
