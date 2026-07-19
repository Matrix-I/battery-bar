// IOSDeviceSection.swift — the iPhone/iPad block used to live here as its own View (IOSDevicesSection
// wrapping a per-device IOSDeviceRow). It is now folded into BatteryDetailView as the `iPhoneSection`
// computed property, which renders the primary connected iPhone INLINE — a single value read with its
// rows written straight into the panel VStack, exactly like the Mac "Battery" block. That removed the
// ForEach over the 1 Hz-replaced device array whose per-tick row rebuilds were snapping the expand
// animation (the "giật" bug). The row markup now lives next to the Mac battery markup it mirrors, so
// nothing from this file is referenced any more. Kept as a placeholder so the source file list stays
// stable; see iPhoneSection in BatteryDetailView.swift for the live code.

import SwiftUI
