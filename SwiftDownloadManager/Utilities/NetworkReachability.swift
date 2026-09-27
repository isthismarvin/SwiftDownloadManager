import Foundation
import Network
import os

/// Network interface and path monitor that notifies the app when connectivity transitions.
@MainActor
final class NetworkReachability: @unchecked Sendable {
    static let shared = NetworkReachability()
    private static let logger = Logger(subsystem: "nrw.marvin.SwiftDownloadManager", category: "NetworkReachability")

    private let monitor = NWPathMonitor()
    private var isOnWiFi = true
    private var isConnected = true
    private var hasObservedFirstState = false

    private init() {
        monitor.pathUpdateHandler = { path in
            Task { @MainActor in
                NetworkReachability.shared.handlePathUpdate(path)
            }
        }
        monitor.start(queue: DispatchQueue(label: "nrw.marvin.SwiftDownloadManager.NetworkReachability"))
    }

    private func handlePathUpdate(_ path: NWPath) {
        let currentlyConnected = path.status == .satisfied
        let wifiOrEthernet = path.usesInterfaceType(.wifi) || path.usesInterfaceType(.wiredEthernet)
        isOnWiFi = wifiOrEthernet

        if !hasObservedFirstState {
            isConnected = currentlyConnected
            hasObservedFirstState = true
            return
        }

        if !isConnected && currentlyConnected {
            Self.logger.info("Network connectivity restored")
            isConnected = true
            DownloadManager.shared.handleNetworkRestored()
        } else if isConnected && !currentlyConnected {
            Self.logger.warning("Network connectivity lost")
            isConnected = false
        }
    }

    var prefersWiFiAvailable: Bool { isOnWiFi }
    var isNetworkAvailable: Bool { isConnected }
}
