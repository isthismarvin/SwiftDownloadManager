import AppKit
import SwiftUI

/// Standalone floating panel — appears above other apps (e.g. Chrome) without raising the main window.
@MainActor
enum FloatingDialogPanel {
    private static var panel: NSPanel?
    private static var delegate = PanelDelegate()
    private static var userCloseHandler: (() -> Void)?
    private static var pendingPresent: DispatchWorkItem?

    static var isPresented: Bool {
        panel?.isVisible == true
    }

    static func present(
        title: String,
        @ViewBuilder content: () -> some View,
        onUserClose: (() -> Void)? = nil,
        size: NSSize
    ) {
        userCloseHandler = onUserClose
        let rootView = AnyView(content())

        pendingPresent?.cancel()
        let work = DispatchWorkItem {
            presentNow(title: title, content: rootView, size: size)
        }
        pendingPresent = work
        DispatchQueue.main.async(execute: work)
    }

    static func dismiss() {
        pendingPresent?.cancel()
        pendingPresent = nil
        userCloseHandler = nil
        panel?.orderOut(nil)
    }

    private static func presentNow(title: String, content: AnyView, size: NSSize) {
        let hosting = NSHostingController(
            rootView: content
                .frame(width: size.width, height: size.height)
                .background(Color(nsColor: .windowBackgroundColor))
        )
        hosting.view.translatesAutoresizingMaskIntoConstraints = true
        hosting.view.frame = NSRect(origin: .zero, size: size)
        hosting.view.autoresizingMask = [.width, .height]

        let targetPanel: NSPanel
        if let panel {
            targetPanel = panel
            targetPanel.orderOut(nil)
        } else {
            targetPanel = makePanel(title: title, size: size)
            targetPanel.delegate = delegate
            panel = targetPanel
        }

        targetPanel.title = title
        targetPanel.contentMinSize = size
        targetPanel.contentMaxSize = size
        targetPanel.setContentSize(size)
        targetPanel.contentViewController = hosting
        position(targetPanel, size: size)

        DispatchQueue.main.async {
            targetPanel.orderFrontRegardless()
            targetPanel.makeKey()
        }
    }

    private static func makePanel(title: String, size: NSSize) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .utilityWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
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

    private static func position(_ panel: NSPanel, size: NSSize) {
        guard let screen = NSScreen.screenWithMouse ?? NSScreen.main else { return }

        let visible = screen.visibleFrame
        let origin = NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2
        )
        panel.setFrame(NSRect(origin: origin, size: size), display: false)
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
