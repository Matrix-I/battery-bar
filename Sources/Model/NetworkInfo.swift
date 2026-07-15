// NetworkInfo.swift — snapshot of the machine's network state shown in the Network tab. Filled by
// NetworkReader from a handful of independent sources (getifaddrs / sysctl route table for the
// interface + byte counters, SCDynamicStore for the primary service + DNS, CoreWLAN for the Wi-Fi
// radio, an ICMP ping for latency/jitter, and an optional outbound lookup for the public IP), so
// every field is optional and simply hidden by the view when it wasn't (yet) read.

import Foundation

/// One end-to-end reading of the primary network interface. All fields are optional/defaulted so a
/// partially-completed read (e.g. Wi-Fi details in, ping still running, public IP disabled) still
/// renders cleanly instead of blocking the whole panel on the slowest source.
struct NetworkInfo {
    // MARK: Interface identity
    /// BSD name of the primary interface — the one the default route points at (e.g. "en0").
    var interfaceName: String?
    /// Friendly service name from the network config ("Wi-Fi", "Ethernet", "USB 10/100/1000 LAN").
    var serviceName: String?
    /// Interface is administratively up and running (IFF_UP && IFF_RUNNING).
    var isUp = false
    /// Hardware (MAC) address of the primary interface, colon-separated.
    var macAddress: String?
    var localIPv4: String?
    var localIPv6: String?
    var dnsServers: [String] = []

    // MARK: Throughput (since the app launched — see NetworkReader's baseline)
    var uploadTotal: UInt64 = 0
    var downloadTotal: UInt64 = 0
    /// Live per-second rates, derived from the delta between two counter reads.
    var uploadRate: Double = 0     // bytes/sec
    var downloadRate: Double = 0   // bytes/sec

    // MARK: Wi-Fi radio (nil on wired links)
    var isWiFi = false
    /// nil until Location Services is granted — CoreWLAN redacts the SSID otherwise (macOS 14+).
    var ssid: String?
    var rssi: Int?                 // dBm, negative; closer to 0 is stronger
    var phyMode: String?           // "802.11ax"
    var channelNumber: Int?
    var channelBand: String?       // "2.4 GHz" / "5 GHz" / "6 GHz"
    var channelWidth: String?      // "20 MHz" / "40 MHz" / "80 MHz" / "160 MHz"
    var txRate: Double?            // negotiated transmit rate, Mbps

    // MARK: Internet
    /// A real reachability probe succeeded (the latency ping came back), not just a link-up flag.
    var internetReachable = false
    var latencyMs: Double?         // mean RTT of the last ping burst
    var jitterMs: Double?          // stddev of the last ping burst

    // MARK: Public IP (only populated when the "Show public IP" toggle is on)
    var publicIPv4: String?
    var publicIPv6: String?
    var countryCode: String?       // ISO-3166 alpha-2, e.g. "VN" — rendered as a flag by the view
    /// Set when the last public-IP lookup failed (offline, service down) so the view can say so
    /// instead of silently showing nothing.
    var publicIPError = false
}
