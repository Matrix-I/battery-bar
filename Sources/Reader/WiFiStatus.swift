// WiFiStatus.swift — reads the Wi-Fi radio's live state from CoreWLAN: SSID, signal (RSSI), the
// 802.11 PHY mode, the channel (number + band + width) and the negotiated transmit rate.
//
// Everything here works without any special permission EXCEPT `ssid()`: since macOS 14 the system
// redacts the network name (and BSSID) unless the app holds Location Services authorization, so
// `ssid` comes back nil until the user grants it — while signal/channel/standard/speed keep working
// regardless. `isWiFi` is false when the primary interface isn't the Wi-Fi radio (e.g. Ethernet),
// letting the reader skip this section entirely.

import Foundation
import CoreWLAN

enum WiFiStatus {

    struct Reading {
        var interfaceName: String?
        var ssid: String?
        var rssi: Int?
        var phyMode: String?
        var channelNumber: Int?
        var channelBand: String?
        var channelWidth: String?
        var txRate: Double?
    }

    /// Reads the default Wi-Fi interface. Returns nil when the Mac has no Wi-Fi radio at all;
    /// returns a Reading with an empty-ish body when Wi-Fi exists but isn't associated to a network.
    static func read() -> Reading? {
        guard let iface = CWWiFiClient.shared().interface() else { return nil }
        var r = Reading()
        r.interfaceName = iface.interfaceName

        // ssid() returns nil without Location authorization (macOS 14+) or when not associated.
        if let ssid = iface.ssid(), !ssid.isEmpty { r.ssid = ssid }

        // rssiValue() is 0 when not associated; treat 0 as "no signal" rather than a real reading.
        let rssi = iface.rssiValue()
        if rssi != 0 { r.rssi = rssi }

        r.phyMode = phyModeString(iface.activePHYMode())

        if let ch = iface.wlanChannel() {
            r.channelNumber = ch.channelNumber
            r.channelBand = bandString(ch.channelBand)
            r.channelWidth = widthString(ch.channelWidth)
        }

        let tx = iface.transmitRate()
        if tx > 0 { r.txRate = tx }

        return r
    }

    private static func phyModeString(_ mode: CWPHYMode) -> String? {
        // Wi-Fi 7 (.mode11be) only exists on newer SDKs/OSes, so read it behind an availability check
        // to stay buildable against the app's older deployment target.
        if #available(macOS 15.0, *), mode == .mode11be { return "802.11be" }
        switch mode {
        case .mode11a:  return "802.11a"
        case .mode11b:  return "802.11b"
        case .mode11g:  return "802.11g"
        case .mode11n:  return "802.11n"
        case .mode11ac: return "802.11ac"
        case .mode11ax: return "802.11ax"
        default:        return nil   // .modeNone and any future modes
        }
    }

    private static func bandString(_ band: CWChannelBand) -> String? {
        switch band {
        case .band2GHz: return "2.4 GHz"
        case .band5GHz: return "5 GHz"
        case .band6GHz: return "6 GHz"
        case .bandUnknown: return nil
        @unknown default: return nil
        }
    }

    private static func widthString(_ width: CWChannelWidth) -> String? {
        switch width {
        case .width20MHz:  return "20 MHz"
        case .width40MHz:  return "40 MHz"
        case .width80MHz:  return "80 MHz"
        case .width160MHz: return "160 MHz"
        case .widthUnknown: return nil
        @unknown default: return nil
        }
    }
}
