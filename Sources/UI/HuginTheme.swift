import SwiftUI

enum HuginColor {
    static let basalt = Color(hex: 0x0E0F12)
    static let schiefer = Color(hex: 0x1D1F24)
    static let seitenleiste = Color(hex: 0x121317)
    static let karte = Color(hex: 0x131418)
    static let composer = Color(hex: 0x16171B)
    static let dialog = Color(hex: 0x17181C)
    static let knochen = Color(hex: 0xECE6D9)
    static let asche = Color(hex: 0x9A958B)
    static let glut = Color(hex: 0xEE9A3C)
    static let glutHighlight = Color(hex: 0xF7BE6E)
    static let frost = Color(hex: 0xBEE4F0)
    static let rost = Color(hex: 0xE0613F)
    static let rostText = Color(hex: 0xF2A48E)   // Diff: entfernte Zeilen (Design §5.4)
    static let border1 = Color(hex: 0x23252B)
    static let border2 = Color(hex: 0x2A2C33)
    static let border3 = Color(hex: 0x3A3D45)

    /// „Farbe sagt, wer denkt“: Glut = lokal, Frost = Claude
    static func actor(_ a: Actor?) -> Color {
        a == .claude ? frost : glut
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

enum HuginFont {
    // PostScript-Namen der gebündelten TTFs (UIAppFonts registriert genau diese)
    static func geist(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        switch weight {
        case .medium: return .custom("Geist-Medium", size: size)
        case .semibold, .bold: return .custom("Geist-SemiBold", size: size)
        default: return .custom("Geist-Regular", size: size)
        }
    }
    static func geistMono(_ size: CGFloat) -> Font {
        .custom("GeistMono-Regular", size: size)
    }
}

enum HuginMotion {
    static let gleiten = Animation.timingCurve(0.2, 0.8, 0.2, 1, duration: 0.52)
    static let atmen = Animation.easeInOut(duration: 4.2).repeatForever(autoreverses: true)
    static let aufflammen = Animation.easeOut(duration: 0.18)
    static let einsinken = Animation.easeIn(duration: 0.7)
    static let aufblenden = Animation.easeOut(duration: 0.24)
}

enum HuginRadius {
    static let bubble: CGFloat = 26
    static let card: CGFloat = 20
    static let pill: CGFloat = 22
    static let chip: CGFloat = 8
}
