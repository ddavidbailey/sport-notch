import AppKit

/// Menu-bar control surface for the agent app. Since the app runs as an
/// `.accessory` with no Dock icon, this status item is the only way to quit it.
@MainActor
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        // Template image adapts to light/dark menu bars automatically.
        let icon = NSImage(systemSymbolName: "soccerball", accessibilityDescription: "Sport Notch")
        icon?.isTemplate = true
        statusItem.button?.image = icon

        let menu = NSMenu()
        let quitItem = NSMenuItem(
            title: "Quit Sport Notch",
            action: #selector(quit),
            keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    // MARK: - Actions

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
