import AppKit
import Foundation

/// Renders a native progress bar overlay across the macOS Dock icon.
final class DockProgressTileView: NSView {
    var progress: Double = 0.0 {
        didSet { needsDisplay = true }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Draw standard app icon base
        if let icon = NSApp.applicationIconImage {
            icon.draw(in: bounds)
        }

        guard progress > 0.0 && progress < 1.0 else { return }

        // Draw progress capsule on bottom
        let barHeight: CGFloat = 16
        let padding: CGFloat = 12
        let barRect = NSRect(
            x: padding,
            y: padding + 4,
            width: bounds.width - (padding * 2),
            height: barHeight
        )

        // Background track
        let trackPath = NSBezierPath(roundedRect: barRect, xRadius: barHeight / 2, yRadius: barHeight / 2)
        NSColor.black.withAlphaComponent(0.65).setFill()
        trackPath.fill()

        // Border outline
        NSColor.white.withAlphaComponent(0.25).setStroke()
        trackPath.lineWidth = 1
        trackPath.stroke()

        // Fill progress
        let innerPadding: CGFloat = 2
        let maxFillWidth = barRect.width - (innerPadding * 2)
        let fillWidth = max(barHeight - (innerPadding * 2), maxFillWidth * CGFloat(progress))
        let fillRect = NSRect(
            x: barRect.minX + innerPadding,
            y: barRect.minY + innerPadding,
            width: min(fillWidth, maxFillWidth),
            height: barHeight - (innerPadding * 2)
        )
        let fillPath = NSBezierPath(
            roundedRect: fillRect,
            xRadius: (barHeight - (innerPadding * 2)) / 2,
            yRadius: (barHeight - (innerPadding * 2)) / 2
        )
        NSColor.systemBlue.setFill()
        fillPath.fill()
    }
}

/// Orchestrates Dock badge text and visual progress bar updates.
@MainActor
final class DockProgressManager {
    static let shared = DockProgressManager()

    private lazy var tileView = DockProgressTileView()

    private init() {}

    /// Updates the Dock icon's badge and progress bar based on active download metrics.
    func update(activeCount: Int, totalSpeedBytesPerSecond: Double = 0, overallProgress: Double? = nil) {
        let dockTile = NSApp.dockTile
        let settings = AppSettings.shared

        guard settings.showDockBadge, activeCount > 0 else {
            dockTile.badgeLabel = nil
            if dockTile.contentView != nil {
                dockTile.contentView = nil
                dockTile.display()
            }
            return
        }

        // 1. Badge label
        switch settings.dockBadgeDisplayMode {
        case .activeCount:
            dockTile.badgeLabel = "\(activeCount)"
        case .totalSpeed:
            dockTile.badgeLabel = totalSpeedBytesPerSecond > 0 ? "\(ByteFormatter.format(Int64(totalSpeedBytesPerSecond)))/s" : "\(activeCount)"
        case .overallProgress:
            if let p = overallProgress, p > 0 {
                dockTile.badgeLabel = "\(Int(round(p * 100)))%"
            } else {
                dockTile.badgeLabel = "\(activeCount)"
            }
        case .none:
            dockTile.badgeLabel = nil
        }

        // 2. Progress bar
        if settings.dockShowProgressBar, let progress = overallProgress, progress > 0.0 && progress < 1.0 {
            if dockTile.contentView !== tileView {
                dockTile.contentView = tileView
            }
            tileView.progress = progress
            dockTile.display()
        } else {
            if dockTile.contentView != nil {
                dockTile.contentView = nil
                dockTile.display()
            }
        }
    }
}
