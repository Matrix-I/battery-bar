// BatteryBarApp.swift — app entry point for BatteryBar, a menu bar battery health app
// (coconutBattery-style).
//
// Requires : macOS 13 Ventura or later + Xcode Command Line Tools
//            (xcode-select --install)
//
// Build/run     :  ./build_app.sh        (compiles the whole Sources/ tree into BatteryBar.app)
// Package .dmg  :  ./build_dmg.sh
//
// Data is read directly from the IOKit registry "AppleSmartBattery" (see BatteryReader) — the
// same source coconutBattery uses. No root needed, no kernel extension. Live power rails + fan
// speeds come from the AppleSMC user client (see SMC); iPhone/Android come over USB via
// libimobiledevice / adb (see IOSDeviceReader / AndroidDeviceReader).
//
// The two menu-bar items (Battery + Network) are built manually with NSStatusItem + NSPopover rather
// than SwiftUI's MenuBarExtra. MenuBarExtra can't enforce "only one popover open at a time": closing
// one item's window from the outside leaves that MenuBarExtra believing it's still presented, so the
// next click just toggles it shut (the classic two-click bug). Owning the NSPopovers ourselves lets
// us close the other one cleanly — its `isShown` stays truthful, so every switch is a single click.

import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    // Readers live here (not as @StateObject on the App) since the status items, not a SwiftUI
    // scene, own the UI now. They keep polling for the whole app lifetime.
    private let batteryReader = BatteryReader()
    private let iosReader = IOSDeviceReader()
    private let androidReader = AndroidDeviceReader()
    private let networkReader = NetworkReader()

    private var batteryItem: NSStatusItem!
    private var networkItem: NSStatusItem!
    private let batteryPopover = NSPopover()
    private let networkPopover = NSPopover()

    /// Refreshes the two status-item glyphs ~1 Hz (cheap to rebuild; the readers update at that rate
    /// anyway). Also the hook for menu-bar toggle changes to take effect within a second.
    private var labelTimer: Timer?
    /// Fires on clicks outside the app so an open popover dismisses like a normal menu-bar popover.
    private var outsideClickMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar-only app: no Dock icon, no app menu (the .app bundle also sets LSUIElement).
        NSApp.setActivationPolicy(.accessory)

        configure(popover: batteryPopover,
                  root: BatteryDetailView(reader: batteryReader, iosReader: iosReader, androidReader: androidReader))
        configure(popover: networkPopover, root: NetworkDetailView(reader: networkReader))

        batteryItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        batteryItem.button?.target = self
        batteryItem.button?.action = #selector(toggleBattery)

        networkItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        networkItem.button?.target = self
        networkItem.button?.action = #selector(toggleNetwork)

        refreshLabels()
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.refreshLabels() }
        RunLoop.main.add(t, forMode: .common)
        labelTimer = t

        // A global monitor sees only clicks in OTHER apps / the desktop, never our own popover's
        // interior or our status buttons — exactly the "clicked away" case that should dismiss.
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
            [weak self] _ in self?.closeAll()
        }
    }

    /// Hosts a SwiftUI detail view in a popover. `.applicationDefined` (not `.transient`) so the
    /// system never auto-dismisses it behind our back — we do all closing — which is what keeps the
    /// one-click switching deterministic. `.preferredContentSize` lets the SwiftUI content drive the
    /// popover's size the same way it drove the MenuBarExtra window.
    private func configure<Root: View>(popover: NSPopover, root: Root) {
        let host = NSHostingController(rootView: root)
        host.sizingOptions = [.preferredContentSize]
        popover.behavior = .applicationDefined
        popover.animates = false
        popover.contentViewController = host
    }

    @objc private func toggleBattery() { toggle(batteryPopover, item: batteryItem, other: networkPopover) }
    @objc private func toggleNetwork() { toggle(networkPopover, item: networkItem, other: batteryPopover) }

    private func toggle(_ popover: NSPopover, item: NSStatusItem, other: NSPopover) {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        other.performClose(nil)                 // single-popover rule — close the other first, cleanly
        guard let button = item.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        // An accessory app isn't active by default; activating lets the popover take key focus so
        // its controls (toggles, buttons, text selection) work on the first click.
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closeAll() {
        if batteryPopover.isShown { batteryPopover.performClose(nil) }
        if networkPopover.isShown { networkPopover.performClose(nil) }
    }

    private func refreshLabels() {
        batteryItem?.button?.image = currentBatteryImage()
        networkItem?.button?.image = networkMenuBarImage(up: networkReader.info.uploadRate,
                                                         down: networkReader.info.downloadRate)
    }

    /// Rebuilds the battery glyph, mirroring the old MenuBarLabel logic: a combined Mac+phone glyph
    /// when the iPhone/Android menu-bar toggle is on and a device is readable, otherwise the plain
    /// Mac battery. iPhone wins over Android when both are present, to keep the item from growing a
    /// third glyph.
    private func currentBatteryImage() -> NSImage {
        let defaults = UserDefaults.standard
        let showPercent = defaults.object(forKey: "showMenuBarPercent") as? Bool ?? true
        let showIPhone = defaults.bool(forKey: "showIPhoneMenuBar")
        let showAndroid = defaults.bool(forKey: "showAndroidMenuBar")
        let info = batteryReader.info
        let macPct = Int(info.chargePercent.rounded())

        if showIPhone, let ios = iosReader.devices.first, let cp = ios.chargePercent {
            return dualMenuBarImage(macPct: macPct, macCharging: info.isPluggedIn,
                                    phonePct: Int(cp.rounded()), phoneCharging: ios.isPluggedIn,
                                    phoneSymbol: "iphone", showPercent: showPercent)
        }
        if showAndroid, let android = androidReader.devices.first, let level = android.levelPercent {
            return dualMenuBarImage(macPct: macPct, macCharging: info.isPluggedIn,
                                    phonePct: level, phoneCharging: android.isPluggedIn,
                                    phoneSymbol: "candybarphone", showPercent: showPercent)
        }
        return batteryMenuBarImage(level: info.chargePercent / 100,
                                   charging: info.isPluggedIn,
                                   percent: showPercent ? macPct : nil)
    }
}

@main
struct BatteryBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // No visible scene — the UI is the two NSStatusItems built in AppDelegate. Settings gives the
        // App a valid (empty, never-shown) scene body.
        Settings { EmptyView() }
    }
}
