// ProcessList.swift — shared helper for the TOP PROCESSES tables in the CPU and RAM popovers:
// resolving a pid to a display name + app icon. Used by both CPUReader and MemoryReader so the two
// tables identify processes identically.

import Foundation
import AppKit

enum ProcessList {
    /// A GUI application's localized name and icon (e.g. "Google Chrome" + its icon) when the PID
    /// owns an NSRunningApplication; otherwise the `ps` accounting name and no icon, for the
    /// daemons/helpers that have none (the view draws a generic placeholder for those).
    static func identity(pid: Int, fallback comm: String) -> (name: String, icon: NSImage?) {
        guard let app = NSRunningApplication(processIdentifier: pid_t(pid)) else { return (comm, nil) }
        let name = app.localizedName.flatMap { $0.isEmpty ? nil : $0 } ?? comm
        return (name, app.icon)
    }
}
