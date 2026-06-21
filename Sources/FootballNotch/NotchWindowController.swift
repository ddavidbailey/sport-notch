import AppKit
import SwiftUI

@MainActor
final class NotchWindowController {
    private let panel: NSPanel
    private var screenObserver: NSObjectProtocol?

    init(rootView: some View) {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 80),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovable = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = false

        let hosting = NSHostingView(rootView: rootView)
        panel.contentView = hosting
        panel.setContentSize(hosting.fittingSize)

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reposition() }
        }

        reposition()
        panel.orderFrontRegardless()
    }

    /// Resize the panel to fit the rendered SwiftUI content, then reposition.
    func resize(to size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        panel.setContentSize(size)
        reposition()
    }

    /// Center horizontally on the notch screen, pinned to the top edge.
    func reposition() {
        let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 })
            ?? NSScreen.main
        guard let screen else { return }
        let size = panel.frame.size
        let x = screen.frame.midX - size.width / 2
        let y = screen.frame.maxY - size.height
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
