import Foundation
import Network
import Observation
import os

/// Tracks whether the Chrome companion extension has contacted the local server.
enum ChromeExtensionConnectionState: Equatable {
    /// Server is up; waiting up to 30s for the extension to ping.
    case searching
    /// Extension responded via `/ping` or `/add`.
    case connected
    /// Server down, search timed out, or extension unreachable.
    case disconnected
}

/// Minimal loopback-only HTTP server used by the Chrome extension companion.
///
/// Endpoints:
/// - `GET /ping`  -> `{"status":"ok","app":"SwiftDownloadManager"}`
/// - `POST /add`  -> body `{"url":"https://...","filename":"optional"}`,
///                   receives the URL via `DownloadManager.receiveDownload`
///                   (confirmation dialog before the queue starts).
///
/// The listener binds exclusively to 127.0.0.1, so nothing outside this
/// machine can reach it.
@Observable
final class LocalHTTPServer: @unchecked Sendable {
    static let shared = LocalHTTPServer()

    static let port: UInt16 = 6789
    static let extensionSearchTimeout: TimeInterval = 30
    static let extensionStalenessTimeout: TimeInterval = 45

    @MainActor private(set) var isListening = false
    @MainActor private(set) var extensionConnectionState: ChromeExtensionConnectionState = .disconnected
    @MainActor private(set) var lastExtensionContactAt: Date?

    private let logger = Logger(subsystem: "nrw.marvin.SwiftDownloadManager", category: "LocalHTTPServer")
    private let queue = DispatchQueue(label: "nrw.marvin.SwiftDownloadManager.LocalHTTPServer")
    private var listener: NWListener?
    @MainActor private var extensionSearchTask: Task<Void, Never>?
    @MainActor private var extensionStalenessTask: Task<Void, Never>?

    private init() {}

    func start() {
        queue.async { [self] in
            guard listener == nil else { return }

            guard let port = NWEndpoint.Port(rawValue: Self.port) else {
                logger.error("Invalid port: \(Self.port)")
                return
            }

            let parameters = NWParameters.tcp
            // Bind to loopback only; the extension talks to localhost and the
            // server must never be reachable from other hosts.
            parameters.requiredLocalEndpoint = NWEndpoint.hostPort(
                host: .ipv4(.loopback),
                port: port
            )
            parameters.allowLocalEndpointReuse = true

            do {
                let listener = try NWListener(using: parameters)
                listener.newConnectionHandler = { [weak self] connection in
                    self?.handle(connection: connection)
                }
                listener.stateUpdateHandler = { [logger] state in
                    switch state {
                    case .ready:
                        logger.info("Listening on 127.0.0.1:\(Self.port)")
                        Task { @MainActor in
                            LocalHTTPServer.shared.isListening = true
                            LocalHTTPServer.shared.beginExtensionSearch()
                        }
                    case .failed(let error):
                        logger.error("Listener failed: \(error.localizedDescription)")
                        Task { @MainActor in
                            LocalHTTPServer.shared.setServerOffline()
                        }
                    default:
                        break
                    }
                }
                listener.start(queue: queue)
                self.listener = listener
            } catch {
                logger.error("Could not start listener: \(error.localizedDescription)")
            }
        }
    }

    func stop() {
        queue.async { [self] in
            listener?.cancel()
            listener = nil
            Task { @MainActor in
                LocalHTTPServer.shared.setServerOffline()
            }
        }
    }

