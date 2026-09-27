import Foundation
import Observation

@Observable
@MainActor
final class AppSettings {
    static let shared = AppSettings()

    enum Key {
        static let defaultSaveDirectoryBookmark = "defaultSaveDirectoryBookmark"
        static let showCompletionDialog = "showCompletionDialog"
        static let showConfirmationDialog = "showConfirmationDialog"
        static let pauseDownloadsOnQuit = "pauseDownloadsOnQuit"
        static let defaultSegmentsCount = "defaultSegmentsCount"
        static let addNewDownloadsPaused = "holdNewDownloadsInQueue"
        static let defaultPostDownloadAction = "defaultPostDownloadAction"
        static let conflictPolicy = "destinationConflictPolicy"
        static let useCustomSpeedLimit = "useCustomSpeedLimit"
        static let customSpeedLimitBytesPerSecond = "customSpeedLimitBytesPerSecond"
        static let defaultStartWhenOnWiFi = "defaultStartWhenOnWiFi"
        static let probeTimeoutSeconds = "probeTimeoutSeconds"
        static let segmentRetries = "segmentRetries"
        static let sendBrowserHeadersByDefault = "sendBrowserHeadersByDefault"
        static let notifyOnComplete = "notifyOnComplete"
        static let notifyOnFailed = "notifyOnFailed"
        static let playNotificationSound = "playNotificationSound"
        static let showDockBadge = "showDockBadge"
        static let historyRetentionDays = "historyRetentionDays"
        static let appLanguage = "appLanguage"
        static let inspectorCollapsed = "inspectorCollapsed"
        static let inspectorExpandedHeight = "inspectorExpandedHeight"
        static let downloadSortOrder = "downloadSortOrder"
        static let downloadSortAscending = "downloadSortAscending"
        static let tableColumnOrder = "tableColumnOrder"
        static let maxConcurrentDownloads = "maxConcurrentDownloads"
        static let globalSpeedLimitBytesPerSecond = "globalSpeedLimitBytesPerSecond"
        static let launchAtLogin = "launchAtLogin"
        static let startInBackground = "startInBackground"
        static let showMenuBarIcon = "showMenuBarIcon"
        static let hideDockWhenInBackground = "hideDockWhenInBackground"
        static let rememberFolderPerDomain = "rememberFolderPerHost"
        static let detectDuplicateDownloads = "detectContentDuplicates"
        static let stallDetectionEnabled = "stallDetectionEnabled"
        static let stallTimeoutSeconds = "stallTimeoutSeconds"
        static let stallAutoRetry = "stallAutoRetry"
        static let notifyOnStall = "notifyOnStall"
        static let adaptiveSegmentCount = "adaptiveSegmentCount"
        static let sizeBasedSegmentCountEnabled = "sizeBasedSegmentCountEnabled"
        static let segmentCountTiersJSON = "segmentCountTiersJSON"
        static let fairBandwidthSharing = "fairBandwidthSharing"
        static let smartPostDownloadActions = "smartPostDownloadActions"
        static let autoExtractArchives = "autoExtractArchives"
        static let trashArchiveAfterExtraction = "trashArchiveAfterExtraction"
        static let showInspectorInsights = "showInspectorInsights"
        static let notifyOnQueueBacklog = "notifyOnQueueBacklog"
        static let queueBacklogThreshold = "queueBacklogThreshold"
        static let largeFileThresholdGB = "largeFileThresholdGB"
        static let showSmartSidebarFilters = "showSmartSidebarFilters"
        static let accelerationLevel = "accelerationLevel"
        static let bandwidthSharingMode = "bandwidthSharingMode"
        static let autoRetryEnabled = "autoRetryEnabled"
        static let safariEnabled = "safariEnabled"
        static let chromeEnabled = "chromeEnabled"
        static let firefoxEnabled = "firefoxEnabled"
        static let edgeEnabled = "edgeEnabled"
        static let clipboardMonitoringEnabled = "clipboardMonitoringEnabled"
        static let rememberFileTypeActions = "rememberFileTypeActions"
        static let schedulerEnabled = "schedulerEnabled"
        static let schedulerStartHour = "schedulerStartHour"
        static let schedulerStartMinute = "schedulerStartMinute"
        static let schedulerStopHour = "schedulerStopHour"
        static let schedulerStopMinute = "schedulerStopMinute"
        static let onQueueCompleteAction = "onQueueCompleteAction"
        static let preventIdleSleepWhileDownloading = "preventIdleSleepWhileDownloading"
        static let autoResumeOnNetworkRestore = "autoResumeOnNetworkRestore"
        static let dockBadgeDisplayMode = "dockBadgeDisplayMode"
        static let dockShowProgressBar = "dockShowProgressBar"
        static let windowCloseBehavior = "windowCloseBehavior"
        static let confirmQuitWhenDownloading = "confirmQuitWhenDownloading"
    }

