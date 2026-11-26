import SwiftUI
import AMSIcons

// The web app's colours, exactly (css/style.css v1.51). A habit's own colour always means that habit;
// blue is buttons and links; green / yellow / red are the fasting signals; amber text = needs a look.

enum Palette {
    /// The eight habit colours, in the web app's order. A new habit takes `all[count % 8]`.
    static let all = ["#3b70f0", "#e0447c", "#2fa96d", "#ee8b2c", "#d9463e", "#7a5af8", "#2aa8c4", "#c9a227"]
    static let names = ["Blue", "Pink", "Green", "Orange", "Red", "Purple", "Teal", "Yellow"]
}

enum Ink {
    static let accent = Color(hex: "#3b70f0")
    static let green = Color(hex: "#2fa96d")
    static let red = Color(hex: "#d9463e")
    static let amber = Color(hex: "#e0a80f")
    static let danger = Color(hex: "#e5484d")
    static let gold = Color(hex: "#c9a227")

    static let bg = Color.dynamic(light: "#f2f4f8", dark: "#0d1117")
    static let surface = Color.dynamic(light: "#ffffff", dark: "#161b26")
    static let text = Color.dynamic(light: "#16181d", dark: "#eceef2")
    static let dim = Color.dynamic(light: "#656d7a", dark: "#8d93a1")
    static let border = Color.dynamic(light: "#000000", dark: "#ffffff", alphaLight: 0.07, alphaDark: 0.08)
    /// "Something is out of date or needs a look."
    static let stale = Color.dynamic(light: "#7a5b06", dark: "#e0a80f")
    static let chart = Color.dynamic(light: "#24925c", dark: "#2fa96d")
    static let shadow = Color.dynamic(light: "#141e3c", dark: "#000000", alphaLight: 0.06, alphaDark: 0.35)

    static func surfaceHex(_ scheme: ColorScheme) -> String { scheme == .dark ? "#161b26" : "#ffffff" }
}

extension Color {
    init(hex: String, alpha: Double = 1) {
        let (r, g, b) = RGB.parse(hex)
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }

    /// A colour that follows day and night by itself.
    static func dynamic(light: String, dark: String, alphaLight: Double = 1, alphaDark: Double = 1) -> Color {
        #if os(iOS)
        return Color(UIColor { t in
            let (r, g, b) = RGB.parse(t.userInterfaceStyle == .dark ? dark : light)
            return UIColor(red: r, green: g, blue: b, alpha: t.userInterfaceStyle == .dark ? alphaDark : alphaLight)
        })
        #else
        return Color(NSColor(name: nil) { a in
            let isDark = a.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let (r, g, b) = RGB.parse(isDark ? dark : light)
            return NSColor(srgbRed: r, green: g, blue: b, alpha: isDark ? alphaDark : alphaLight)
        })
        #endif
    }

    /// The habit colour mixed into the card surface, in OKLab (17 % on Today's cards, 10 % in the preview) —
    /// the web app's `color-mix(in oklab, …)`; sRGB would wash purples out.
    static func tint(_ hex: String, _ amount: Double, _ scheme: ColorScheme) -> Color {
        Color(hex: OKLab.mix(hex, Ink.surfaceHex(scheme), amount))
    }
}

enum RGB {
    static func parse(_ hex: String) -> (Double, Double, Double) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return (0.23, 0.44, 0.94) }
        return (Double((v >> 16) & 0xff) / 255, Double((v >> 8) & 0xff) / 255, Double(v & 0xff) / 255)
    }
    static func hex(_ r: Double, _ g: Double, _ b: Double) -> String {
        func c(_ x: Double) -> Int { Int((min(1, max(0, x)) * 255).rounded()) }
        return String(format: "#%02x%02x%02x", c(r), c(g), c(b))
    }
}

/// Björn Ottosson's OKLab, for colour mixing that keeps a colour's character.
enum OKLab {
    private static func toLinear(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
    private static func toGamma(_ c: Double) -> Double { c <= 0.0031308 ? 12.92 * c : 1.055 * pow(c, 1 / 2.4) - 0.055 }

    static func lab(_ hex: String) -> (Double, Double, Double) {
        let (R, G, B) = RGB.parse(hex)
        let r = toLinear(R), g = toLinear(G), b = toLinear(B)
        let l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
        let m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
        let s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
        return (0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
                1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
                0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)
    }
    static func hex(_ L: Double, _ a: Double, _ b: Double) -> String {
        let l = pow(L + 0.3963377774 * a + 0.2158037573 * b, 3)
        let m = pow(L - 0.1055613458 * a - 0.0638541728 * b, 3)
        let s = pow(L - 0.0894841775 * a - 1.2914855480 * b, 3)
        return RGB.hex(toGamma(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s),
                       toGamma(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s),
                       toGamma(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s))
    }
    /// `amount` of `a` in `b`.
    static func mix(_ a: String, _ b: String, _ amount: Double) -> String {
        let x = lab(a), y = lab(b)
        return hex(x.0 * amount + y.0 * (1 - amount), x.1 * amount + y.1 * (1 - amount), x.2 * amount + y.2 * (1 - amount))
    }
}

// MARK: - Icons

/// One of the web app's hand-drawn icons (TrackIcons), in any colour and size.
struct TrackIcon: View {
    let name: String
    var size: CGFloat = 24
    var color: Color = Ink.text
    var lineWidth: Double = 1.7
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let strokes = TrackIcons.strokes[name] ?? TrackIcons.strokes["sun"] ?? []
        ZStack {
            ForEach(Array(strokes.enumerated()), id: \.offset) { _, s in
                let w = CGFloat(s.width ?? lineWidth) * size / 24
                if s.surfaceFill {
                    GridShape(d: s.d).fill(Ink.surface)
                }
                GridShape(d: s.d).stroke(color, style: StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
