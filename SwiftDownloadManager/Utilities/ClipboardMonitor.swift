import AppKit
import Foundation
import os

/// IDM-style Clipboard Monitor: watches NSPasteboard.general for copied URLs
/// matching downloadable file types and prompts for download.
@MainActor
final class ClipboardMonitor {
    static let shared = ClipboardMonitor()

    private let logger = Logger(subsystem: "nrw.marvin.SwiftDownloadManager", category: "ClipboardMonitor")
    private var timer: Timer?
    private var lastChangeCount: Int = -1
    private var lastCapturedURLString: String?

    /// Common downloadable file extensions captured automatically (IDM style).
    static let downloadableExtensions: Set<String> = [
        // Compressed archives
        "zip", "rar", "7z", "tar", "gz", "tgz", "bz2", "tbz2", "xz", "iso", "dmg", "pkg", "deb", "rpm", "7zip", "zst",
        // Media (video/audio)
        "mp4", "mkv", "avi", "mov", "wmv", "flv", "webm", "m4v", "ts",
        "mp3", "flac", "wav", "aac", "ogg", "m4a", "opus", "wma",
        // Documents
        "pdf", "epub", "mobi", "djvu", "doc", "docx", "xls", "xlsx", "ppt", "pptx",
        // Disk images & Executables & Binaries
        "exe", "msi", "bin", "apk", "ipa", "appimage", "run"
    ]

    private init() {}

    func start() {
        guard timer == nil else { return }
        lastChangeCount = NSPasteboard.general.changeCount
        // Poll pasteboard periodically when app is running
        timer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkPasteboard()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func checkPasteboard() {
        guard AppSettings.shared.clipboardMonitoringEnabled else { return }

        let currentChangeCount = NSPasteboard.general.changeCount
        guard currentChangeCount != lastChangeCount else { return }
        lastChangeCount = currentChangeCount

        guard let rawString = NSPasteboard.general.string(forType: .string) else { return }
        let trimmed = rawString.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty, trimmed != lastCapturedURLString else { return }

        guard let candidateURL = Self.extractDownloadableURL(from: trimmed) else { return }

        lastCapturedURLString = trimmed
        logger.info("Captured downloadable URL from clipboard: \(candidateURL.absoluteString, privacy: .public)")

        let manager = DownloadManager.shared
        guard manager.modelContext != nil else { return }
        _ = manager.receiveDownload(url: candidateURL, source: .paste)
    }

    nonisolated static func extractDownloadableURL(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return nil
        }

        let ext = url.pathExtension.lowercased()
        if downloadableExtensions.contains(ext) {
            return url
        }

        let pathWithoutQuery = url.path.lowercased()
        for extCandidate in downloadableExtensions {
            if pathWithoutQuery.hasSuffix("." + extCandidate) {
                return url
            }
        }

        return nil
    }
}
