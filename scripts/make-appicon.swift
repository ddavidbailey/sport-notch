#!/usr/bin/env swift
import AppKit

// Generates the Sport Notch app icon: a soccerball resting on a mown pitch,
// inside the standard macOS rounded-rectangle body. Resolution-independent —
// every size is drawn from scratch, not downscaled, so edges stay crisp.
//
// Usage:
//   swift scripts/make-appicon.swift            # build Resources/AppIcon.icns
//   swift scripts/make-appicon.swift --preview /tmp/icon.png   # one 1024 PNG

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

func col(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: a)
}

func drawIcon(_ S: CGFloat) -> NSBitmapImageRep {
    let px = Int(S)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: S, height: S)

    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    ctx.cgContext.clear(CGRect(x: 0, y: 0, width: S, height: S))
    ctx.imageInterpolation = .high

    let k = S / 1024.0
    let detail = S >= 128            // skip fine texture on tiny icons

    // --- macOS rounded-rect body, nudged up so its contact shadow has room ---
    let margin: CGFloat = 100 * k
    let bodyW = S - margin * 2
    let bodyRect = CGRect(x: margin, y: margin + 6 * k, width: bodyW, height: bodyW)
    let radius = bodyW * 0.2237
    let body = NSBezierPath(roundedRect: bodyRect, xRadius: radius, yRadius: radius)
    let cx = bodyRect.midX, cy = bodyRect.midY

    // contact shadow under the whole icon
    NSGraphicsContext.saveGraphicsState()
    let cast = NSShadow()
    cast.shadowColor = col(0x000000, 0.30)
    cast.shadowBlurRadius = 36 * k
    cast.shadowOffset = NSSize(width: 0, height: -9 * k)
    cast.set()
    col(0x0A5A27).set()
    body.fill()
    NSGraphicsContext.restoreGraphicsState()

    // pitch: top-lit vertical gradient, faint mown stripes, edge vignette
    NSGraphicsContext.saveGraphicsState()
    body.addClip()
    NSGradient(colors: [col(0x1CB14E), col(0x0A5A27)])!.draw(in: bodyRect, angle: -90)

    if detail {
        // Tonal mown stripes: alternating darker turf bands, kept very quiet so
        // they read as "field" rather than printed bars.
        let stripes = 7
        let w = bodyRect.width / CGFloat(stripes)
        for i in 0..<stripes where i % 2 == 1 {
            col(0x041F0E, 0.13).setFill()
            NSBezierPath(rect: CGRect(x: bodyRect.minX + CGFloat(i) * w,
                                      y: bodyRect.minY, width: w, height: bodyRect.height)).fill()
        }
        let vign = NSGradient(colors: [col(0x000000, 0.0), col(0x062A14, 0.20)])!
        vign.draw(fromCenter: CGPoint(x: cx, y: cy), radius: bodyW * 0.34,
                  toCenter: CGPoint(x: cx, y: cy), radius: bodyW * 0.76, options: [])
    }
    NSGraphicsContext.restoreGraphicsState()

    // --- the ball ---
    let ballD = bodyW * 0.63
    let ballRect = CGRect(x: cx - ballD / 2, y: cy - ballD / 2 + bodyW * 0.01,
                          width: ballD, height: ballD)
    let ballPath = NSBezierPath(ovalIn: ballRect)

    // drop shadow → resting on grass
    NSGraphicsContext.saveGraphicsState()
    let drop = NSShadow()
    drop.shadowColor = col(0x041C0E, 0.50)
    drop.shadowBlurRadius = 24 * k
    drop.shadowOffset = NSSize(width: 0, height: -11 * k)
    drop.set()
    col(0xF6F7F3).set()
    ballPath.fill()
    NSGraphicsContext.restoreGraphicsState()

    // volume: off-white radial shading
    NSGraphicsContext.saveGraphicsState()
    ballPath.addClip()
    let hi = CGPoint(x: ballRect.midX - ballD * 0.20, y: ballRect.midY + ballD * 0.20)
    NSGradient(colors: [col(0xFFFFFF), col(0xE7EAE1)])!
        .draw(fromCenter: hi, radius: ballD * 0.04,
              toCenter: CGPoint(x: ballRect.midX, y: ballRect.midY), radius: ballD * 0.62, options: [])
    NSGraphicsContext.restoreGraphicsState()

    // ink seam pattern (Apple's soccerball glyph, recolored)
    if let base = NSImage(systemSymbolName: "soccerball", accessibilityDescription: nil),
       let sym = base.withSymbolConfiguration(.init(pointSize: ballD, weight: .regular)) {
        let tinted = NSImage(size: sym.size)
        tinted.lockFocus()
        col(0x14161A).set()
        let rr = NSRect(origin: .zero, size: sym.size)
        sym.draw(in: rr)
        rr.fill(using: .sourceAtop)
        tinted.unlockFocus()

        let aspect = sym.size.width / sym.size.height
        let h = ballD * 0.96
        let w = h * aspect
        tinted.draw(in: CGRect(x: ballRect.midX - w / 2, y: ballRect.midY - h / 2, width: w, height: h))
    }

    // sheen
    NSGraphicsContext.saveGraphicsState()
    ballPath.addClip()
    let sc = CGPoint(x: ballRect.midX - ballD * 0.22, y: ballRect.midY + ballD * 0.24)
    NSGradient(colors: [col(0xFFFFFF, 0.22), col(0xFFFFFF, 0.0)])!
        .draw(fromCenter: sc, radius: 0, toCenter: sc, radius: ballD * 0.52, options: [])
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func png(_ rep: NSBitmapImageRep, _ path: String) {
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

let args = CommandLine.arguments
if args.count >= 3, args[1] == "--preview" {
    png(drawIcon(1024), args[2])
    print("preview → \(args[2])")
    exit(0)
}

// Full iconset → .icns
let fm = FileManager.default
let root = URL(fileURLWithPath: fm.currentDirectoryPath)
let iconset = root.appendingPathComponent(".build/AppIcon.iconset")
try? fm.removeItem(at: iconset)
try! fm.createDirectory(at: iconset, withIntermediateDirectories: true)

let specs: [(Int, Int)] = [(16,1),(16,2),(32,1),(32,2),(128,1),(128,2),(256,1),(256,2),(512,1),(512,2)]
for (pt, scale) in specs {
    let pxSize = pt * scale
    let name = scale == 1 ? "icon_\(pt)x\(pt).png" : "icon_\(pt)x\(pt)@2x.png"
    png(drawIcon(CGFloat(pxSize)), iconset.appendingPathComponent(name).path)
}

let resources = root.appendingPathComponent("Resources")
try? fm.createDirectory(at: resources, withIntermediateDirectories: true)
let icns = resources.appendingPathComponent("AppIcon.icns").path
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", icns]
try! task.run()
task.waitUntilExit()
print(task.terminationStatus == 0 ? "wrote \(icns)" : "iconutil failed (\(task.terminationStatus))")
