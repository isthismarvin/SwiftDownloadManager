import Foundation
import SwiftData

@Model
final class DownloadItem: Identifiable {
    @Attribute(.unique) var id: UUID
    var urlString: String
    var fileName: String
    var statusRaw: String
    var bytesReceived: Int64
    var bytesTotal: Int64
    var localFilePath: String?
    var localFileBookmark: Data?
    var resumeDataPath: String?
    var supportsResume: Bool
    var createdAt: Date
    var completedAt: Date?
    var preferredSegmentsCount: Int
    var saveDirectoryPath: String?
    var saveDirectoryBookmark: Data?
    var libraryCategoryRaw: String?
    var errorMessage: String?
    var sourceRaw: String?
    var probeErrorMessage: String?
    var scheduledStartAt: Date?
    var postDownloadActionRaw: String?
    var requestHeadersJSON: String?
    var speedHistoryJSON: String?
    var referrerURLString: String?
    var holdInQueue: Bool = false
    var startWhenOnWiFi: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \DownloadSegment.downloadItem)
    var segments: [DownloadSegment] = []

    var folder: DownloadFolder?

    var libraryCategory: LibraryCategory? {
        get {
            guard let libraryCategoryRaw else { return nil }
            return LibraryCategory(rawValue: libraryCategoryRaw)
        }
        set {
            libraryCategoryRaw = newValue?.rawValue
        }
    }

    var status: DownloadStatus {
        get {
            DownloadStatus(rawValue: statusRaw) ?? .queued
        }
        set {
            statusRaw = newValue.rawValue
        }
    }

    var source: DownloadSource? {
        get {
            guard let sourceRaw else { return nil }
            return DownloadSource(rawValue: sourceRaw)
        }
        set {
            sourceRaw = newValue?.rawValue
        }
    }

    var postDownloadAction: PostDownloadAction {
        get {
            guard let postDownloadActionRaw else { return .none }
            return PostDownloadAction(rawValue: postDownloadActionRaw) ?? .none
        }
        set {
            postDownloadActionRaw = newValue == .none ? nil : newValue.rawValue
        }
    }

    var requestHeaders: [String: String] {
        RequestHeadersHelper.decode(requestHeadersJSON)
    }

    init(
        id: UUID = UUID(),
        urlString: String,
        fileName: String,
        status: DownloadStatus = .queued,
        bytesReceived: Int64 = 0,
        bytesTotal: Int64 = -1,
        localFilePath: String? = nil,
        localFileBookmark: Data? = nil,
        resumeDataPath: String? = nil,
        supportsResume: Bool = false,
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        preferredSegmentsCount: Int = 4,
        saveDirectoryPath: String? = nil,
        saveDirectoryBookmark: Data? = nil,
        libraryCategory: LibraryCategory? = nil,
        errorMessage: String? = nil,
        folder: DownloadFolder? = nil,
        source: DownloadSource? = nil,
        probeErrorMessage: String? = nil,
        scheduledStartAt: Date? = nil,
        postDownloadAction: PostDownloadAction = .none,
        requestHeadersJSON: String? = nil,
        speedHistoryJSON: String? = nil,
        referrerURLString: String? = nil,
        holdInQueue: Bool = false,
        startWhenOnWiFi: Bool = false
    ) {
        self.id = id
        self.urlString = urlString
        self.fileName = fileName
        self.statusRaw = status.rawValue
        self.bytesReceived = bytesReceived
        self.bytesTotal = bytesTotal
        self.localFilePath = localFilePath
        self.localFileBookmark = localFileBookmark
        self.resumeDataPath = resumeDataPath
        self.supportsResume = supportsResume
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.preferredSegmentsCount = preferredSegmentsCount
        self.saveDirectoryPath = saveDirectoryPath
        self.saveDirectoryBookmark = saveDirectoryBookmark
        self.libraryCategoryRaw = libraryCategory?.rawValue
        self.errorMessage = errorMessage
        self.folder = folder
        self.sourceRaw = source?.rawValue
        self.probeErrorMessage = probeErrorMessage
        self.scheduledStartAt = scheduledStartAt
        self.postDownloadActionRaw = postDownloadAction == .none ? nil : postDownloadAction.rawValue
        self.requestHeadersJSON = requestHeadersJSON
        self.speedHistoryJSON = speedHistoryJSON
        self.referrerURLString = referrerURLString
        self.holdInQueue = holdInQueue
        self.startWhenOnWiFi = startWhenOnWiFi
    }
}