    @MainActor
    func beginExtensionSearch() {
        extensionSearchTask?.cancel()
        extensionConnectionState = .searching
        extensionSearchTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.extensionSearchTimeout))
            guard !Task.isCancelled else { return }
            if extensionConnectionState == .searching {
                extensionConnectionState = .disconnected
            }
        }
    }

    @MainActor
    func recordExtensionContact() {
        extensionSearchTask?.cancel()
        lastExtensionContactAt = Date()
        extensionConnectionState = .connected
        scheduleExtensionStalenessCheck()
    }

    @MainActor
    func setServerOffline() {
        extensionSearchTask?.cancel()
        extensionStalenessTask?.cancel()
        isListening = false
        lastExtensionContactAt = nil
        extensionConnectionState = .disconnected
    }

    @MainActor
    private func scheduleExtensionStalenessCheck() {
        extensionStalenessTask?.cancel()
        extensionStalenessTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.extensionStalenessTimeout))
            guard !Task.isCancelled else { return }
            guard extensionConnectionState == .connected else { return }
            guard let lastContact = lastExtensionContactAt else {
                extensionConnectionState = .disconnected
                return
            }
            if Date().timeIntervalSince(lastContact) >= Self.extensionStalenessTimeout {
                extensionConnectionState = .disconnected
            } else {
                scheduleExtensionStalenessCheck()
            }
        }
    }

    @MainActor
    private func markExtensionContactFromNetworkThread() {
        recordExtensionContact()
    }

    // MARK: - Connection handling

    private func handle(connection: NWConnection) {
        connection.start(queue: queue)
        receiveRequest(on: connection, buffer: Data())
    }

    private func receiveRequest(on connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }

            var buffer = buffer
            if let data { buffer.append(data) }

            if error != nil {
                connection.cancel()
                return
            }

            // Wait until the full head (and body, per Content-Length) arrived.
            if let request = HTTPRequestParser.parse(data: buffer) {
                self.respond(to: request, on: connection)
            } else if isComplete || buffer.count > 1024 * 1024 {
                self.send(status: "400 Bad Request", json: ["error": "malformed request"], on: connection)
            } else {
                self.receiveRequest(on: connection, buffer: buffer)
            }
        }
    }

    private func respond(to request: HTTPRequestParser.ParsedRequest, on connection: NWConnection) {
        switch (request.method, request.path) {
        case ("OPTIONS", _):
            send(status: "204 No Content", json: nil, on: connection)
        case ("GET", "/ping"):
            DispatchQueue.main.async {
                LocalHTTPServer.shared.markExtensionContactFromNetworkThread()
            }
            send(status: "200 OK", json: ["status": "ok", "app": "SwiftDownloadManager"], on: connection)
        case ("POST", "/add"):
            handleAdd(body: request.body, on: connection)
        default:
            send(status: "404 Not Found", json: ["error": "not found"], on: connection)
        }
    }

    private func handleAdd(body: Data, on connection: NWConnection) {
        guard
            let payload = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
            let urlString = payload["url"] as? String
        else {
            send(status: "400 Bad Request", json: ["error": "missing url"], on: connection)
            return
        }

        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            let url = URL(string: trimmed),
            let scheme = url.scheme?.lowercased(),
            scheme == "http" || scheme == "https"
        else {
            send(status: "400 Bad Request", json: ["error": "invalid url"], on: connection)
            return
        }

        let fileName = (payload["filename"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let referrer = payload["referrer"] as? String
        var headers: [String: String] = [:]
        if let rawHeaders = payload["headers"] as? [String: Any] {
            for (key, value) in rawHeaders {
                if let stringValue = value as? String {
                    headers[key] = stringValue
                }
            }
        }

        Task { @MainActor in
            LocalHTTPServer.shared.markExtensionContactFromNetworkThread()
            let manager = DownloadManager.shared
            guard manager.modelContext != nil else {
                self.send(status: "503 Service Unavailable", json: ["error": "app is still starting"], on: connection)
                return
            }
            let outcome = manager.receiveDownload(
                url: url,
                fileNameOverride: fileName,
                source: .chromeExtension,
                requestHeaders: headers,
                referrer: referrer
            )
            switch outcome {
            case .queued:
                self.send(status: "200 OK", json: ["added": true, "started": true], on: connection)
            case .awaitingConfirmation, .duplicateAwaitingConfirmation:
                self.send(status: "200 OK", json: ["added": true, "awaitingConfirmation": true], on: connection)
            case .blocked:
                self.send(status: "403 Forbidden", json: ["error": "domain blocked"], on: connection)
            case nil:
                self.send(status: "503 Service Unavailable", json: ["error": "could not enqueue download"], on: connection)
            }
        }
    }

    // MARK: - Response writing

    private func send(status: String, json: [String: Any]?, on connection: NWConnection) {
        var body = Data()
        if let json, let encoded = try? JSONSerialization.data(withJSONObject: json) {
            body = encoded
        }

        var head = "HTTP/1.1 \(status)\r\n"
        head += "Content-Type: application/json\r\n"
        head += "Content-Length: \(body.count)\r\n"
        head += "Access-Control-Allow-Origin: *\r\n"
        head += "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
        head += "Access-Control-Allow-Headers: Content-Type\r\n"
        head += "Connection: close\r\n"
        head += "\r\n"

        var response = Data(head.utf8)
        response.append(body)

        connection.send(content: response, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}
