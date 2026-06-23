import AppKit
import SportNotchCore

/// Menu-bar control surface for the agent app. Since the app runs as an
/// `.accessory` with no Dock icon, this status item is how the user shows or hides
/// the notch overlay and quits.
@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let store: MatchStore
    private let toggleItem: NSMenuItem

    init(store: MatchStore) {
        self.store = store
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        toggleItem = NSMenuItem(
            title: "Hide Sport Notch",
            action: #selector(toggleMinimized),
            keyEquivalent: "")
        super.init()

        // Template image adapts to light/dark menu bars automatically.
        let icon = NSImage(systemSymbolName: "soccerball", accessibilityDescription: "Sport Notch")
        icon?.isTemplate = true
        statusItem.button?.image = icon

        toggleItem.target = self

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(toggleItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(
            title: "Quit Sport Notch",
            action: #selector(quit),
            keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    // MARK: - Actions

    @objc private func toggleMinimized() {
        if store.isMinimized {
            store.restore()
        } else {
            store.minimize()
        }
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        // Reflect the live state each time the menu opens, since a fresh kickoff can
        // reopen the notch without the user touching this menu.
        toggleItem.title = store.isMinimized ? "Show Sport Notch" : "Hide Sport Notch"
    }
}
