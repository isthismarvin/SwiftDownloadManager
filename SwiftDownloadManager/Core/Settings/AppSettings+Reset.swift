import Foundation
import AppKit

extension AppSettings {
    func resetAllSettings() {
        let keysToReset: [String] = [
            Key.defaultSaveDirectoryBookmark,
            Key.showCompletionDialog,
            Key.showConfirmationDialog,
            Key.pauseDownloadsOnQuit,
            Key.defaultSegmentsCount,
            Key.addNewDownloadsPaused,
            Key.defaultPostDownloadAction,
            Key.conflictPolicy,
            Key.useCustomSpeedLimit,
            Key.customSpeedLimitBytesPerSecond,
            Key.defaultStartWhenOnWiFi,
            Key.probeTimeoutSeconds,
            Key.segmentRetries,
            Key.sendBrowserHeadersByDefault,
            Key.notifyOnComplete,
            Key.notifyOnFailed,
            Key.playNotificationSound,
            Key.showDockBadge,
            Key.historyRetentionDays,
            Key.appLanguage,
            Key.inspectorCollapsed,
            Key.inspectorExpandedHeight,
            Key.downloadSortOrder,
            Key.maxConcurrentDownloads,
            Key.globalSpeedLimitBytesPerSecond,
            Key.launchAtLogin,
            Key.startInBackground,
            Key.showMenuBarIcon,
            Key.hideDockWhenInBackground,
            Key.rememberFolderPerDomain,
            Key.detectDuplicateDownloads,
            Key.stallDetectionEnabled,
            Key.stallTimeoutSeconds,
            Key.notifyOnStall,
            Key.adaptiveSegmentCount,
            Key.sizeBasedSegmentCountEnabled,
            Key.segmentCountTiersJSON,
            Key.fairBandwidthSharing,
            Key.smartPostDownloadActions,
            Key.autoExtractArchives,
            Key.trashArchiveAfterExtraction,
            Key.showInspectorInsights,
            Key.notifyOnQueueBacklog,
            Key.queueBacklogThreshold,
            Key.largeFileThresholdGB,
            Key.showSmartSidebarFilters,
            Key.accelerationLevel,
            Key.bandwidthSharingMode,
            Key.autoRetryEnabled,
            Key.safariEnabled,
            Key.chromeEnabled,
            Key.firefoxEnabled,
            Key.edgeEnabled,
            Key.clipboardMonitoringEnabled,
            Key.rememberFileTypeActions,
            Key.preventIdleSleepWhileDownloading,
            Key.autoResumeOnNetworkRestore,
            Key.dockBadgeDisplayMode,
            Key.dockShowProgressBar,
            Key.windowCloseBehavior,
            Key.confirmQuitWhenDownloading,
            "domainRules",
            "intelligence.hostPreferences",
            "intelligence.extensionRules",
            "appShortcutOverrides"
        ]
        for key in keysToReset {
            UserDefaults.standard.removeObject(forKey: key)
        }

        RecentDestinationsStore.clearAll()
        DomainRuleStore.clearAllRules()

        defaultSaveDirectoryBookmark = nil
        showCompletionDialog = true
        showConfirmationDialog = true
        pauseDownloadsOnQuit = true
        accelerationLevel = .balanced
        addNewDownloadsPaused = false
        defaultSegmentsCount = 4
        defaultPostDownloadAction = .none
        conflictPolicy = .rename
        useCustomSpeedLimit = false
        customSpeedLimitBytesPerSecond = 3_000_000
        defaultStartWhenOnWiFi = false
        bandwidthSharingMode = .auto
        autoRetryEnabled = true
        stallDetectionEnabled = true
        stallTimeoutSeconds = 120
        probeTimeoutSeconds = 30
        segmentRetries = 3
        safariEnabled = true
        chromeEnabled = true
        firefoxEnabled = false
        edgeEnabled = false
        sendBrowserHeadersByDefault = true
        clipboardMonitoringEnabled = false
        rememberFolderPerDomain = true
        rememberFileTypeActions = true
        detectDuplicateDownloads = true
        smartPostDownloadActions = true
        autoExtractArchives = false
        trashArchiveAfterExtraction = false
        schedulerEnabled = false
        schedulerStartHour = 2
        schedulerStartMinute = 0
        schedulerStopHour = 6
        schedulerStopMinute = 0
        onQueueCompleteAction = .doNothing
        notifyOnComplete = true
        notifyOnFailed = true
        notifyOnStall = true
        notifyOnQueueBacklog = false
        queueBacklogThreshold = 5
        playNotificationSound = true
        showDockBadge = true
        dockBadgeDisplayMode = .activeCount
        dockShowProgressBar = true
        preventIdleSleepWhileDownloading = true
        autoResumeOnNetworkRestore = true
        windowCloseBehavior = .hideToMenuBar
        confirmQuitWhenDownloading = true
        historyRetentionDays = 30
        appLanguage = .system
        inspectorCollapsed = false
        inspectorExpandedHeight = AppTheme.inspectorExpandedHeightDefault
        sortOrder = .dateAdded
        sortAscending = DownloadSortOrder.dateAdded.prefersAscending
        tableColumnOrder = DownloadTableColumn.defaultDataColumnOrder.map(\.rawValue)
        maxConcurrentDownloads = 2
        globalSpeedLimitBytesPerSecond = 0
        launchAtLogin = true
        LaunchAtLoginManager.setEnabled(true)
        startInBackground = true
        showMenuBarIcon = true
        hideDockWhenInBackground = true
        BackgroundAppManager.shared.applyActivationPolicy()
        adaptiveSegmentCount = true
        sizeBasedSegmentCountEnabled = true
        segmentCountTiers = SegmentCountPolicy.defaultTiers
        showSmartSidebarFilters = true
        showInspectorInsights = true
        largeFileThresholdGB = 1
        AppShortcutSettings.shared.resetAll()
        DownloadLearningStore.clearAll()
        DownloadManager.shared.applySegmentRetries(3)
    }

    func ensureMigrationFromOldKeys() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Key.autoRetryEnabled) == nil {
            autoRetryEnabled = defaults.object(forKey: "stallAutoRetry") as? Bool ?? true
            UserDefaults.standard.removeObject(forKey: "stallAutoRetry")
        }
        if defaults.object(forKey: Key.bandwidthSharingMode) == nil {
            let oldFair = defaults.object(forKey: Key.fairBandwidthSharing) as? Bool ?? true
            bandwidthSharingMode = oldFair ? .fair : .auto
        }
    }

    /// Older builds copied the custom slider into the global preset key.
    func sanitizePollutedGlobalSpeedLimit() {
        guard !useCustomSpeedLimit,
              !Self.speedLimitPresets.contains(globalSpeedLimitBytesPerSecond) else { return }
        globalSpeedLimitBytesPerSecond = 0
    }
}
