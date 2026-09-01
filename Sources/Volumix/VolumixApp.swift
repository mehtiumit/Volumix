import AppKit
import SwiftUI

@main
enum Volumix {
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)   // No Dock icon.
        application.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller = MixerController()
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var hotKey: HotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = false
        popover.contentViewController = NSHostingController(
            rootView: MixerView(controller: controller)
        )

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "slider.horizontal.3",
            accessibilityDescription: "Volumix"
        )
        statusItem.button?.target = self
        statusItem.button?.action = #selector(toggle)

        hotKey = HotKey { [weak self] in self?.toggle() }
    }

    @objc private func toggle() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
            controller.stopMetering()
        } else {
            // Run metering only while the panel is visible; a hidden 30 Hz timer wastes CPU.
            controller.startMetering()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Bring the panel forward when opened by shortcut; harmless when opened by click.
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.shutdown()
    }
}
