import Foundation
import Network

/// Lightweight Wi-Fi / interface check for scheduled downloads.
@MainActor
final class NetworkReachability: @unchecked Sendable {
    static let shared = NetworkReachability()

    private let monitor = NWPathMonitor()
    private var isOnWiFi = true

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isOnWiFi = path.usesInterfaceType(.wifi) || path.usesInterfaceType(.wiredEthernet)
            }
        }
        monitor.start(queue: DispatchQueue(label: "nrw.marvin.SwiftDownloadManager.NetworkReachability"))
    }

    var prefersWiFiAvailable: Bool { isOnWiFi }
}
