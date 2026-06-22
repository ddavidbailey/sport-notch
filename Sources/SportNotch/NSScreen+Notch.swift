import AppKit

/// Geometry describing the notch (or its notchless fallback) on the active screen.
struct NotchMetrics: Equatable {
    /// Height of the physical notch / menu bar; content is offset below this.
    let height: CGFloat
    /// Width of the physical notch, or a sensible default on notchless displays.
    let width: CGFloat
    /// Whether the active screen has a real notch.
    let hasNotch: Bool
    /// Physical screen diagonal in inches (0 if the display doesn't report one).
    /// A 14" MacBook Pro reads ~14.1, a 16" ~16.2.
    let diagonalInches: CGFloat
    /// Whether the active screen is the Mac's built-in display (a laptop panel)
    /// rather than an external desktop monitor.
    let isBuiltIn: Bool

    static let fallback = NotchMetrics(
        height: 32, width: 180, hasNotch: false, diagonalInches: 0, isBuiltIn: false)

    static var current: NotchMetrics { forScreen(targetScreen) }

    /// Notch geometry for a specific screen — used so the layout always reflects the
    /// display the overlay is actually on, not whichever was active at launch.
    static func forScreen(_ screen: NSScreen?) -> NotchMetrics {
        guard let screen else { return fallback }
        let diagonal = screen.diagonalInches
        let builtIn = screen.isBuiltIn
        if let notch = screen.notchSize {
            return NotchMetrics(height: notch.height, width: notch.width, hasNotch: true,
                                diagonalInches: diagonal, isBuiltIn: builtIn)
        }
        // Notchless: float just under the menu bar.
        return NotchMetrics(height: max(screen.menubarHeight, 24), width: 180, hasNotch: false,
                            diagonalInches: diagonal, isBuiltIn: builtIn)
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

    /// Core Graphics display ID for this screen, used for the physical-size and
    /// built-in queries below.
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }

    /// True for the Mac's built-in panel (laptop screen), false for external monitors.
    var isBuiltIn: Bool {
        guard let displayID else { return false }
        return CGDisplayIsBuiltin(displayID) != 0
    }

    /// Physical diagonal in inches, or 0 if the display reports no size.
    var diagonalInches: CGFloat {
        guard let displayID else { return 0 }
        let mm = CGDisplayScreenSize(displayID) // physical size in millimetres
        guard mm.width > 0, mm.height > 0 else { return 0 }
        return hypot(mm.width, mm.height) / 25.4
    }
}
