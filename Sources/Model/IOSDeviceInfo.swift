// IOSDeviceInfo.swift — iPhone/iPad-over-USB battery model. Populated by IOSDeviceReader,
// which shells out to libimobiledevice (same approach as cocobat.py --ios).

import Foundation

struct IOSDeviceInfo: Identifiable {
    let id: String               // UDID
    var name = ""
    var model = ""
    var iosVersion = ""
    var serial = ""
    var currentCapacity: Int?     // mAh — nil if diagnostics doesn't return this key
    var maxCapacity: Int?
    var designCapacity: Int?
    var cycleCount: Int?
    var temperatureC: Double?
    var voltageV: Double?
    var amperageA: Double?         // negative = discharging, positive = charging
    var isCharging = false
    var externalConnected = false
    var fullyCharged = false
    var errorMessage: String?
    var isStale = false           // true = currently showing the last known data because the connection briefly dropped
    var isNetwork = false         // reached over Wi-Fi sync (idevice_id -n) instead of USB — the device is
                                  // plugged into some other power source (or a charge-only cable/hub that
                                  // carries no data), yet still readable over the network, so we surface it
                                  // and read it with the `-n` flag rather than dropping it.
    var isLocked = false          // device is present + trusted but at the passcode lock screen: the diagnostics
                                  // registry (mAh/health/cycle) is refused, so those values are last-known or absent
    var coarseChargePercent: Double?  // live 0–100% charge from the lockdown battery domain — used whenever the
                                  // mAh registry is unavailable (locked device, or an OS that only answers the
                                  // GasGauge fallback), since that domain still reports a coarse charge level.
    var reportedHealthPercent: Double?  // "Maximum Capacity" health % reported directly by the device (the
                                  // diagnostics GasGauge fallback gives FullChargeCapacity as a percentage, not
                                  // mAh) — used when we can't compute health from maxCapacity/designCapacity.
    var limitedData = false       // read came from the GasGauge fallback (cycle count + health + coarse charge only);
                                  // the mAh / temperature / voltage / serial figures aren't exposed on this OS/device.
    var capturedAt: Date?         // timestamp this data was captured (for a locked row: when the health figures were last read)

    /// Whether the menu-bar glyph should show the charging bolt. `isCharging` alone goes
    /// false the moment the phone reaches 100% even though it's still on the cable and
    /// drawing power, which left the bolt off while plugged in and full. Being externally
    /// connected is the right signal — same fix as the Mac's `BatteryInfo.isPluggedIn`.
    var isPluggedIn: Bool { externalConnected || isCharging }

    var chargePercent: Double? {
        if let cur = currentCapacity, let max = maxCapacity, max > 0 {
            return Double(cur) / Double(max) * 100
        }
        // No mAh registry (locked, or the GasGauge fallback): the lockdown battery domain still
        // reports a coarse 0–100% charge level.
        return coarseChargePercent
    }
    var healthPercent: Double? {
        // Prefer the mAh-derived figure; fall back to a directly-reported "Maximum Capacity" %
        // (the GasGauge path, where full-charge mAh isn't exposed).
        if let max = maxCapacity, max > 0, let design = designCapacity, design > 0 {
            return Double(max) / Double(design) * 100
        }
        return reportedHealthPercent
    }
    var watts: Double? {
        guard let v = voltageV, let a = amperageA else { return nil }
        return v * a
    }
}
