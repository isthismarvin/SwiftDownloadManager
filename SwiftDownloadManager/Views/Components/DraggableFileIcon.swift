import AppKit
import SwiftUI

/// Finder-style draggable file icon — double-click opens, drag moves/copies.
struct DraggableFileIcon: NSViewRepresentable {
    let fileURL: URL
    let icon: NSImage
    var size: CGFloat = 40
    var onDoubleClick: (() -> Void)?
    var onFileExported: (() -> Void)?

    func makeNSView(context: Context) -> DraggableFileIconView {
        let view = DraggableFileIconView()
        view.configure(fileURL: fileURL, icon: icon, size: size)
        view.onDoubleClick = onDoubleClick
        view.onFileExported = onFileExported
        return view
    }

    func updateNSView(_ nsView: DraggableFileIconView, context: Context) {
        nsView.configure(fileURL: fileURL, icon: icon, size: size)
        nsView.onDoubleClick = onDoubleClick
        nsView.onFileExported = onFileExported
    }
}

final class DraggableFileIconView: NSView, NSDraggingSource {
    private var fileURL: URL?
    private var icon: NSImage?
    private var iconSize: CGFloat = 40
    private var dragStartLocation: NSPoint?
    private var draggingSession: NSDraggingSession?
    private var dragCopyIntent = false

    var onDoubleClick: (() -> Void)?
    var onFileExported: (() -> Void)?

    func configure(fileURL: URL, icon: NSImage, size: CGFloat) {
        self.fileURL = fileURL
        self.icon = icon
        self.iconSize = size
        invalidateIntrinsicContentSize()
        needsDisplay = true
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: iconSize, height: iconSize)
    }

    override func resetCursorRects() {
        discardCursorRects()
        addCursorRect(bounds, cursor: .pointingHand)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let icon else { return }
        let rect = NSRect(
            x: (bounds.width - iconSize) / 2,
            y: (bounds.height - iconSize) / 2,
            width: iconSize,
            height: iconSize
        )
        icon.draw(in: rect)
    }

    override func mouseDown(with event: NSEvent) {
        dragStartLocation = event.locationInWindow
    }

    override func mouseUp(with event: NSEvent) {
        if event.clickCount >= 2 {
            onDoubleClick?()
        }
        dragStartLocation = nil
        draggingSession = nil
    }

    override func mouseDragged(with event: NSEvent) {
        guard draggingSession == nil,
              let fileURL,
              FileManager.default.fileExists(atPath: fileURL.path),
              let start = dragStartLocation else { return }

        let current = event.locationInWindow
        let dx = current.x - start.x
        let dy = current.y - start.y
        guard (dx * dx + dy * dy) > 4 else { return }

        dragCopyIntent = event.modifierFlags.contains(.option)

        let draggingItem = NSDraggingItem(pasteboardWriter: fileURL as NSURL)
        let dragIcon = icon ?? NSWorkspace.shared.icon(forFile: fileURL.path)
        draggingItem.setDraggingFrame(
            NSRect(x: 0, y: 0, width: iconSize, height: iconSize),
            contents: dragIcon
        )

        draggingSession = beginDraggingSession(with: [draggingItem], event: event, source: self)
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        context == .outsideApplication ? [.copy, .move] : .copy
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        let copyIntent = dragCopyIntent
        let handler = onFileExported
        let sourcePath = fileURL?.path

        defer {
            draggingSession = nil
            dragStartLocation = nil
            dragCopyIntent = false
        }

        guard operation != [], let sourcePath else { return }

        Task { @MainActor in
            // Finder finishes move/copy slightly after the drag session ends.
            try? await Task.sleep(for: .milliseconds(400))
            let stillExists = FileManager.default.fileExists(atPath: sourcePath)

            let exported: Bool
            if copyIntent {
                // ⌥-Drag = copy: keep list entry unless the source truly vanished.
                exported = !stillExists || operation == .move
            } else {
                // Normal drag out = user took the file elsewhere.
                exported = true
            }

            if exported {
                handler?()
            }
        }
    }
}