    var appLanguage: AppLanguage = {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: Key.appLanguage) ?? "") ?? .system
    }() {
        didSet { UserDefaults.standard.set(appLanguage.rawValue, forKey: Key.appLanguage) }
    }

    var resolvedLanguageCode: String {
        switch appLanguage {
        case .system:
            let preferred = Locale.preferredLanguages.first ?? "en"
            return preferred.hasPrefix("de") ? "de" : "en"
        case .german: return "de"
        case .english: return "en"
        }
    }

    var defaultSaveDirectoryBookmark: Data? {
        didSet { UserDefaults.standard.set(defaultSaveDirectoryBookmark, forKey: Key.defaultSaveDirectoryBookmark) }
    }

    var showCompletionDialog: Bool {
        didSet { UserDefaults.standard.set(showCompletionDialog, forKey: Key.showCompletionDialog) }
    }

    var showConfirmationDialog: Bool {
        didSet { UserDefaults.standard.set(showConfirmationDialog, forKey: Key.showConfirmationDialog) }
    }

    var pauseDownloadsOnQuit: Bool {
        didSet { UserDefaults.standard.set(pauseDownloadsOnQuit, forKey: Key.pauseDownloadsOnQuit) }
    }

    var accelerationLevel: AccelerationLevel {
        didSet {
            UserDefaults.standard.set(accelerationLevel.rawValue, forKey: Key.accelerationLevel)
            applyAccelerationLevel()
        }
    }

    var addNewDownloadsPaused: Bool {
        didSet { UserDefaults.standard.set(addNewDownloadsPaused, forKey: Key.addNewDownloadsPaused) }
    }

    var defaultSegmentsCount: Int {
        didSet { UserDefaults.standard.set(defaultSegmentsCount, forKey: Key.defaultSegmentsCount) }
    }

    var defaultPostDownloadAction: PostDownloadAction {
        didSet {
            UserDefaults.standard.set(defaultPostDownloadAction.rawValue, forKey: Key.defaultPostDownloadAction)
        }
    }

    var conflictPolicy: DestinationConflictPolicy {
        didSet { UserDefaults.standard.set(conflictPolicy.rawValue, forKey: Key.conflictPolicy) }
    }

    /// Preset values for the non-custom speed limit UI.
    static let speedLimitPresets: [Int64] = [0, 500_000, 1_000_000, 2_000_000, 5_000_000]

    /// Active limit applied to the download engine (custom overrides presets).
    var effectiveSpeedLimitBytesPerSecond: Int64 {
        useCustomSpeedLimit ? customSpeedLimitBytesPerSecond : globalSpeedLimitBytesPerSecond
    }

    var useCustomSpeedLimit: Bool {
        didSet {
            UserDefaults.standard.set(useCustomSpeedLimit, forKey: Key.useCustomSpeedLimit)
            applyEffectiveSpeedLimit()
        }
    }

    var customSpeedLimitBytesPerSecond: Int64 {
        didSet {
            UserDefaults.standard.set(customSpeedLimitBytesPerSecond, forKey: Key.customSpeedLimitBytesPerSecond)
            if useCustomSpeedLimit { applyEffectiveSpeedLimit() }
        }
    }

    var defaultStartWhenOnWiFi: Bool {
        didSet { UserDefaults.standard.set(defaultStartWhenOnWiFi, forKey: Key.defaultStartWhenOnWiFi) }
    }

    var bandwidthSharingMode: BandwidthSharingMode {
        didSet {
            UserDefaults.standard.set(bandwidthSharingMode.rawValue, forKey: Key.bandwidthSharingMode)
            applyEffectiveSpeedLimit()
        }
    }

    var autoRetryEnabled: Bool {
        didSet { UserDefaults.standard.set(autoRetryEnabled, forKey: Key.autoRetryEnabled) }
    }

    var stallDetectionEnabled: Bool {
        didSet { UserDefaults.standard.set(stallDetectionEnabled, forKey: Key.stallDetectionEnabled) }
    }

    var stallTimeoutSeconds: Int {
        didSet { UserDefaults.standard.set(stallTimeoutSeconds, forKey: Key.stallTimeoutSeconds) }
    }

    var probeTimeoutSeconds: Int {
        didSet { UserDefaults.standard.set(probeTimeoutSeconds, forKey: Key.probeTimeoutSeconds) }
    }

    var segmentRetries: Int {
        didSet {
            UserDefaults.standard.set(segmentRetries, forKey: Key.segmentRetries)
            DownloadManager.shared.applySegmentRetries(segmentRetries)
        }
    }

    // MARK: - Integration

    var safariEnabled: Bool {
        didSet { UserDefaults.standard.set(safariEnabled, forKey: Key.safariEnabled) }
    }

    var chromeEnabled: Bool {
        didSet { UserDefaults.standard.set(chromeEnabled, forKey: Key.chromeEnabled) }
    }

    var firefoxEnabled: Bool {
        didSet { UserDefaults.standard.set(firefoxEnabled, forKey: Key.firefoxEnabled) }
    }

    var edgeEnabled: Bool {
        didSet { UserDefaults.standard.set(edgeEnabled, forKey: Key.edgeEnabled) }
    }

    var sendBrowserHeadersByDefault: Bool {
        didSet { UserDefaults.standard.set(sendBrowserHeadersByDefault, forKey: Key.sendBrowserHeadersByDefault) }
    }

    var clipboardMonitoringEnabled: Bool {
        didSet { UserDefaults.standard.set(clipboardMonitoringEnabled, forKey: Key.clipboardMonitoringEnabled) }
    }

    // MARK: - Automation

    var rememberFolderPerDomain: Bool {
        didSet { UserDefaults.standard.set(rememberFolderPerDomain, forKey: Key.rememberFolderPerDomain) }
    }

    var rememberFileTypeActions: Bool {
        didSet { UserDefaults.standard.set(rememberFileTypeActions, forKey: Key.rememberFileTypeActions) }
    }

    var detectDuplicateDownloads: Bool {
        didSet { UserDefaults.standard.set(detectDuplicateDownloads, forKey: Key.detectDuplicateDownloads) }
    }

    var smartPostDownloadActions: Bool {
        didSet { UserDefaults.standard.set(smartPostDownloadActions, forKey: Key.smartPostDownloadActions) }
    }

    var autoExtractArchives: Bool {
        didSet { UserDefaults.standard.set(autoExtractArchives, forKey: Key.autoExtractArchives) }
    }

    var trashArchiveAfterExtraction: Bool {
        didSet { UserDefaults.standard.set(trashArchiveAfterExtraction, forKey: Key.trashArchiveAfterExtraction) }
    }

    // MARK: - Scheduler & Power Management

    var schedulerEnabled: Bool {
        didSet { UserDefaults.standard.set(schedulerEnabled, forKey: Key.schedulerEnabled) }
    }

    var schedulerStartHour: Int {
        didSet { UserDefaults.standard.set(schedulerStartHour, forKey: Key.schedulerStartHour) }
    }

    var schedulerStartMinute: Int {
        didSet { UserDefaults.standard.set(schedulerStartMinute, forKey: Key.schedulerStartMinute) }
    }

    var schedulerStopHour: Int {
        didSet { UserDefaults.standard.set(schedulerStopHour, forKey: Key.schedulerStopHour) }
    }

    var schedulerStopMinute: Int {
        didSet { UserDefaults.standard.set(schedulerStopMinute, forKey: Key.schedulerStopMinute) }
    }

    var onQueueCompleteAction: OnQueueCompleteAction {
        didSet { UserDefaults.standard.set(onQueueCompleteAction.rawValue, forKey: Key.onQueueCompleteAction) }
    }

    var preventIdleSleepWhileDownloading: Bool {
        didSet {
            UserDefaults.standard.set(preventIdleSleepWhileDownloading, forKey: Key.preventIdleSleepWhileDownloading)
            SleepAssertionManager.shared.update(activeCount: DownloadManager.shared.activeDownloadsCount)
        }
    }

    var autoResumeOnNetworkRestore: Bool {
        didSet { UserDefaults.standard.set(autoResumeOnNetworkRestore, forKey: Key.autoResumeOnNetworkRestore) }
    }

    var windowCloseBehavior: WindowCloseBehavior {
        didSet { UserDefaults.standard.set(windowCloseBehavior.rawValue, forKey: Key.windowCloseBehavior) }
    }

    var confirmQuitWhenDownloading: Bool {
        didSet { UserDefaults.standard.set(confirmQuitWhenDownloading, forKey: Key.confirmQuitWhenDownloading) }
    }

    // MARK: - Notifications

    var notifyOnComplete: Bool {
        didSet { UserDefaults.standard.set(notifyOnComplete, forKey: Key.notifyOnComplete) }
    }

    var notifyOnFailed: Bool {
        didSet { UserDefaults.standard.set(notifyOnFailed, forKey: Key.notifyOnFailed) }
    }

    var notifyOnStall: Bool {
        didSet { UserDefaults.standard.set(notifyOnStall, forKey: Key.notifyOnStall) }
    }

    var notifyOnQueueBacklog: Bool {
        didSet { UserDefaults.standard.set(notifyOnQueueBacklog, forKey: Key.notifyOnQueueBacklog) }
    }

    var queueBacklogThreshold: Int {
        didSet { UserDefaults.standard.set(queueBacklogThreshold, forKey: Key.queueBacklogThreshold) }
    }

    var playNotificationSound: Bool {
        didSet { UserDefaults.standard.set(playNotificationSound, forKey: Key.playNotificationSound) }
    }

    var showDockBadge: Bool {
        didSet {
            UserDefaults.standard.set(showDockBadge, forKey: Key.showDockBadge)
            DownloadManager.shared.updateDockProgress()
        }
    }

    var dockBadgeDisplayMode: DockBadgeDisplayMode {
        didSet {
            UserDefaults.standard.set(dockBadgeDisplayMode.rawValue, forKey: Key.dockBadgeDisplayMode)
            DownloadManager.shared.updateDockProgress()
        }
    }

    var dockShowProgressBar: Bool {
        didSet {
            UserDefaults.standard.set(dockShowProgressBar, forKey: Key.dockShowProgressBar)
            DownloadManager.shared.updateDockProgress()
        }
    }

    // MARK: - History

    var historyRetentionDays: Int {
        didSet {
            UserDefaults.standard.set(historyRetentionDays, forKey: Key.historyRetentionDays)
            DownloadManager.shared.pruneHistory(olderThanDays: historyRetentionDays)
        }
    }

    // MARK: - UI State (not in Settings panels, but persisted)

    var inspectorCollapsed: Bool {
        didSet { UserDefaults.standard.set(inspectorCollapsed, forKey: Key.inspectorCollapsed) }
    }

    var inspectorExpandedHeight: CGFloat = {
        let stored = UserDefaults.standard.double(forKey: Key.inspectorExpandedHeight)
        guard stored > 0 else { return AppTheme.inspectorExpandedHeightDefault }
        return min(
            max(CGFloat(stored), AppTheme.inspectorExpandedHeightMin),
            AppTheme.inspectorExpandedHeightMax
        )
    }() {
        didSet {
            let clamped = Self.clampInspectorHeight(inspectorExpandedHeight)
            if clamped != inspectorExpandedHeight {
                inspectorExpandedHeight = clamped
                return
            }
            UserDefaults.standard.set(Double(inspectorExpandedHeight), forKey: Key.inspectorExpandedHeight)
        }
    }

    var sortOrder: DownloadSortOrder = {
        DownloadSortOrder.fromPersisted(UserDefaults.standard.string(forKey: Key.downloadSortOrder))
    }() {
        didSet {
            UserDefaults.standard.set(sortOrder.rawValue, forKey: Key.downloadSortOrder)
            if oldValue != sortOrder {
                sortAscending = sortOrder.prefersAscending
            }
        }
    }

    var sortAscending: Bool = {
        if UserDefaults.standard.object(forKey: Key.downloadSortAscending) == nil {
            return DownloadSortOrder.fromPersisted(
                UserDefaults.standard.string(forKey: Key.downloadSortOrder)
            ).prefersAscending
        }
        return UserDefaults.standard.bool(forKey: Key.downloadSortAscending)
    }() {
        didSet { UserDefaults.standard.set(sortAscending, forKey: Key.downloadSortAscending) }
    }

    var tableColumnOrder: [String] = AppSettings.loadTableColumnOrder() {
        didSet {
            UserDefaults.standard.set(
                tableColumnOrder.joined(separator: ","),
                forKey: Key.tableColumnOrder
            )
        }
    }

    var showSmartSidebarFilters: Bool {
        didSet { UserDefaults.standard.set(showSmartSidebarFilters, forKey: Key.showSmartSidebarFilters) }
    }

    var showInspectorInsights: Bool {
        didSet { UserDefaults.standard.set(showInspectorInsights, forKey: Key.showInspectorInsights) }
    }

    var largeFileThresholdGB: Int {
        didSet { UserDefaults.standard.set(largeFileThresholdGB, forKey: Key.largeFileThresholdGB) }
    }

    // MARK: - Engine internals (persisted, not in Settings UI)
    // These are used by the download engine but configured via accelerationLevel.

    var sizeBasedSegmentCountEnabled: Bool {
        didSet { UserDefaults.standard.set(sizeBasedSegmentCountEnabled, forKey: Key.sizeBasedSegmentCountEnabled) }
    }

    var segmentCountTiers: [SegmentCountTier] {
        didSet {
            let normalized = SegmentCountPolicy.normalizedTiers(segmentCountTiers)
            if normalized != segmentCountTiers {
                segmentCountTiers = normalized
                return
            }
            persistSegmentCountTiers(normalized)
        }
    }

    var adaptiveSegmentCount: Bool {
        didSet { UserDefaults.standard.set(adaptiveSegmentCount, forKey: Key.adaptiveSegmentCount) }
    }

    // MARK: - Legacy aliases (mapped to old UserDefaults keys)

    var holdNewDownloadsInQueue: Bool {
        get { addNewDownloadsPaused }
        set { addNewDownloadsPaused = newValue }
    }

    var fairBandwidthSharing: Bool {
        get { bandwidthSharingMode == .fair }
        set { bandwidthSharingMode = newValue ? .fair : .auto }
    }

    var smartFeaturesEnabled: Bool {
        get { true }
        set {}
    }

    var rememberFolderPerHost: Bool {
        get { rememberFolderPerDomain }
        set { rememberFolderPerDomain = newValue }
    }

    var detectContentDuplicates: Bool {
        get { detectDuplicateDownloads }
        set { detectDuplicateDownloads = newValue }
    }

    var stallAutoRetry: Bool {
        get { autoRetryEnabled }
        set { autoRetryEnabled = newValue }
    }

    func recommendedSegmentsCount(for bytesTotal: Int64, fallback: Int? = nil) -> Int {
        let fallbackCount = fallback ?? accelerationLevel.segmentCount
        guard sizeBasedSegmentCountEnabled else { return fallbackCount }
        return SegmentCountPolicy.connections(
            for: bytesTotal,
            tiers: segmentCountTiers,
            fallback: fallbackCount
        )
    }

    var canAddSegmentCountTier: Bool {
        segmentCountTiers.filter { !$0.isCatchAll }.count < 7
    }

    var canRemoveSegmentCountTier: Bool {
        segmentCountTiers.filter { !$0.isCatchAll }.count > 1
    }

    func addSegmentCountTier() {
        var tiers = SegmentCountPolicy.normalizedTiers(segmentCountTiers)
        guard tiers.filter({ !$0.isCatchAll }).count < 7 else { return }

        let bounded = tiers.filter { !$0.isCatchAll }
        let catchAllConnections = tiers.first(where: \.isCatchAll)?.connections ?? 8
        let newMB: Int
        if let last = bounded.last {
            newMB = max(last.maxSizeMB + 1, last.maxSizeMB * 2)
        } else {
            newMB = 50
        }

        tiers.insert(
            SegmentCountTier(maxSizeMB: newMB, connections: catchAllConnections),
            at: bounded.count
        )
        segmentCountTiers = SegmentCountPolicy.normalizedTiers(tiers)
    }

    func removeLastBoundedSegmentCountTier() {
        var tiers = SegmentCountPolicy.normalizedTiers(segmentCountTiers)
        let bounded = tiers.filter { !$0.isCatchAll }
        guard bounded.count > 1, let last = bounded.last else { return }
        tiers.removeAll { $0.id == last.id }
        segmentCountTiers = SegmentCountPolicy.normalizedTiers(tiers)
    }

    func updateSegmentCountTier(id: UUID, maxSizeMB: Int? = nil, connections: Int? = nil) {
        var tiers = segmentCountTiers
        guard let index = tiers.firstIndex(where: { $0.id == id }) else { return }
        if let maxSizeMB, !tiers[index].isCatchAll {
            tiers[index].maxSizeMB = max(1, maxSizeMB)
        }
        if let connections {
            tiers[index].connections = connections
        }
        segmentCountTiers = SegmentCountPolicy.normalizedTiers(tiers)
    }

    private func applyAccelerationLevel() {
        let count = accelerationLevel.segmentCount
        defaultSegmentsCount = count
        let rawConnections = min(count, 8)
        let rawTiers = SegmentCountPolicy.defaultTiers
        var tiers = SegmentCountPolicy.normalizedTiers(rawTiers)
        for i in tiers.indices {
            tiers[i].connections = min(tiers[i].connections, rawConnections)
        }
        segmentCountTiers = SegmentCountPolicy.normalizedTiers(tiers)
    }

    private static func loadSegmentCountTiers() -> [SegmentCountTier] {
        guard let data = UserDefaults.standard.data(forKey: Key.segmentCountTiersJSON),
              let tiers = try? JSONDecoder().decode([SegmentCountTier].self, from: data) else {
            return SegmentCountPolicy.defaultTiers
        }
        return SegmentCountPolicy.normalizedTiers(tiers)
    }

    private func persistSegmentCountTiers(_ tiers: [SegmentCountTier]) {
        guard let data = try? JSONEncoder().encode(tiers) else { return }
        UserDefaults.standard.set(data, forKey: Key.segmentCountTiersJSON)
    }

    private init() {
        let defaults = UserDefaults.standard
        defaultSaveDirectoryBookmark = defaults.data(forKey: Key.defaultSaveDirectoryBookmark)
        showCompletionDialog = defaults.object(forKey: Key.showCompletionDialog) as? Bool ?? true
        showConfirmationDialog = defaults.object(forKey: Key.showConfirmationDialog) as? Bool ?? true
        pauseDownloadsOnQuit = defaults.object(forKey: Key.pauseDownloadsOnQuit) as? Bool ?? true
        let accelLevel = AccelerationLevel(rawValue: defaults.string(forKey: Key.accelerationLevel) ?? "") ?? .balanced
        accelerationLevel = accelLevel
        addNewDownloadsPaused = defaults.bool(forKey: Key.addNewDownloadsPaused)
        let segments = defaults.integer(forKey: Key.defaultSegmentsCount)
        defaultSegmentsCount = segments == 0 ? accelLevel.segmentCount : segments
        defaultPostDownloadAction = PostDownloadAction(
            rawValue: defaults.string(forKey: Key.defaultPostDownloadAction) ?? ""
        ) ?? .none
        conflictPolicy = DestinationConflictPolicy(
            rawValue: defaults.string(forKey: Key.conflictPolicy) ?? ""
        ) ?? .rename
        useCustomSpeedLimit = defaults.bool(forKey: Key.useCustomSpeedLimit)
        customSpeedLimitBytesPerSecond = defaults.object(forKey: Key.customSpeedLimitBytesPerSecond) as? Int64 ?? 3_000_000
        defaultStartWhenOnWiFi = defaults.bool(forKey: Key.defaultStartWhenOnWiFi)
        let bwRaw = defaults.string(forKey: Key.bandwidthSharingMode) ?? ""
        bandwidthSharingMode = BandwidthSharingMode(rawValue: bwRaw) ?? .auto
        autoRetryEnabled = defaults.object(forKey: Key.autoRetryEnabled) as? Bool ?? true
        let stallTimeout = defaults.integer(forKey: Key.stallTimeoutSeconds)
        stallTimeoutSeconds = stallTimeout == 0 ? 120 : stallTimeout
        stallDetectionEnabled = defaults.object(forKey: Key.stallDetectionEnabled) as? Bool ?? true
        let timeout = defaults.integer(forKey: Key.probeTimeoutSeconds)
        probeTimeoutSeconds = timeout == 0 ? 30 : timeout
        let retries = defaults.integer(forKey: Key.segmentRetries)
        segmentRetries = retries == 0 ? 3 : retries
        safariEnabled = defaults.object(forKey: Key.safariEnabled) as? Bool ?? true
        chromeEnabled = defaults.object(forKey: Key.chromeEnabled) as? Bool ?? true
        firefoxEnabled = defaults.object(forKey: Key.firefoxEnabled) as? Bool ?? false
        edgeEnabled = defaults.object(forKey: Key.edgeEnabled) as? Bool ?? false
        sendBrowserHeadersByDefault = defaults.object(forKey: Key.sendBrowserHeadersByDefault) as? Bool ?? true
        clipboardMonitoringEnabled = defaults.object(forKey: Key.clipboardMonitoringEnabled) as? Bool ?? false
        rememberFolderPerDomain = defaults.object(forKey: Key.rememberFolderPerDomain) as? Bool ?? true
        rememberFileTypeActions = defaults.object(forKey: Key.rememberFileTypeActions) as? Bool ?? true
        detectDuplicateDownloads = defaults.object(forKey: Key.detectDuplicateDownloads) as? Bool ?? true
        smartPostDownloadActions = defaults.object(forKey: Key.smartPostDownloadActions) as? Bool ?? true
        autoExtractArchives = defaults.bool(forKey: Key.autoExtractArchives)
        trashArchiveAfterExtraction = defaults.bool(forKey: Key.trashArchiveAfterExtraction)
        schedulerEnabled = defaults.bool(forKey: Key.schedulerEnabled)
        schedulerStartHour = defaults.object(forKey: Key.schedulerStartHour) as? Int ?? 2
        schedulerStartMinute = defaults.object(forKey: Key.schedulerStartMinute) as? Int ?? 0
        schedulerStopHour = defaults.object(forKey: Key.schedulerStopHour) as? Int ?? 6
        schedulerStopMinute = defaults.object(forKey: Key.schedulerStopMinute) as? Int ?? 0
        if let rawAction = defaults.string(forKey: Key.onQueueCompleteAction),
           let action = OnQueueCompleteAction(rawValue: rawAction) {
            onQueueCompleteAction = action
        } else {
            onQueueCompleteAction = .doNothing
        }
        preventIdleSleepWhileDownloading = defaults.object(forKey: Key.preventIdleSleepWhileDownloading) as? Bool ?? true
        autoResumeOnNetworkRestore = defaults.object(forKey: Key.autoResumeOnNetworkRestore) as? Bool ?? true
        let windowCloseRaw = defaults.string(forKey: Key.windowCloseBehavior) ?? ""
        windowCloseBehavior = WindowCloseBehavior(rawValue: windowCloseRaw) ?? .hideToMenuBar
        confirmQuitWhenDownloading = defaults.object(forKey: Key.confirmQuitWhenDownloading) as? Bool ?? true
        notifyOnComplete = defaults.object(forKey: Key.notifyOnComplete) as? Bool ?? true
        notifyOnFailed = defaults.object(forKey: Key.notifyOnFailed) as? Bool ?? true
        notifyOnStall = defaults.object(forKey: Key.notifyOnStall) as? Bool ?? true
        notifyOnQueueBacklog = defaults.object(forKey: Key.notifyOnQueueBacklog) as? Bool ?? false
        let backlog = defaults.integer(forKey: Key.queueBacklogThreshold)
        queueBacklogThreshold = backlog == 0 ? 5 : backlog
        playNotificationSound = defaults.object(forKey: Key.playNotificationSound) as? Bool ?? true
        showDockBadge = defaults.object(forKey: Key.showDockBadge) as? Bool ?? true
        let dockModeRaw = defaults.string(forKey: Key.dockBadgeDisplayMode) ?? ""
        dockBadgeDisplayMode = DockBadgeDisplayMode(rawValue: dockModeRaw) ?? .activeCount
        dockShowProgressBar = defaults.object(forKey: Key.dockShowProgressBar) as? Bool ?? true
        let retention = defaults.integer(forKey: Key.historyRetentionDays)
        historyRetentionDays = retention == 0 ? 30 : retention
        appLanguage = AppLanguage(rawValue: defaults.string(forKey: Key.appLanguage) ?? "") ?? .system
        inspectorCollapsed = defaults.bool(forKey: Key.inspectorCollapsed)
        let storedInspectorHeight = defaults.double(forKey: Key.inspectorExpandedHeight)
        inspectorExpandedHeight = Self.clampInspectorHeight(
            storedInspectorHeight > 0
                ? CGFloat(storedInspectorHeight)
                : AppTheme.inspectorExpandedHeightDefault
        )
        let concurrent = defaults.integer(forKey: Key.maxConcurrentDownloads)
        maxConcurrentDownloads = concurrent == 0 ? 2 : concurrent
        globalSpeedLimitBytesPerSecond = defaults.value(forKey: Key.globalSpeedLimitBytesPerSecond) as? Int64 ?? 0
        launchAtLogin = defaults.object(forKey: Key.launchAtLogin) as? Bool ?? true
        startInBackground = defaults.object(forKey: Key.startInBackground) as? Bool ?? true
        showMenuBarIcon = defaults.object(forKey: Key.showMenuBarIcon) as? Bool ?? true
        hideDockWhenInBackground = defaults.object(forKey: Key.hideDockWhenInBackground) as? Bool ?? true
        showSmartSidebarFilters = defaults.object(forKey: Key.showSmartSidebarFilters) as? Bool ?? true
        showInspectorInsights = defaults.object(forKey: Key.showInspectorInsights) as? Bool ?? true
        let largeGB = defaults.integer(forKey: Key.largeFileThresholdGB)
        largeFileThresholdGB = largeGB == 0 ? 1 : largeGB
        let legacyAdaptive = defaults.object(forKey: Key.adaptiveSegmentCount) as? Bool ?? true
        adaptiveSegmentCount = legacyAdaptive
        if defaults.object(forKey: Key.sizeBasedSegmentCountEnabled) == nil {
            sizeBasedSegmentCountEnabled = legacyAdaptive
        } else {
            sizeBasedSegmentCountEnabled = defaults.bool(forKey: Key.sizeBasedSegmentCountEnabled)
        }
        segmentCountTiers = Self.loadSegmentCountTiers()
        sanitizePollutedGlobalSpeedLimit()
        ensureMigrationFromOldKeys()
    }

    private static func clampInspectorHeight(_ value: CGFloat) -> CGFloat {
        min(max(value, AppTheme.inspectorExpandedHeightMin), AppTheme.inspectorExpandedHeightMax)
    }

    var defaultSaveDirectoryPath: String {
        resolvedDefaultSaveDirectory()?.path ?? DownloadPathResolver.defaultDownloadsDirectory().path
    }

    func resolvedDefaultSaveDirectory() -> URL? {
        if let bookmark = defaultSaveDirectoryBookmark,
           let url = BookmarkHelper.resolveBookmark(bookmark) {
            defer { BookmarkHelper.stopAccessing(url) }
            return url.resolvingSymlinksInPath()
        }
        return DownloadPathResolver.defaultDownloadsDirectory()
    }

    func setDefaultSaveDirectory(_ url: URL) {
        defaultSaveDirectoryBookmark = BookmarkHelper.createBookmark(for: url)
    }

    func clearDefaultSaveDirectory() {
        defaultSaveDirectoryBookmark = nil
    }

    func applyEffectiveSpeedLimit() {
        DownloadManager.shared.applyFairBandwidthSharing()
    }

    func syncCustomSpeedIfNeeded() {
        applyEffectiveSpeedLimit()
    }

    func shouldShowConfirmation(for urlString: String) -> Bool {
        if DomainRuleStore.policy(for: urlString) == .alwaysAsk { return true }
        return showConfirmationDialog
    }

    func defaultConfirmationOptions(for item: DownloadItem) -> DownloadConfirmationOptions {
        var saveDirectory: URL?
        if let path = item.saveDirectoryPath {
            saveDirectory = URL(fileURLWithPath: path, isDirectory: true)
        } else if let url = resolvedDefaultSaveDirectory() {
            saveDirectory = url
        }

        var options = DownloadConfirmationOptions(
            fileName: item.fileName,
            urlString: item.urlString,
            preferredSegmentsCount: item.preferredSegmentsCount,
            libraryCategory: item.libraryCategory,
            folder: item.folder,
            saveDirectory: saveDirectory,
            domainPolicy: nil,
            startImmediately: !addNewDownloadsPaused,
            postDownloadAction: item.postDownloadAction == .none ? defaultPostDownloadAction : item.postDownloadAction,
            scheduledStartAt: nil,
            startWhenOnWiFi: item.startWhenOnWiFi,
            useBrowserHeaders: sendBrowserHeadersByDefault && item.requestHeadersJSON != nil
        )
        DownloadIntelligence.enrichConfirmationOptions(&options, for: item)
        return options
    }

    // MARK: - Column / Table helpers (UI state)

    func moveTableColumn(from source: String, to target: String) {
        guard source != target else { return }
        var order = DownloadTableColumn.normalizedOrder(
            tableColumnOrder.compactMap(DownloadTableColumn.init(rawValue:))
        ).map(\.rawValue)
        guard let fromIndex = order.firstIndex(of: source),
              let toIndex = order.firstIndex(of: target) else { return }
        order.remove(at: fromIndex)
        order.insert(source, at: toIndex)
        tableColumnOrder = order
    }

    func moveTableColumn(_ column: DownloadTableColumn, direction: Int) {
        guard column.isReorderable else { return }
        var order = DownloadTableColumn.normalizedOrder(
            tableColumnOrder.compactMap(DownloadTableColumn.init(rawValue:))
        )
        guard let index = order.firstIndex(of: column) else { return }
        let newIndex = index + direction
        guard order.indices.contains(newIndex) else { return }
        order.swapAt(index, newIndex)
        tableColumnOrder = order.map(\.rawValue)
    }

    func resetTableColumnOrder() {
        tableColumnOrder = DownloadTableColumn.defaultDataColumnOrder.map(\.rawValue)
    }

    private static func loadTableColumnOrder() -> [String] {
        guard let raw = UserDefaults.standard.string(forKey: Key.tableColumnOrder), !raw.isEmpty else {
            return DownloadTableColumn.defaultDataColumnOrder.map(\.rawValue)
        }
        let stored = raw.split(separator: ",").map(String.init)
        return DownloadTableColumn.normalizedOrder(
            stored.compactMap(DownloadTableColumn.init(rawValue:))
        ).map(\.rawValue)
    }

    // MARK: - maxConcurrentDownloads

    var maxConcurrentDownloads: Int = {
        let val = UserDefaults.standard.integer(forKey: Key.maxConcurrentDownloads)
        return val == 0 ? 2 : val
    }() {
        didSet {
            UserDefaults.standard.set(maxConcurrentDownloads, forKey: Key.maxConcurrentDownloads)
            DownloadManager.shared.processQueue()
        }
    }

    var globalSpeedLimitBytesPerSecond: Int64 = {
        UserDefaults.standard.value(forKey: Key.globalSpeedLimitBytesPerSecond) as? Int64 ?? 0
    }() {
        didSet {
            UserDefaults.standard.set(globalSpeedLimitBytesPerSecond, forKey: Key.globalSpeedLimitBytesPerSecond)
            if !useCustomSpeedLimit {
                applyEffectiveSpeedLimit()
            }
        }
    }

    var launchAtLogin: Bool = {
        UserDefaults.standard.object(forKey: Key.launchAtLogin) as? Bool ?? true
    }() {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: Key.launchAtLogin)
            LaunchAtLoginManager.setEnabled(launchAtLogin)
        }
    }

    var startInBackground: Bool = {
        UserDefaults.standard.object(forKey: Key.startInBackground) as? Bool ?? true
    }() {
        didSet { UserDefaults.standard.set(startInBackground, forKey: Key.startInBackground) }
    }

    var showMenuBarIcon: Bool {
        didSet {
            UserDefaults.standard.set(showMenuBarIcon, forKey: Key.showMenuBarIcon)
            if !showMenuBarIcon { hideDockWhenInBackground = false }
            BackgroundAppManager.shared.applyActivationPolicy()
        }
    }

    var hideDockWhenInBackground: Bool {
        didSet {
            UserDefaults.standard.set(hideDockWhenInBackground, forKey: Key.hideDockWhenInBackground)
            BackgroundAppManager.shared.applyActivationPolicy()
        }
    }
}

