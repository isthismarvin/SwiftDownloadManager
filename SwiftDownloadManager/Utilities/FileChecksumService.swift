import Foundation
import CryptoKit

enum FileChecksumService: Sendable {
    /// Computes SHA-256 for a file by streaming in 1 MB chunks to prevent high memory usage.
    static func computeSHA256(for fileURL: URL) async throws -> String {
        try await Task.detached(priority: .utility) {
            let handle = try FileHandle(forReadingFrom: fileURL)
            defer { try? handle.close() }

            var hasher = SHA256()
            let chunkSize = 1024 * 1024

            while let chunk = try handle.read(upToCount: chunkSize), !chunk.isEmpty {
                hasher.update(data: chunk)
            }

            let digest = hasher.finalize()
            return digest.map { String(format: "%02x", $0) }.joined()
        }.value
    }

    /// Computes MD5 for legacy checksum verification.
    static func computeMD5(for fileURL: URL) async throws -> String {
        try await Task.detached(priority: .utility) {
            let handle = try FileHandle(forReadingFrom: fileURL)
            defer { try? handle.close() }

            var hasher = Insecure.MD5()
            let chunkSize = 1024 * 1024

            while let chunk = try handle.read(upToCount: chunkSize), !chunk.isEmpty {
                hasher.update(data: chunk)
            }

            let digest = hasher.finalize()
            return digest.map { String(format: "%02x", $0) }.joined()
        }.value
    }
}
