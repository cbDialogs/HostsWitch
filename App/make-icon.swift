import AppKit

// Moonlit indigo rounded square, a crescent moon, and the ember witch's hat.
let sizes = [16, 32, 64, 128, 256, 512, 1024]
let iconset = URL(fileURLWithPath: "AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r/255, green: g/255, blue: b/255, alpha: a)
}
let indigo = rgb(0x1B, 0x15, 0x30)
let deep   = rgb(0x0B, 0x08, 0x14)
let silver = rgb(0xE6, 0xE0, 0xF4)
let ember  = rgb(0xF0, 0x89, 0x4A)

func draw(_ px: Int) -> NSImage {
    let s = CGFloat(px)
    let img = NSImage(size: NSSize(width: s, height: s))
    img.lockFocus()
    let inset = s * 0.09
    let rect = NSRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let square = NSBezierPath(roundedRect: rect, xRadius: s * 0.185, yRadius: s * 0.185)

    NSGradient(starting: indigo, ending: deep)!.draw(in: square, angle: -70)

    // moon glow + crescent, upper right
    square.addClip()
    let moonR = s * 0.16
    let moonC = NSPoint(x: rect.maxX - s * 0.20, y: rect.maxY - s * 0.20)
    let glow = NSBezierPath(ovalIn: NSRect(x: moonC.x - moonR * 2.2, y: moonC.y - moonR * 2.2, width: moonR * 4.4, height: moonR * 4.4))
    silver.withAlphaComponent(0.08).setFill(); glow.fill()
    let moon = NSBezierPath(ovalIn: NSRect(x: moonC.x - moonR, y: moonC.y - moonR, width: moonR * 2, height: moonR * 2))
    silver.setFill(); moon.fill()
    let bite = NSBezierPath(ovalIn: NSRect(x: moonC.x - moonR * 0.55, y: moonC.y - moonR * 0.75, width: moonR * 2, height: moonR * 2))
    NSGradient(starting: indigo, ending: deep)!.draw(in: bite, angle: -70)

    // the hat, stroked in ember with a soft glow
    let box = NSRect(x: rect.minX + rect.width * 0.14, y: rect.minY + rect.height * 0.12,
                     width: rect.width * 0.72, height: rect.width * 0.72)
    func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
        NSPoint(x: box.minX + x / 24 * box.width, y: box.maxY - y / 24 * box.height)
    }
    let hat = NSBezierPath()
    hat.lineWidth = max(1.2, s * 0.055)
    hat.lineCapStyle = .round
    hat.lineJoinStyle = .round
    hat.move(to: p(2.5, 18.5))
    hat.curve(to: p(21.5, 18.5), controlPoint1: p(6, 21.2), controlPoint2: p(18, 21.2))
    hat.move(to: p(6, 18))
    hat.line(to: p(11.2, 4.2))
    hat.curve(to: p(12.8, 4.2), controlPoint1: p(11.5, 3.2), controlPoint2: p(12.5, 3.2))
    hat.line(to: p(14, 8.2))
    hat.line(to: p(18, 18))
    hat.move(to: p(8.2, 13.6))
    hat.curve(to: p(15.8, 13.6), controlPoint1: p(10.6, 14.8), controlPoint2: p(13.4, 14.8))

    if px >= 64 {
        let shadow = NSShadow()
        shadow.shadowColor = ember.withAlphaComponent(0.55)
        shadow.shadowBlurRadius = s * 0.06
        shadow.set()
    }
    ember.setStroke(); hat.stroke()

    img.unlockFocus()
    return img
}

for px in sizes {
    let img = draw(px)
    guard let tiff = img.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { continue }
    if px <= 512 {
        try! png.write(to: iconset.appendingPathComponent("icon_\(px)x\(px).png"))
    }
    if px >= 32 {
        try! png.write(to: iconset.appendingPathComponent("icon_\(px/2)x\(px/2)@2x.png"))
    }
}
print("iconset ready")
