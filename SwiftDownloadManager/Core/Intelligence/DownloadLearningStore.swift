import Foundation

struct HostLearningRecord: Codable, Equatable {
    var saveDirectoryPath: String?
    var saveDirectoryBookmark: Data?
    var downloadCount: Int = 0
    var lastCategoryRaw: String?
    var lastPostDownloadActionRaw: String?
}

struct ExtensionLearningRule: Codable, Equatable {
    var postDownloadActionRaw: String
}

/// Persists learned preferences (host folders, counts, file-type actions).
enum DownloadLearningStore {
    private static let hostsKey = "intelligence.hostPreferences"
    private static let extensionsKey = "intelligence.extensionRules"

    static func hostRecord(for host: String) -> HostLearningRecord? {
        allHostRecords()[normalize(host)]
    }

    static func recordDownload(
        host: String,
        saveDirectoryPath: String?,
        saveDirectoryBookmark: Data?,
        category: LibraryCategory?,
        postDownloadAction: PostDownloadAction
    ) {
        let key = normalize(host)
        guard !key.isEmpty else { return }

        var records = allHostRecords()
        var record = records[key] ?? HostLearningRecord()
        record.downloadCount += 1
        if let saveDirectoryPath {
            record.saveDirectoryPath = saveDirectoryPath
            record.saveDirectoryBookmark = saveDirectoryBookmark
        }
        if let category {
            record.lastCategoryRaw = category.rawValue
        }
        if postDownloadAction != .none {
            record.lastPostDownloadActionRaw = postDownloadAction.rawValue
        }
        records[key] = record
        saveHostRecords(records)
    }

    static func suggestedSaveDirectory(for host: String) -> URL? {
        guard let record = hostRecord(for: host) else { return nil }
        if let bookmark = record.saveDirectoryBookmark,
           let url = BookmarkHelper.resolveBookmark(bookmark) {
            defer { BookmarkHelper.stopAccessing(url) }
            return url.resolvingSymlinksInPath()
        }
        if let path = record.saveDirectoryPath {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return nil
    }

    static func suggestedCategory(for host: String) -> LibraryCategory? {
        guard let raw = hostRecord(for: host)?.lastCategoryRaw else { return nil }
        return LibraryCategory(rawValue: raw)
    }

    static func suggestedPostDownloadAction(for host: String) -> PostDownloadAction? {
        guard let raw = hostRecord(for: host)?.lastPostDownloadActionRaw else { return nil }
        return PostDownloadAction(rawValue: raw)
    }

    static func extensionRule(for fileExtension: String) -> ExtensionLearningRule? {
        let key = fileExtension.lowercased()
        guard !key.isEmpty else { return nil }
        return allExtensionRules()[key]
    }

    static func setExtensionRule(fileExtension: String, action: PostDownloadAction) {
        let key = fileExtension.lowercased()
        guard !key.isEmpty, action != .none else { return }
        var rules = allExtensionRules()
        rules[key] = ExtensionLearningRule(postDownloadActionRaw: action.rawValue)
        saveExtensionRules(rules)
    }

    static func recommendedPostDownloadAction(for fileName: String) -> PostDownloadAction? {
        let ext = URL(fileURLWithPath: fileName).pathExtension.lowercased()
        if let rule = extensionRule(for: ext),
           let action = PostDownloadAction(rawValue: rule.postDownloadActionRaw) {
            return action
        }
        if ["zip", "gz", "tar", "bz2", "xz", "7z", "rar", "tgz", "tbz2", "cab"].contains(ext) {
            return .extractArchive
        }
        if ["dmg", "pkg", "app"].contains(ext) {
            return .openFile
        }
        return nil
    }

    static func clearAll() {
        UserDefaults.standard.removeObject(forKey: hostsKey)
        UserDefaults.standard.removeObject(forKey: extensionsKey)
    }

    static func allHostsSorted() -> [(host: String, record: HostLearningRecord)] {
        allHostRecords()
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
            .map { (host: $0.key, record: $0.value) }
    }

    static func allExtensionsSorted() -> [(ext: String, rule: ExtensionLearningRule)] {
        allExtensionRules()
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
            .map { (ext: $0.key, rule: $0.value) }
    }

    static func removeHost(_ host: String) {
        let key = normalize(host)
        guard !key.isEmpty else { return }
        var records = allHostRecords()
        records.removeValue(forKey: key)
        saveHostRecords(records)
    }

    static func removeExtension(_ fileExtension: String) {
        let key = fileExtension.lowercased()
        guard !key.isEmpty else { return }
        var rules = allExtensionRules()
        rules.removeValue(forKey: key)
        saveExtensionRules(rules)
    }

    static func clearHostRecords() {
        UserDefaults.standard.removeObject(forKey: hostsKey)
    }

    static func clearExtensionRules() {
        UserDefaults.standard.removeObject(forKey: extensionsKey)
    }

    private static func normalize(_ host: String) -> String {
        DomainRuleStore.normalize(host)
    }

    private static func allHostRecords() -> [String: HostLearningRecord] {
        guard let data = UserDefaults.standard.data(forKey: hostsKey),
              let decoded = try? JSONDecoder().decode([String: HostLearningRecord].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private static func saveHostRecords(_ records: [String: HostLearningRecord]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: hostsKey)
    }

    private static func allExtensionRules() -> [String: ExtensionLearningRule] {
        guard let data = UserDefaults.standard.data(forKey: extensionsKey),
              let decoded = try? JSONDecoder().decode([String: ExtensionLearningRule].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private static func saveExtensionRules(_ rules: [String: ExtensionLearningRule]) {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        UserDefaults.standard.set(data, forKey: extensionsKey)
    }
}
