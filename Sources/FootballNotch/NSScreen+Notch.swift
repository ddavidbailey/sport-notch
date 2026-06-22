import AppKit

/// Geometry describing the notch (or its notchless fallback) on the active screen.
struct NotchMetrics: Equatable {
    /// Height of the physical notch / menu bar; content is offset below this.
    let height: CGFloat
    /// Width of the physical notch, or a sensible default on notchless displays.
    let width: CGFloat
    /// Whether the active screen has a real notch.
    let hasNotch: Bool

    static let fallback = NotchMetrics(height: 32, width: 180, hasNotch: false)

    static var current: NotchMetrics {
        guard let screen = NotchMetrics.targetScreen else { return fallback }
        if let notch = screen.notchSize {
            return NotchMetrics(height: notch.height, width: notch.width, hasNotch: true)
        }
        // Notchless: float just under the menu bar.
        return NotchMetrics(height: max(screen.menubarHeight, 24), width: 180, hasNotch: false)
    }

    /// The screen to render on: prefer one with a notch, else the main screen.
    static var targetScreen: NSScreen? {
        NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main
    }
}

extension NSScreen {
    var notchSize: NSSize? {
        guard
            let left = auxiliaryTopLeftArea?.width,
            let right = auxiliaryTopRightArea?.width,
            safeAreaInsets.top > 0
        else { return nil }

        let height = safeAreaInsets.top
        let width = frame.width - left - right
        return NSSize(width: width, height: height)
    }

    var menubarHeight: CGFloat {
        let height = frame.maxY - visibleFrame.maxY
        return height > 0 ? height : 24
    }
}
