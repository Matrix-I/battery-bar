// icon_gen.swift — generates AppIcon_1024.png (source art for AppIcon.icns)
// Run: swiftc icon_gen.swift -o icon_gen && ./icon_gen

import AppKit

let size: CGFloat = 1024

func tinted(_ image: NSImage, color: NSColor, size: NSSize) -> NSImage {
    let out = NSImage(size: size)
    out.lockFocus()
    image.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .sourceOver, fraction: 1.0)
    color.set()
    NSRect(origin: .zero, size: size).fill(using: .sourceAtop)
    out.unlockFocus()
    return out
}

let canvas = NSImage(size: NSSize(width: size, height: size))
canvas.lockFocus()

// Background: rounded square (macOS-style squircle approximation), dark charcoal gradient
let cornerRadius = size * 0.225
let bgPath = NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: size, height: size),
                          xRadius: cornerRadius, yRadius: cornerRadius)
NSGradient(colors: [
    NSColor(calibratedRed: 0.13, green: 0.13, blue: 0.15, alpha: 1.0),
    NSColor(calibratedRed: 0.05, green: 0.05, blue: 0.06, alpha: 1.0),
])?.draw(in: bgPath, angle: -90)

// Foreground: battery + bolt glyph, green (matches the app's "healthy battery" color)
let config = NSImage.SymbolConfiguration(pointSize: size * 0.52, weight: .semibold)
if let base = NSImage(systemSymbolName: "battery.100percent.bolt", accessibilityDescription: nil)?
    .withSymbolConfiguration(config) {
    let green = NSColor(calibratedRed: 0.20, green: 0.84, blue: 0.44, alpha: 1.0)
    let glyph = tinted(base, color: green, size: base.size)
    let origin = NSPoint(x: (size - glyph.size.width) / 2, y: (size - glyph.size.height) / 2)
    glyph.draw(at: origin, from: .zero, operation: .sourceOver, fraction: 1.0)
}

canvas.unlockFocus()

guard let tiff = canvas.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("failed to render icon")
}
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon_1024.png"
try! png.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
