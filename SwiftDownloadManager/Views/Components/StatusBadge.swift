import SwiftUI

struct StatusBadgeInfo {
    let label: String
    /// SF Symbol name for the icon shown in the table row.
    let icon: String
    let color: Color
}

/// Icon-only status indicator. The text label is shown as a tooltip so the
/// column stays compact. Mirrors the symbol style used in the sidebar.
struct StatusBadge: View {
    let info: StatusBadgeInfo

    var body: some View {
        Image(systemName: info.icon)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(info.color)
            .frame(width: 22, height: 22)
            .background(info.color.opacity(0.15), in: Circle())
            .help(info.label)
            .accessibilityLabel(info.label)
    }
}
