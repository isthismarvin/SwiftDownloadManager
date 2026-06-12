import Foundation

/// In-app localization backed by `Localizable.xcstrings`, with inline
/// fallbacks via `t(de:en:)` during migration.
/// Reads the active language from `AppSettings.shared` on each call so
/// `@Observable` views refresh when the user changes language.
enum L10n {
    @MainActor
    static func catalog(_ key: String, default defaultValue: String) -> String {
        let locale = Locale(identifier: AppSettings.shared.resolvedLanguageCode)
        let resource = LocalizedStringResource(
            String.LocalizationValue(stringLiteral: key),
            locale: locale
        )
        let localized = String(localized: resource)
        if localized == key { return defaultValue }
        return localized
    }

    @MainActor
    static func t(de: String, en: String) -> String {
        AppSettings.shared.resolvedLanguageCode == "de" ? de : en
    }

    /// Formats a date for list/inspector display (Today/Yesterday or abbreviated).
    @MainActor
    static func formatRelativeDateTime(_ date: Date) -> String {
        let time = date.formatted(date: .omitted, time: .shortened)
        if Calendar.current.isDateInToday(date) {
            return t(de: "Heute, \(time)", en: "Today, \(time)")
        }
        if Calendar.current.isDateInYesterday(date) {
            return t(de: "Gestern, \(time)", en: "Yesterday, \(time)")
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    @MainActor
    static var yes: String { catalog("yes", default: "Yes") }
    @MainActor
    static var no: String { catalog("no", default: "No") }
    @MainActor
    static var unknown: String { catalog("unknown", default: "Unknown") }
    @MainActor
    static var cancel: String { catalog("cancel", default: "Cancel") }
}
