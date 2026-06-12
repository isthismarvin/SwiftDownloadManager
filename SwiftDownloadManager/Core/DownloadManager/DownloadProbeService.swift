import Foundation
import os

enum DownloadProbeOutcome: Sendable {
    case success(HTTPHeaderHelper.HEADResult)
    /// Server responded but HEAD/Range did not yield size info — download may still work.
    case inconclusive
    /// DNS, timeout, or no connectivity — do not start the engine.
    case networkError(Error)
}

enum DownloadProbeService {
    private static let logger = Logger(subsystem: "nrw.marvin.SwiftDownloadManager", category: "Probe")

    static func probe(url: URL, headers: [String: String] = [:]) async -> DownloadProbeOutcome {
        var lastNetworkError: Error?

        switch await performHEAD(url: url, headers: headers) {
        case .success(let result) where result.contentLength > 0 || result.supportsResume:
            logger.info("HEAD probe succeeded for \(url.absoluteString, privacy: .public)")
            return .success(result)
        case .networkError(let error):
            lastNetworkError = error
        case .success, .inconclusive:
            break
        }

        switch await performRangeProbe(url: url, headers: headers) {
        case .success(let result):
            logger.info("Range probe succeeded for \(url.absoluteString, privacy: .public)")
            return .success(result)
        case .networkError(let error):
            lastNetworkError = error
        case .inconclusive:
            break
        }

        if let lastNetworkError {
            logger.error("Network unreachable for \(url.absoluteString, privacy: .public): \(lastNetworkError.localizedDescription, privacy: .public)")
            return .networkError(lastNetworkError)
        }

        logger.warning("Probe inconclusive for \(url.absoluteString, privacy: .public) — proceeding with unknown size")
        return .inconclusive
    }

    private enum ProbeAttempt {
        case success(HTTPHeaderHelper.HEADResult)
        case inconclusive
        case networkError(Error)
    }

    private static func performHEAD(url: URL, headers: [String: String]) async -> ProbeAttempt {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = TimeInterval(AppSettings.shared.probeTimeoutSeconds)
        RequestHeadersHelper.applying(headers, to: &request)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return .inconclusive }
            return .success(HTTPHeaderHelper.parseHEADResponse(httpResponse))
        } catch {
            if isNetworkError(error) {
                logger.error("HEAD network error: \(error.localizedDescription, privacy: .public)")
                return .networkError(error)
            }
            logger.warning("HEAD failed (non-network): \(error.localizedDescription, privacy: .public)")
            return .inconclusive
        }
    }

    private static func performRangeProbe(url: URL, headers: [String: String]) async -> ProbeAttempt {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("bytes=0-0", forHTTPHeaderField: "Range")
        request.timeoutInterval = TimeInterval(AppSettings.shared.probeTimeoutSeconds)
        RequestHeadersHelper.applying(headers, to: &request)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return .inconclusive }

            var result = HTTPHeaderHelper.parseHEADResponse(httpResponse)
            if httpResponse.statusCode == 206,
               let contentRange = httpResponse.value(forHTTPHeaderField: "Content-Range"),
               let total = contentRange.split(separator: "/").last,
               let totalSize = Int64(total) {
                result.contentLength = totalSize
                result.supportsResume = true
            }
            return .success(result)
        } catch {
            if isNetworkError(error) {
                logger.error("Range probe network error: \(error.localizedDescription, privacy: .public)")
                return .networkError(error)
            }
            logger.warning("Range probe failed (non-network): \(error.localizedDescription, privacy: .public)")
            return .inconclusive
        }
    }

    private static func isNetworkError(_ error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else { return false }
        switch nsError.code {
        case NSURLErrorNotConnectedToInternet,
             NSURLErrorCannotFindHost,
             NSURLErrorDNSLookupFailed,
             NSURLErrorTimedOut,
             NSURLErrorNetworkConnectionLost,
             NSURLErrorCannotConnectToHost,
             NSURLErrorSecureConnectionFailed,
             NSURLErrorInternationalRoamingOff,
             NSURLErrorDataNotAllowed:
            return true
        default:
            return false
        }
    }
}
