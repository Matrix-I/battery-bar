// Pinger.swift — measures internet latency and jitter with a small burst of ICMP echo requests.
//
// Uses an *unprivileged* ICMP socket: `socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)`. On Darwin this
// datagram flavour lets a normal user process send/receive ICMP echo without the raw-socket root
// requirement (it's how ping(8) works without setuid). The kernel rewrites the echo identifier to
// the socket's port and only delivers matching replies back to us, so we match on the sequence
// number we set (the identifier is not ours to rely on). Latency is the mean RTT of the burst;
// jitter is the standard deviation.
//
// This is deliberately synchronous and meant to run on a background queue (see NetworkReader): one
// burst blocks for at most count × timeout.

import Foundation

enum Pinger {

    struct Result {
        var samples: [Double]      // per-reply RTT in ms
        var latencyMs: Double?     // mean
        var jitterMs: Double?      // population standard deviation
        var reachable: Bool        // at least one reply came back
    }

    /// Pings an IPv4 dotted-quad host `count` times (spacing them slightly) and summarises the RTTs.
    static func ping(host: String, count: Int = 5, timeout: TimeInterval = 1.0) -> Result {
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        guard inet_pton(AF_INET, host, &addr.sin_addr) == 1 else {
            return Result(samples: [], latencyMs: nil, jitterMs: nil, reachable: false)
        }

        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP)
        guard fd >= 0 else {
            return Result(samples: [], latencyMs: nil, jitterMs: nil, reachable: false)
        }
        defer { close(fd) }

        let identifier = UInt16(truncatingIfNeeded: getpid())
        var samples: [Double] = []
        for seq in 0..<count {
            if let rtt = onePing(fd: fd, addr: &addr, identifier: identifier,
                                 seq: UInt16(truncatingIfNeeded: seq), timeout: timeout) {
                samples.append(rtt)
            }
            // A short gap so consecutive echoes aren't fired back-to-back (which tends to bunch up
            // replies and understate jitter). Skipped after the final ping.
            if seq < count - 1 { Thread.sleep(forTimeInterval: 0.12) }
        }

        let mean = samples.isEmpty ? nil : samples.reduce(0, +) / Double(samples.count)
        var jitter: Double?
        if let mean, samples.count > 1 {
            let variance = samples.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(samples.count)
            jitter = variance.squareRoot()
        }
        return Result(samples: samples, latencyMs: mean, jitterMs: jitter, reachable: !samples.isEmpty)
    }

    /// Sends one echo request and waits (up to `timeout`) for the matching reply, returning the RTT
    /// in milliseconds, or nil on timeout / error.
    private static func onePing(fd: Int32, addr: inout sockaddr_in, identifier: UInt16,
                                seq: UInt16, timeout: TimeInterval) -> Double? {
        var packet = echoRequest(identifier: identifier, seq: seq)
        let sent = packet.withUnsafeMutableBytes { raw -> Int in
            withUnsafePointer(to: &addr) { aptr in
                aptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { saptr in
                    sendto(fd, raw.baseAddress, raw.count, 0, saptr, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        guard sent > 0 else { return nil }
        let start = DispatchTime.now()
        let deadline = start.uptimeNanoseconds + UInt64(timeout * 1_000_000_000)

        var recvBuf = [UInt8](repeating: 0, count: 1024)
        while true {
            let remainingNs = Int64(deadline) - Int64(DispatchTime.now().uptimeNanoseconds)
            if remainingNs <= 0 { return nil }
            var pfd = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
            let pr = poll(&pfd, 1, Int32(remainingNs / 1_000_000))
            guard pr > 0 else { return nil }   // 0 = timeout, <0 = error

            let n = recv(fd, &recvBuf, recvBuf.count, 0)
            guard n > 0 else { return nil }
            // The reply may or may not carry a leading IPv4 header depending on the socket flavour,
            // so locate the ICMP header by skipping the IP header only when one is present.
            var off = 0
            if (recvBuf[0] >> 4) == 4 { off = Int(recvBuf[0] & 0x0f) * 4 }
            guard n >= off + 8 else { continue }
            let type = recvBuf[off]
            let replySeq = (UInt16(recvBuf[off + 6]) << 8) | UInt16(recvBuf[off + 7])
            // Type 0 = echo reply. Match our sequence so a straggler from an earlier ping can't be
            // mistaken for this one (which would report an artificially low RTT).
            guard type == 0, replySeq == seq else { continue }
            let rttNs = DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds
            return Double(rttNs) / 1_000_000.0
        }
    }

    /// Builds an 8-byte ICMP echo-request header + a short payload, with the checksum filled in.
    private static func echoRequest(identifier: UInt16, seq: UInt16) -> [UInt8] {
        var p = [UInt8](repeating: 0, count: 16)   // 8-byte header + 8-byte payload
        p[0] = 8                                    // type = ICMP_ECHO
        p[1] = 0                                    // code
        p[2] = 0; p[3] = 0                          // checksum (computed below)
        p[4] = UInt8(identifier >> 8); p[5] = UInt8(identifier & 0xff)
        p[6] = UInt8(seq >> 8);        p[7] = UInt8(seq & 0xff)
        // Payload can be anything; leave it zero-filled.
        let ck = checksum(p)
        p[2] = UInt8(ck >> 8); p[3] = UInt8(ck & 0xff)
        return p
    }

    /// Standard internet checksum (RFC 1071): one's-complement sum of the 16-bit big-endian words.
    private static func checksum(_ data: [UInt8]) -> UInt16 {
        var sum: UInt32 = 0
        var i = 0
        while i + 1 < data.count {
            sum += (UInt32(data[i]) << 8) | UInt32(data[i + 1])
            i += 2
        }
        if i < data.count { sum += UInt32(data[i]) << 8 }
        while sum >> 16 != 0 { sum = (sum & 0xffff) + (sum >> 16) }
        return UInt16(~sum & 0xffff)
    }
}
