import SwiftUI
import CoreText

// The Coven palette, lifted from the approved mockup (design/generate.py).
enum Theme {
    static let backdrop  = Color(hex: 0x0B0814)
    static let window    = Color(hex: 0x1B1530)   // editor / main pane
    static let side      = Color(hex: 0x150F28)   // sidebar, toolbar, status bar
    static let border    = Color(hex: 0x2E2650)
    static let text      = Color(hex: 0xE6E0F4)   // moon silver
    static let muted     = Color(hex: 0xA89ECB)
    static let faint     = Color(hex: 0x6F6592)
    static let accent    = Color(hex: 0xF0894A)   // ember
    static let onAccent  = Color(hex: 0x1B1530)
    static let selected  = Color(hex: 0x2B2250)
    static let hover     = Color(hex: 0x221B40)
    static let comment   = Color(hex: 0x8C82B3)
    static let highlight = Color(hex: 0x261E48)   // managed block in View
    static let field     = Color(hex: 0x231C3E)   // search / secondary buttons
    static let offTrack  = Color(hex: 0x3A3358)

    static let nsWindow    = NSColor(hex: 0x1B1530)
    static let nsText      = NSColor(hex: 0xE6E0F4)
    static let nsAccent    = NSColor(hex: 0xF0894A)
    static let nsComment   = NSColor(hex: 0x8C82B3)
    static let nsFaint     = NSColor(hex: 0x6F6592)
    static let nsHighlight = NSColor(hex: 0x261E48)
    static let nsSelection = NSColor(hex: 0x3A2E6A)

    static private(set) var hasCormorant = false
    static private(set) var hasJetBrains = false

    static func registerFonts() {
        guard let dir = Bundle.main.resourceURL?.appendingPathComponent("Fonts") else { return }
        for name in ["CormorantGaramond.ttf", "CormorantGaramond-Italic.ttf", "JetBrainsMono.ttf"] {
            let url = dir.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: url.path) {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
        hasCormorant = NSFont(name: "CormorantGaramond-SemiBold", size: 12) != nil
        hasJetBrains = NSFont(name: "JetBrainsMono-Regular", size: 12) != nil
    }

    /// Display serif for the window title and breadcrumb.
    static func serif(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        hasCormorant
            ? Font.custom(weight == .regular ? "CormorantGaramond-Regular" : "CormorantGaramond-SemiBold", size: size)
            : Font.system(size: size, weight: weight, design: .serif)
    }
    static func serifItalic(_ size: CGFloat) -> Font {
        hasCormorant
            ? Font.custom("CormorantGaramond-Italic", size: size)
            : Font.system(size: size, design: .serif).italic()
    }
    static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight)
    }
    static func mono(_ size: CGFloat) -> Font {
        hasJetBrains ? Font.custom("JetBrainsMono-Regular", size: size)
                     : Font.system(size: size, design: .monospaced)
    }
    static func nsMono(_ size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        if hasJetBrains, let f = NSFont(name: weight == .regular ? "JetBrainsMono-Regular" : "JetBrainsMono-SemiBold", size: size) {
            return f
        }
        return NSFont.monospacedSystemFont(ofSize: size, weight: weight)
    }

    // MARK: - the hat

    /// The witch's hat, as a path in a 24×24 box (y down), matching the
    /// mockup's stroke icon.
    static func hatPath(in box: CGRect, lineWidth: CGFloat) -> NSBezierPath {
        let s = box.width / 24
        func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
            NSPoint(x: box.minX + x * s, y: box.maxY - y * s)   // flip y
        }
        let path = NSBezierPath()
        path.lineWidth = lineWidth
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        // brim
        path.move(to: p(2.5, 18.5))
        path.curve(to: p(21.5, 18.5), controlPoint1: p(6, 21.2), controlPoint2: p(18, 21.2))
        // cone, bent tip
        path.move(to: p(6, 18))
        path.line(to: p(11.2, 4.2))
        path.curve(to: p(12.8, 4.2), controlPoint1: p(11.5, 3.2), controlPoint2: p(12.5, 3.2))
        path.line(to: p(14, 8.2))
        path.line(to: p(18, 18))
        // band
        path.move(to: p(8.2, 13.6))
        path.curve(to: p(15.8, 13.6), controlPoint1: p(10.6, 14.8), controlPoint2: p(13.4, 14.8))
        return path
    }

    /// Template image for the menu bar (tinted by the system).
    static let menuBarIcon: NSImage = {
        let size = NSSize(width: 18, height: 18)
        let img = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setStroke()
            hatPath(in: rect.insetBy(dx: 1, dy: 1), lineWidth: 1.7).stroke()
            return true
        }
        img.isTemplate = true
        return img
    }()
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red:   Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue:  Double(hex & 0xFF) / 255)
    }
}

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green:   CGFloat((hex >> 8) & 0xFF) / 255,
                  blue:    CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

/// The hat as a SwiftUI shape, for the toolbar.
struct HatShape: Shape {
    func path(in rect: CGRect) -> Path {
        let s = rect.width / 24
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * s, y: rect.minY + y * s) }
        var path = Path()
        path.move(to: p(2.5, 18.5))
        path.addCurve(to: p(21.5, 18.5), control1: p(6, 21.2), control2: p(18, 21.2))
        path.move(to: p(6, 18))
        path.addLine(to: p(11.2, 4.2))
        path.addCurve(to: p(12.8, 4.2), control1: p(11.5, 3.2), control2: p(12.5, 3.2))
        path.addLine(to: p(14, 8.2))
        path.addLine(to: p(18, 18))
        path.move(to: p(8.2, 13.6))
        path.addCurve(to: p(15.8, 13.6), control1: p(10.6, 14.8), control2: p(13.4, 14.8))
        return path
    }
}
