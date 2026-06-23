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

// --- real truncated-icosahedron geometry (the actual shape of a football) ---
typealias V3 = (x: Double, y: Double, z: Double)
func vadd(_ a: V3, _ b: V3) -> V3 { (a.x + b.x, a.y + b.y, a.z + b.z) }
func vsub(_ a: V3, _ b: V3) -> V3 { (a.x - b.x, a.y - b.y, a.z - b.z) }
func vdot(_ a: V3, _ b: V3) -> Double { a.x * b.x + a.y * b.y + a.z * b.z }
func vscale(_ a: V3, _ s: Double) -> V3 { (a.x * s, a.y * s, a.z * s) }
func vcross(_ a: V3, _ b: V3) -> V3 {
    (a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
}
func vlen(_ a: V3) -> Double { vdot(a, a).squareRoot() }
func vnorm(_ a: V3) -> V3 { let l = vlen(a); return (a.x / l, a.y / l, a.z / l) }

struct Football { let verts: [V3]; let pentagons: [[Int]]; let edges: [(Int, Int)] }

// The 60 vertices (even/cyclic permutations of the canonical coordinate set,
// edge length 2), the 12 pentagonal faces (the 5 vertices nearest each
// icosahedral axis), and the 90 edges (vertex pairs one edge-length apart).
let football: Football = {
    let phi = (1.0 + 5.0.squareRoot()) / 2.0
    func cyc(_ a: Double, _ b: Double, _ c: Double) -> [V3] { [(a, b, c), (b, c, a), (c, a, b)] }

    var verts: [V3] = []
    for s1 in [1.0, -1.0] { for s2 in [1.0, -1.0] {
        verts += cyc(0, s1, s2 * 3 * phi)                       // (0, ±1, ±3φ)
    } }
    for s1 in [1.0, -1.0] { for s2 in [1.0, -1.0] { for s3 in [1.0, -1.0] {
        verts += cyc(s1, s2 * (2 + phi), s3 * 2 * phi)          // (±1, ±(2+φ), ±2φ)
    } } }
    for s1 in [1.0, -1.0] { for s2 in [1.0, -1.0] { for s3 in [1.0, -1.0] {
        verts += cyc(s1 * phi, s2 * 2, s3 * (2 * phi + 1))      // (±φ, ±2, ±(2φ+1))
    } } }

    var pentagons: [[Int]] = []
    for s1 in [1.0, -1.0] { for s2 in [1.0, -1.0] {
        for axis in cyc(0, s1, s2 * phi) {                      // 12 icosahedral axes
            let a = vnorm(axis)
            let near = (0..<verts.count).sorted { vdot(verts[$0], a) > vdot(verts[$1], a) }
            pentagons.append(Array(near.prefix(5)))
        }
    } }

    var edges: [(Int, Int)] = []
    for i in 0..<verts.count { for j in (i + 1)..<verts.count {
        if vlen(vsub(verts[i], verts[j])) < 2.1 { edges.append((i, j)) }
    } }

    return Football(verts: verts, pentagons: pentagons, edges: edges)
}()

// Draw the football pattern into a circle of radius `R` centred at `bc`: one
// pentagonal face is rotated to face the viewer (a vertex pointing up), the
// front pentagons are filled, and every front edge is stroked so the white
// hexagons read as connected patches — a real ball, not floating shapes.
func drawFootball(_ bc: CGPoint, _ R: CGFloat, _ ink: NSColor, _ seamW: CGFloat) {
    let phi = (1.0 + 5.0.squareRoot()) / 2.0
    let rho = (1.0 + 9.0 * phi * phi).squareRoot()             // circumradius
    // Zoom in slightly so the rim pentagons reach the silhouette and are cropped
    // by the ball edge, instead of leaving a white equatorial halo around them.
    let overscan = 1.20
    let scale = Double(R) / rho * overscan

    // Build a view basis: central pentagon's axis -> +z (toward viewer), and one
    // of its vertices -> +y (up).
    let p0 = football.pentagons[0]
    var axis: V3 = (0, 0, 0)
    for k in p0 { axis = vadd(axis, football.verts[k]) }
    let zc = vnorm(axis)
    let top = football.verts[p0[0]]
    let yc = vnorm(vsub(top, vscale(zc, vdot(top, zc))))
    let xc = vcross(yc, zc)

    func project(_ p: V3) -> (pt: CGPoint, depth: Double) {
        (CGPoint(x: bc.x + CGFloat(vdot(p, xc) * scale),
                 y: bc.y + CGFloat(vdot(p, yc) * scale)), vdot(p, zc))
    }

    // fill the front-facing pentagons
    ink.setFill()
    for pent in football.pentagons {
        var c: V3 = (0, 0, 0)
        for k in pent { c = vadd(c, football.verts[k]) }
        if vdot(vnorm(c), zc) <= 0.12 { continue }            // back / edge-on: skip
        let pts = pent.map { project(football.verts[$0]).pt }
        let mx = pts.map(\.x).reduce(0, +) / CGFloat(pts.count)
        let my = pts.map(\.y).reduce(0, +) / CGFloat(pts.count)
        let ring = pts.sorted { atan2($0.y - my, $0.x - mx) < atan2($1.y - my, $1.x - mx) }
        let path = NSBezierPath()
        path.move(to: ring[0])
        for q in ring.dropFirst() { path.line(to: q) }
        path.close()
        path.fill()
    }

    // stroke the seam network (front edges only)
    ink.set()
    let seams = NSBezierPath()
    seams.lineWidth = seamW
    seams.lineCapStyle = .round
    seams.lineJoinStyle = .round
    for (i, j) in football.edges {
        let a = project(football.verts[i]), b = project(football.verts[j])
        if a.depth > 0, b.depth > 0 { seams.move(to: a.pt); seams.line(to: b.pt) }
    }
    seams.stroke()
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

    // volume: sphere shading — bright upper-left highlight fades to muted lower-right
    NSGraphicsContext.saveGraphicsState()
    ballPath.addClip()
    let hi = CGPoint(x: ballRect.midX - ballD * 0.20, y: ballRect.midY + ballD * 0.20)
    NSGradient(colors: [col(0xFFFFFF), col(0xD6DAD2)])!
        .draw(fromCenter: hi, radius: ballD * 0.03,
              toCenter: CGPoint(x: ballRect.midX + ballD * 0.10, y: ballRect.midY - ballD * 0.10),
              radius: ballD * 0.70, options: [])
    // rim darkening for depth
    NSGradient(colors: [col(0x9EA49A, 0.0), col(0x6E7469, 0.22)])!
        .draw(fromCenter: CGPoint(x: ballRect.midX, y: ballRect.midY), radius: ballD * 0.48,
              toCenter: CGPoint(x: ballRect.midX + ballD * 0.12, y: ballRect.midY - ballD * 0.12),
              radius: ballD * 0.72, options: [])
    NSGraphicsContext.restoreGraphicsState()

    // Telstar pattern, drawn from the real truncated-icosahedron geometry so the
    // black pentagons connect at their corners through the white hexagons — a
    // genuine football rather than floating shapes.
    NSGraphicsContext.saveGraphicsState()
    ballPath.addClip()
    drawFootball(CGPoint(x: ballRect.midX, y: ballRect.midY), ballD / 2,
                 col(0x161616), max(1, 0.012 * ballD))
    NSGraphicsContext.restoreGraphicsState()

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
