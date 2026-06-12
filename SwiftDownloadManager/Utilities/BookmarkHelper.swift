import Foundation
import os

enum BookmarkHelper {
    private static let logger = Logger(subsystem: "nrw.marvin.SwiftDownloadManager", category: "Bookmarks")

    static func createBookmark(for url: URL) -> Data? {
        createFileBookmark(for: url)
    }

    static func createFileBookmark(for url: URL) -> Data? {
        do {
            return try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: [.fileResourceIdentifierKey],
                relativeTo: nil
            )
        } catch {
            logger.error("Failed to create file bookmark: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Resolves a security-scoped bookmark and STARTS accessing the resource.
    /// The caller owns the scope and must call
    /// `stopAccessingSecurityScopedResource()` on the returned URL when done.
    static func resolveBookmark(_ data: Data) -> URL? {
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            if isStale {
                return nil
            }
            _ = url.startAccessingSecurityScopedResource()
            return url
        } catch {
            logger.error("Failed to resolve bookmark: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    static func stopAccessing(_ url: URL?) {
        url?.stopAccessingSecurityScopedResource()
    }

    /// Resolves a file bookmark and starts security-scoped access when needed.
    static func resolveFileBookmark(_ data: Data) -> (url: URL, isStale: Bool)? {
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope, .withoutImplicitStartAccessing],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            _ = url.startAccessingSecurityScopedResource()
            return (url, isStale)
        } catch {
            logger.error("Failed to resolve file bookmark: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}
