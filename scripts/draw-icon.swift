// Génère l'icône de l'app (montre et iPhone) : un volant noir sur fond vert-jaune.
// Usage, depuis la racine du dépôt : swift scripts/draw-icon.swift
import AppKit

// Dessine un volant (bouchon en bas, jupe de plumes vers le haut), légèrement incliné.
func drawShuttle(in rect: CGRect, color: NSColor, corkColor: NSColor, lineColor: NSColor) {
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.saveGState()
    // Recentrage visuel : la rotation décale la forme vers le haut à droite.
    ctx.translateBy(x: rect.midX - 0.098 * rect.width, y: rect.midY - 0.078 * rect.width)
    ctx.rotate(by: -.pi / 7)
    let s = rect.width
    // Jupe : trapèze qui s'évase vers le haut.
    let skirt = NSBezierPath()
    skirt.move(to: CGPoint(x: -0.11 * s, y: -0.12 * s))
    skirt.line(to: CGPoint(x: 0.11 * s, y: -0.12 * s))
    skirt.line(to: CGPoint(x: 0.27 * s, y: 0.33 * s))
    skirt.curve(to: CGPoint(x: -0.27 * s, y: 0.33 * s),
                controlPoint1: CGPoint(x: 0.12 * s, y: 0.39 * s),
                controlPoint2: CGPoint(x: -0.12 * s, y: 0.39 * s))
    skirt.close()
    color.setFill(); skirt.fill()
    // Tiges des plumes.
    lineColor.setStroke()
    for i in -2...2 {
        let line = NSBezierPath()
        line.lineWidth = 0.012 * s
        let t = CGFloat(i) / 2
        line.move(to: CGPoint(x: t * 0.08 * s, y: -0.12 * s))
        line.line(to: CGPoint(x: t * 0.22 * s, y: 0.35 * s))
        line.stroke()
    }
    // Bague et bouchon.
    let ring = NSBezierPath(rect: CGRect(x: -0.12 * s, y: -0.15 * s, width: 0.24 * s, height: 0.035 * s))
    lineColor.setFill(); ring.fill()
    let cork = NSBezierPath()
    cork.move(to: CGPoint(x: -0.12 * s, y: -0.15 * s))
    cork.line(to: CGPoint(x: 0.12 * s, y: -0.15 * s))
    cork.curve(to: CGPoint(x: -0.12 * s, y: -0.15 * s),
               controlPoint1: CGPoint(x: 0.13 * s, y: -0.33 * s),
               controlPoint2: CGPoint(x: -0.13 * s, y: -0.33 * s))
    corkColor.setFill(); cork.fill()
    ctx.restoreGState()
}

let lime = NSColor(red: 0.78, green: 1.0, blue: 0.18, alpha: 1)
let ink = NSColor(red: 0.07, green: 0.08, blue: 0.09, alpha: 1)

func render(_ name: String, draw: (CGRect) -> Void) {
    let size = 1024
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw(CGRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.current = nil
    let png = rep.representation(using: .png, properties: [:])!
    for target in ["ShuttleScore", "ShuttleScorePhone"] {
        try! png.write(to: URL(fileURLWithPath: "\(target)/Assets.xcassets/AppIcon.appiconset/\(name).png"))
    }
}

// A : fond vert-jaune, volant noir.
render("AppIcon") { r in
    lime.setFill(); r.fill()
    drawShuttle(in: r.insetBy(dx: 120, dy: 120), color: ink, corkColor: ink, lineColor: lime)
}
