import AppKit
import SwiftUI
import FootballNotchCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: MatchStore!
    private var windowController: NotchWindowController!
    private var statusBarController: StatusBarController?
    private var pollTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // no Dock icon, agent app
        store = MatchStore(service: FIFAService())
        let screen = ScreenContext()
        windowController = NotchWindowController(
            rootView: NotchRootView(store: store, screen: screen, onCardFrame: { [weak self] rect in
                // The first geometry update can fire while the controller is still being
                // constructed (before `windowController` is assigned); defer so it lands
                // once the property is set.
                Task { @MainActor in
                    self?.windowController?.updateInteractiveRect(rect)
                }
            }),
            context: screen)
        statusBarController = StatusBarController()
        startPolling()
    }

    private func startPolling() {
        pollTask = Task { @MainActor in
            while !Task.isCancelled {
                await store.refresh()
                let live = store.followedMatch?.isLive ?? false
                let seconds = pollInterval(isLive: live)
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        pollTask?.cancel()
    }
}
