import AppKit
import SwiftUI

/// App icon + title for toolbars and branded headers.
struct AppBrandHeader: View {
    var iconSize: CGFloat = 28
    var titleFont: Font = .headline
    var leadingPadding: CGFloat = 16
    var trailingPadding: CGFloat = 16
    var spacing: CGFloat = 10

    private var appIcon: NSImage {
        NSApp.applicationIconImage ?? NSImage(named: NSImage.applicationIconName) ?? NSImage()
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            brandedHeader(showTitle: true)
            brandedHeader(showTitle: false)
        }
    }

    private func brandedHeader(showTitle: Bool) -> some View {
        HStack(spacing: spacing) {
            Image(nsImage: appIcon)
                .resizable()
                .interpolation(.high)
                .frame(width: iconSize, height: iconSize)
                .clipShape(RoundedRectangle(cornerRadius: iconSize * 0.22, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 0.5, y: 0.5)

            if showTitle {
                Text(L10n.t(de: "Swift Download Manager", en: "Swift Download Manager"))
                    .font(titleFont)
                    .lineLimit(1)
            }
        }
        .foregroundStyle(.primary)
        .padding(.leading, leadingPadding)
        .padding(.trailing, trailingPadding)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.t(de: "Swift Download Manager", en: "Swift Download Manager"))
    }
}
