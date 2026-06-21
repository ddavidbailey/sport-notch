import AppKit
import SwiftUI
import FootballNotchCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: MatchStore!
    private var windowController: NotchWindowController!
    private var pollTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // no Dock icon, agent app
        store = MatchStore(service: FIFAService())
        windowController = NotchWindowController(rootView: NotchRootView(store: store))
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
