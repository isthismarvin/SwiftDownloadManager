import Foundation

struct ByteFormatter {
    /// Formatiert Bytes im Stil "1.2 GB" / "652.1 MB" (Dezimalpunkt, eine Nachkommastelle).
    static func format(_ bytes: Int64) -> String {
        guard bytes >= 0 else { return "Unknown" }
        let value = Double(bytes)
        guard value >= 1000 else { return "\(bytes) B" }

        let units = ["KB", "MB", "GB", "TB"]
        var scaled = value
        var unitIndex = -1
        while scaled >= 1000 && unitIndex < units.count - 1 {
            scaled /= 1000
            unitIndex += 1
        }
        return String(format: "%.1f %@", locale: Locale(identifier: "en_US"), scaled, units[unitIndex])
    }
}
