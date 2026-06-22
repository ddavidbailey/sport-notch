import AppKit
import ServiceManagement

/// Menu-bar control surface for the agent app. Since the app runs as an
/// `.accessory` with no Dock icon, this status item is the only way to quit it
/// or toggle launch-at-login.
@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let launchAtLoginItem: NSMenuItem

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        launchAtLoginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: "")
        super.init()

        // Template image adapts to light/dark menu bars automatically.
        let icon = NSImage(systemSymbolName: "soccerball", accessibilityDescription: "Football Notch")
        icon?.isTemplate = true
        statusItem.button?.image = icon

        launchAtLoginItem.target = self

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(launchAtLoginItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(
            title: "Quit Football Notch",
            action: #selector(quit),
            keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    // MARK: - Actions

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            // Registration commonly throws for an unsigned app until the user
            // approves it under System Settings → General → Login Items.
            NSLog("Football Notch: launch-at-login toggle failed: \(error)")
        }
        // Always reflect the real status, not the attempted state.
        syncLaunchAtLoginState()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        // Re-sync so the checkbox never drifts from reality (e.g. if the user
        // changed the login item in System Settings).
        syncLaunchAtLoginState()
    }

    // MARK: - Helpers

    private func syncLaunchAtLoginState() {
        launchAtLoginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }
}
