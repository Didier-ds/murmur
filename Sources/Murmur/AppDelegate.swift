import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = StatusItemController(
            onToggle: { [weak self] in self?.toggle() },
            makeMenu: {
                let menu = NSMenu()
                menu.addItem(NSMenuItem(title: "Quit Murmur", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
                return menu
            },
            level: { 0.5 }
        )
    }

    /// Placeholder until dictation exists: just flips the icon between states.
    private func toggle() {
        guard let statusItem else { return }
        statusItem.look = statusItem.look == .idle ? .recording : .idle
    }
}
