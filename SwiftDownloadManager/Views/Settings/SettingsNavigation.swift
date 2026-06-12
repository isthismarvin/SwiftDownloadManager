import Foundation

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
    static let openSettingsSection = Notification.Name("openSettingsSection")
}

@MainActor
enum SettingsNavigation {
    static func open(to section: SettingsSection? = nil) {
        NotificationCenter.default.post(name: .openSettings, object: section)
    }
}
