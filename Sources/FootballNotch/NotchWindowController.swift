import AppKit
import SwiftUI

/// Hosting view that only claims mouse events inside the visible card, letting clicks
/// elsewhere in the (large, mostly transparent) overlay pass through to apps beneath.
final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    var interactiveRect: CGRect = .zero

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        guard interactiveRect.contains(local) else { return nil }
        return super.hitTest(point)
    }
}

@MainActor
final class NotchWindowController {
    private let panel: NSPanel
    private let hostingView: PassthroughHostingView<AnyView>
    private var screenObserver: NSObjectProtocol?

    init(rootView: some View) {
        let hosting = PassthroughHostingView(rootView: AnyView(rootView))
        hosting.sizingOptions = []
        hostingView = hosting

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 460),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovable = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.ignoresMouseEvents = false
        panel.acceptsMouseMovedEvents = true
        panel.contentView = hosting

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

    /// The SwiftUI card reports its frame (in the overlay's coordinate space) so we can
    /// restrict mouse interaction to the visible region.
    func updateInteractiveRect(_ rect: CGRect) {
        hostingView.interactiveRect = rect
    }

    /// Size the fixed overlay to the target screen and pin it top-centered. The overlay
    /// never resizes on hover — all expand/collapse animation happens inside SwiftUI.
    private func reposition() {
        guard let screen = NotchMetrics.targetScreen else { return }
        let width = min(screen.frame.width, 600)
        let height: CGFloat = 460
        let frame = NSRect(
            x: screen.frame.midX - width / 2,
            y: screen.frame.maxY - height,
            width: width,
            height: height
        )
        panel.setFrame(frame, display: true)
        hostingView.frame = NSRect(origin: .zero, size: frame.size)
    }
}
