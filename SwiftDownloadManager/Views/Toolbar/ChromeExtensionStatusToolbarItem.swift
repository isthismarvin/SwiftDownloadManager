import SwiftUI

struct ChromeExtensionStatusIcon: View {
    @Bindable private var httpServer = LocalHTTPServer.shared

    var body: some View {
        Image(systemName: "puzzlepiece.extension")
            .font(.system(size: 15))
            .foregroundStyle(iconColor(for: connectionState))
            .help(statusHelp(for: connectionState))
            .accessibilityLabel(L10n.t(de: "Chrome Extension", en: "Chrome Extension"))
            .accessibilityValue(accessibilityStatus(for: connectionState))
    }

    private var connectionState: ChromeExtensionConnectionState {
        guard httpServer.isListening else { return .disconnected }
        return httpServer.extensionConnectionState
    }

    private func iconColor(for state: ChromeExtensionConnectionState) -> Color {
        switch state {
        case .searching:
            return .yellow
        case .connected:
            return .green
        case .disconnected:
            return .red
        }
    }

    private func statusHelp(for state: ChromeExtensionConnectionState) -> String {
        switch state {
        case .searching:
            return L10n.t(
                de: "Chrome Extension wird gesucht (max. 30 Sekunden)…",
                en: "Searching for Chrome extension (up to 30 seconds)…"
            )
        case .connected:
            return L10n.t(
                de: "Chrome Extension verbunden (localhost:\(LocalHTTPServer.port))",
                en: "Chrome extension connected (localhost:\(LocalHTTPServer.port))"
            )
        case .disconnected:
            return L10n.t(
                de: "Chrome Extension nicht verbunden",
                en: "Chrome extension not connected"
            )
        }
    }

    private func accessibilityStatus(for state: ChromeExtensionConnectionState) -> String {
        switch state {
        case .searching:
            return L10n.t(de: "Suche läuft", en: "Searching")
        case .connected:
            return L10n.t(de: "Verbunden", en: "Connected")
        case .disconnected:
            return L10n.t(de: "Nicht verbunden", en: "Not connected")
        }
    }
}
