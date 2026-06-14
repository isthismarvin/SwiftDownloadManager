import SwiftUI

enum AppTheme {
    static let cornerRadius: CGFloat = 12
    static let smallCornerRadius: CGFloat = 6
    static let separatorOpacity: Double = 0.08
    static let primarySubtleOpacity: Double = 0.03
    static let hoverBackgroundOpacity: Double = 0.045
    static let selectedRowBackgroundOpacity: Double = 0.1
    static let inspectorExpandedHeightDefault: CGFloat = 320
    static let inspectorExpandedHeightMin: CGFloat = 200
    static let inspectorExpandedHeightMax: CGFloat = 480
    static let inspectorCollapsedHeight: CGFloat = 40
    static let inspectorSpring = Animation.spring(response: 0.38, dampingFraction: 0.84)
    static let rowHeight: CGFloat = 60

    static let contentPadding: CGFloat = 16
    static let compactPadding: CGFloat = 8
    static let dialogPadding: CGFloat = 20
    static let dialogWidth: CGFloat = 520
    static let dialogWidthWide: CGFloat = 620
    static let sectionSpacing: CGFloat = 12
    static let itemSpacing: CGFloat = 10

    static var separatorColor: Color {
        Color.primary.opacity(separatorOpacity)
    }

    static var cardBackground: Color {
        Color(nsColor: .controlBackgroundColor)
    }

    static var subtleBackground: Color {
        cardBackground.opacity(0.65)
    }

    static var hoverBackground: Color {
        Color.primary.opacity(hoverBackgroundOpacity)
    }

    static var selectedRowBackground: Color {
        Color.accentColor.opacity(selectedRowBackgroundOpacity)
    }

    static var tableHeaderBackground: Color {
        Color.primary.opacity(0.06)
    }

    static var tableHeaderBorder: Color {
        Color.primary.opacity(0.1)
    }
}

// MARK: - Liquid Glass Policy

/// Where Liquid Glass is allowed in this app (Apple HIG: navigation and floating controls, not content).
enum FloatingGlassLayer {
    /// Toolbar, sidebar footer, floating bars.
    case navigation
    /// Hover actions, selection bar, tab pills.
    case floatingControl
    /// Banners, popover chrome.
    case emphasisOverlay
    /// Settings cells, table content, badges — no glass.
    case content
}

// MARK: - Liquid Glass

extension View {
    /// Grouped card surface for settings and panels.
    func appGlassCard(cornerRadius: CGFloat = AppTheme.cornerRadius) -> some View {
        glassEffect(
            .regular,
            in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        )
    }

    /// Floating control cluster (e.g. row hover actions).
    func appGlassCapsule(interactive: Bool = true) -> some View {
        glassEffect(
            interactive ? .regular.interactive() : .regular,
            in: Capsule()
        )
    }

    /// Emphasis banner with tint.
    func appGlassBanner(tint: Color) -> some View {
        glassEffect(
            .regular.tint(tint),
            in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
        )
    }

    /// Compact chip (badges, counts, tags).
    func appGlassChip(tint: Color? = nil, interactive: Bool = false) -> some View {
        glassEffect(glassVariant(tint: tint, interactive: interactive), in: Capsule())
    }

    /// Segmented pill (tabs, preset buttons).
    func appGlassPill(isSelected: Bool, tint: Color = .accentColor) -> some View {
        glassEffect(
            isSelected ? .regular.tint(tint).interactive() : .regular.interactive(),
            in: Capsule()
        )
    }

    /// Small rounded control (speed presets, compact toggles).
    func appGlassRounded(isSelected: Bool, tint: Color = .accentColor) -> some View {
        glassEffect(
            isSelected ? .regular.tint(tint).interactive() : .regular.interactive(),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
    }

    /// Interactive list/card row surface.
    func appGlassRow(isHighlighted: Bool) -> some View {
        glassEffect(
            isHighlighted ? .regular.interactive() : .regular,
            in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous)
        )
    }

    private func glassVariant(tint: Color?, interactive: Bool) -> Glass {
        var glass: Glass = .regular
        if let tint { glass = glass.tint(tint) }
        if interactive { glass = glass.interactive() }
        return glass
    }
}

// MARK: - Typography

extension View {
    func appCaptionStyle() -> some View {
        font(.system(size: 12))
            .foregroundStyle(.secondary)
    }

    func appBodyStyle() -> some View {
        font(.system(size: 13))
    }

    func appHeadlineStyle() -> some View {
        font(.system(size: 13, weight: .medium))
    }

    func appInspectorLabelStyle() -> some View {
        font(.system(size: 12))
            .foregroundStyle(.secondary)
    }

    func appInspectorValueStyle() -> some View {
        font(.system(size: 12))
    }
}

/// Per-column widths for the download table.
/// Each value is the **total** column width including the 10 pt leading gap.
/// The resize handle is an overlay at the trailing edge, so it doesn't add
/// to the layout width.
struct ColumnWidths {
    var date: CGFloat = 108
    var progress: CGFloat = 160
    var speed: CGFloat = 90
    /// Status is icon-only, so it only needs a small footprint.
    var status: CGFloat = 36
    var size: CGFloat = 80
    var eta: CGFloat = 75

    static let `default` = ColumnWidths()
    static let minWidth: CGFloat = 36
}

/// 1 pt separator with an 8 pt transparent interaction zone overlaid at the
/// trailing edge of a column header. Drag right → column grows; drag left →
/// column shrinks. The divider stays at the column's right edge, so it moves
/// in the same direction as the drag gesture.
struct ResizableDivider: View {
    @Binding var width: CGFloat
    var minWidth: CGFloat = ColumnWidths.minWidth

    @State private var dragStartWidth: CGFloat? = nil

    var body: some View {
        ZStack {
            Rectangle()
                .fill(AppTheme.separatorColor)
                .frame(width: 1)

            Color.clear
                .frame(width: 8)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            if dragStartWidth == nil { dragStartWidth = width }
                            width = Swift.max(
                                minWidth,
                                (dragStartWidth ?? width) + value.translation.width
                            )
                        }
                        .onEnded { _ in
                            dragStartWidth = nil
                        }
                )
                .onHover { hovering in
                    if hovering { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
                }
        }
    }
}
