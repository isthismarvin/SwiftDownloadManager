import AppKit
import SwiftUI

/// Standalone floating panel — appears above other apps (e.g. Chrome) without raising the main window.
@MainActor
enum FloatingDialogPanel {
    private static var panel: NSPanel?
    private static var delegate = PanelDelegate()
    private static var userCloseHandler: (() -> Void)?

    static var isPresented: Bool {
        panel?.isVisible == true
    }

    static func present(
        title: String,
        @ViewBuilder content: () -> some View,
        onUserClose: (() -> Void)? = nil,
        size: NSSize? = nil
    ) {
        userCloseHandler = onUserClose

        let hosting = NSHostingController(
            rootView: AnyView(
                content()
                    .background(Color(nsColor: .windowBackgroundColor))
            )
        )
        if let size {
            hosting.view.frame.size = size
        } else {
            hosting.sizingOptions = [.intrinsicContentSize]
        }

        if let panel {
            panel.title = title
            panel.contentViewController = hosting
            position(panel)
            show(panel)
            return
        }

        let newPanel = makePanel(title: title, size: size)
        newPanel.contentViewController = hosting
        panel = newPanel
        position(newPanel)
        show(newPanel)
    }

    static func dismiss() {
        userCloseHandler = nil
        panel?.orderOut(nil)
    }

    private static func makePanel(title: String, size: NSSize?) -> NSPanel {
        let initialSize = size ?? NSSize(width: 560, height: 480)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: initialSize.width, height: initialSize.height),
            styleMask: [.titled, .closable, .utilityWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.delegate = delegate
        panel.isFloatingPanel = true
        panel.level = .modalPanel
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.title = title
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .windowBackgroundColor
        return panel
    }

    private static func show(_ panel: NSPanel) {
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)
    }

    private static func position(_ panel: NSPanel) {
        panel.layoutIfNeeded()
        guard let screen = NSScreen.screenWithMouse ?? NSScreen.main else { return }

        let size = panel.frame.size
        let visible = screen.visibleFrame
        let origin = NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2
        )
        panel.setFrameOrigin(origin)
    }

    private final class PanelDelegate: NSObject, NSWindowDelegate {
        func windowWillClose(_ notification: Notification) {
            FloatingDialogPanel.userCloseHandler?()
            FloatingDialogPanel.userCloseHandler = nil
        }
    }
}

private extension NSScreen {
    static var screenWithMouse: NSScreen? {
        let mouse = NSEvent.mouseLocation
        return screens.first { NSMouseInRect(mouse, $0.frame, false) }
    }
}
