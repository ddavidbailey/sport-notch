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

/// Publishes the active screen's notch geometry so SwiftUI re-renders whenever the
/// display configuration changes (docking/undocking, moving between laptop and an
/// external monitor). Seeded at creation so the very first frame is already correct.
@MainActor
final class ScreenContext: ObservableObject {
    @Published var metrics: NotchMetrics

    init(metrics: NotchMetrics = .current) {
        self.metrics = metrics
    }
}

@MainActor
final class NotchWindowController {
    private let panel: NSPanel
    private let hostingView: PassthroughHostingView<AnyView>
    private let context: ScreenContext
    private var screenObserver: NSObjectProtocol?
    private var mouseMonitors: [Any] = []

    init(rootView: some View, context: ScreenContext) {
        self.context = context
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
        // Start transparent to the pointer; cursor tracking re-enables interaction only
        // over the visible card (see setUpMouseTracking). This prevents the large panel
        // footprint from swallowing clicks and scroll outside the card.
        panel.ignoresMouseEvents = true
        panel.acceptsMouseMovedEvents = true
        panel.contentView = hosting

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reposition() }
        }

        setUpMouseTracking()
        reposition()
        panel.orderFrontRegardless()
    }

    /// The SwiftUI card reports its frame (in the overlay's coordinate space) so we can
    /// restrict mouse interaction to the visible region.
    func updateInteractiveRect(_ rect: CGRect) {
        hostingView.interactiveRect = rect
        updatePassthrough()
    }

    // MARK: - Pointer pass-through

    /// The overlay panel is much larger than the visible card. Rather than letting it
    /// swallow events outside the card (clicks fall through via hitTest, but scroll and
    /// gestures do not), we flip `ignoresMouseEvents` based on the cursor: the window is
    /// only opaque to the pointer while the cursor is over the card. Global and local
    /// monitors cover both cases — global fires while the cursor is over other apps (the
    /// window is ignoring events), local fires while it's over the card.
    private func setUpMouseTracking() {
        let global = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            MainActor.assumeIsolated { self?.updatePassthrough() }
        }
        let local = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            MainActor.assumeIsolated { self?.updatePassthrough() }
            return event
        }
        mouseMonitors = [global, local].compactMap { $0 }
    }

    private func updatePassthrough() {
        let shouldIgnore = !interactiveRegionContains(NSEvent.mouseLocation)
        if panel.ignoresMouseEvents != shouldIgnore {
            panel.ignoresMouseEvents = shouldIgnore
        }
    }

    /// Whether a point in screen coordinates falls within the card's interactive rect.
    private func interactiveRegionContains(_ screenPoint: NSPoint) -> Bool {
        let rect = hostingView.interactiveRect
        guard !rect.isEmpty else { return false }
        let windowPoint = panel.convertPoint(fromScreen: screenPoint)
        return rect.contains(hostingView.convert(windowPoint, from: nil))
    }

    /// Size the fixed overlay to the target screen and pin it top-centered. The overlay
    /// never resizes on hover — all expand/collapse animation happens inside SwiftUI.
    private func reposition() {
        guard let screen = NotchMetrics.targetScreen else { return }

        // Publish the metrics for the screen we're actually on so the SwiftUI layout
        // matches it. Without this the notch inset can be stale after a display change,
        // hiding content under the notch.
        let metrics = NotchMetrics.forScreen(screen)
        if context.metrics != metrics { context.metrics = metrics }
        NSLog("""
        FootballNotch: active screen "\(screen.localizedName)" \
        \(String(format: "%.1f", metrics.diagonalInches))" builtIn=\(metrics.isBuiltIn) \
        hasNotch=\(metrics.hasNotch) notch=\(Int(metrics.width))x\(Int(metrics.height))
        """)

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
