import AppKit
import Foundation

let outputPath = CommandLine.arguments.dropFirst().first ?? "AppIcon.icns"
let outputURL = URL(fileURLWithPath: outputPath)
let iconsetURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("AgentRocky-\(UUID().uuidString).iconset", isDirectory: true)

try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
defer {
    try? FileManager.default.removeItem(at: iconsetURL)
}

let variants: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for variant in variants {
    let image = NSImage(size: NSSize(width: variant.pixels, height: variant.pixels))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: variant.pixels, height: variant.pixels)
    NSColor(calibratedRed: 0.025, green: 0.05, blue: 0.04, alpha: 1).setFill()
    NSBezierPath(roundedRect: rect, xRadius: CGFloat(variant.pixels) * 0.22, yRadius: CGFloat(variant.pixels) * 0.22).fill()

    let glowRect = rect.insetBy(dx: CGFloat(variant.pixels) * 0.12, dy: CGFloat(variant.pixels) * 0.12)
    NSColor(calibratedRed: 0.36, green: 1.0, blue: 0.58, alpha: 0.9).setStroke()
    let glow = NSBezierPath(roundedRect: glowRect, xRadius: CGFloat(variant.pixels) * 0.18, yRadius: CGFloat(variant.pixels) * 0.18)
    glow.lineWidth = max(2, CGFloat(variant.pixels) * 0.035)
    glow.stroke()

    let bodyRect = rect.insetBy(dx: CGFloat(variant.pixels) * 0.26, dy: CGFloat(variant.pixels) * 0.24)
    NSColor(calibratedRed: 0.42, green: 1.0, blue: 0.58, alpha: 1).setFill()
    NSBezierPath(roundedRect: bodyRect, xRadius: CGFloat(variant.pixels) * 0.11, yRadius: CGFloat(variant.pixels) * 0.11).fill()

    NSColor(calibratedRed: 0.02, green: 0.04, blue: 0.035, alpha: 1).setFill()
    let eyeSize = max(2, CGFloat(variant.pixels) * 0.07)
    let eyeY = bodyRect.midY + CGFloat(variant.pixels) * 0.07
    NSBezierPath(ovalIn: NSRect(x: bodyRect.midX - CGFloat(variant.pixels) * 0.11, y: eyeY, width: eyeSize, height: eyeSize)).fill()
    NSBezierPath(ovalIn: NSRect(x: bodyRect.midX + CGFloat(variant.pixels) * 0.06, y: eyeY, width: eyeSize, height: eyeSize)).fill()

    image.unlockFocus()

    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "AgentRockyIcon", code: 1)
    }

    try png.write(to: iconsetURL.appendingPathComponent(variant.name))
}

try? FileManager.default.removeItem(at: outputURL)
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["--convert", "icns", "--output", outputURL.path, iconsetURL.path]
try process.run()
process.waitUntilExit()

if process.terminationStatus != 0 {
    throw NSError(domain: "AgentRockyIcon", code: Int(process.terminationStatus))
}
