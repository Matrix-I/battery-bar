// Sysctl.swift — thin, safe wrappers over the sysctl(3) family for the handful of kernel values the
// readers need: CPU core topology and chip name, the memory-pressure level, swap usage, and boot
// time. Consolidates the raw-pointer plumbing that CPUReader, MemoryReader and MemoryStats each used
// to hand-roll, so there's a single place that talks to sysctl.

import Foundation

enum Sysctl {
    /// A named integer sysctl (e.g. "hw.perflevel0.logicalcpu"). Handles both widths sysctls report —
    /// some name a 4-byte value, others 8 — so callers don't have to know which. nil if the name is
    /// unknown.
    static func int(_ name: String) -> Int? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        if size == 4 {
            var v: UInt32 = 0
            guard sysctlbyname(name, &v, &size, nil, 0) == 0 else { return nil }
            return Int(v)
        }
        var v = 0
        var s = MemoryLayout<Int>.size
        guard sysctlbyname(name, &v, &s, nil, 0) == 0 else { return nil }
        return v
    }

    /// A named string sysctl (e.g. "machdep.cpu.brand_string"). Empty strings come back as nil.
    static func string(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buf = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buf, &size, nil, 0) == 0 else { return nil }
        let s = String(cString: buf)
        return s.isEmpty ? nil : s
    }

    /// A fixed-size POD value of type `T` from a named sysctl — used for struct results like
    /// `xsw_usage` (vm.swapusage). Reads only when the kernel reports exactly `MemoryLayout<T>.stride`
    /// bytes, so a shape mismatch fails safe as nil. `T` must be trivially copyable (no references).
    static func value<T>(_ name: String) -> T? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size == MemoryLayout<T>.stride else { return nil }
        let ptr = UnsafeMutableRawPointer.allocate(byteCount: size, alignment: MemoryLayout<T>.alignment)
        defer { ptr.deallocate() }
        guard sysctlbyname(name, ptr, &size, nil, 0) == 0 else { return nil }
        return ptr.load(as: T.self)
    }

    /// Seconds since the machine booted, from KERN_BOOTTIME (a `timeval` fetched via the mib form of
    /// sysctl, which sysctlbyname doesn't cover). 0 if the boot clock isn't available yet.
    static func uptime() -> Double {
        var tv = timeval()
        var size = MemoryLayout<timeval>.stride
        var mib = [CTL_KERN, KERN_BOOTTIME]
        guard sysctl(&mib, 2, &tv, &size, nil, 0) == 0, tv.tv_sec != 0 else { return 0 }
        let boot = Double(tv.tv_sec) + Double(tv.tv_usec) / 1_000_000
        return max(0, Date().timeIntervalSince1970 - boot)
    }
}
