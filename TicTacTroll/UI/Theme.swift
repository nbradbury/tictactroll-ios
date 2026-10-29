import CoreText
import SwiftUI
import UIKit

extension Color {
    /// `darkenedTo` scales each channel, for shading a color toward black.
    init(hex: UInt32, alpha: Double = 1, darkenedTo factor: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red * factor, green: green * factor, blue: blue * factor, opacity: alpha)
    }

    // sRGB conversions of the design's oklch() values.
    static let cream = Color(hex: 0xF1EEE4)
    static let ink = Color(hex: 0xEEECE6)
    static let bubbleCream = Color(hex: 0xF5F2E8)
    static let bubbleInk = Color(hex: 0x1B1D1A)
    static let onAccent = Color(hex: 0x15231A)
    static let accent = Color(hex: 0x94D186)
    static let accentShadow = Color(hex: 0x518046)
    static let backgroundTop = Color(hex: 0x1F3D2D)
    static let backgroundBottom = Color(hex: 0x0C1711)
    static let sheetBackground = Color(hex: 0x080F0B)
    static let eyebrow = Color(hex: 0x9DB6A1)
    static let titleShadow = Color(hex: 0x12241A)
    static let muted = Color(hex: 0xABBDAD)
    static let mutedLabel = Color(hex: 0xA1B4A4)
    static let drawLabel = Color(hex: 0x92A495)
    static let outline = Color(hex: 0x4A5A4D)
    static let scrim = Color.black.opacity(0.25)

    static let gorp = Color(hex: 0x78BFF9)
    static let bramble = Color(hex: 0xF9A870)

    static let crateBorder = Color(hex: 0x4E301B)
    static let crateBrace = Color(hex: 0x563822)
    static let cratePlank = Color(hex: 0x755233)
    static let crateSeam = Color(hex: 0x3D281A)
    static let crateShadow = Color(hex: 0x25170D)
    static let dirtTop = Color(hex: 0x2C2615)
    static let dirtBottom = Color(hex: 0x1A160B)
    static let grass = Color(hex: 0x324023)
}

enum FontWeightValue: CGFloat {
    case normal = 400
    case medium = 500
    case bold = 700
}

extension Font {
    /// Registers the bundled fonts once, before any text uses them.
    static func registerAppFonts() {
        for name in ["dm_sans", "jetbrains_mono", "lilita_one", "rubik_dirt"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    /// DM Sans and JetBrains Mono are variable fonts, so the weight is set on the `wght` axis.
    private static func variable(_ family: String, _ size: CGFloat, _ weight: FontWeightValue) -> Font {
        let wght = 0x7767_6874 // 'wght'
        let descriptor = UIFontDescriptor(fontAttributes: [
            .family: family,
            .size: size,
            UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): [wght: weight.rawValue],
        ])
        return Font(UIFont(descriptor: descriptor, size: size))
    }

    static func sans(_ size: CGFloat, _ weight: FontWeightValue = .medium) -> Font {
        variable("DM Sans", size, weight)
    }

    static func mono(_ size: CGFloat) -> Font { variable("JetBrains Mono", size, .medium) }

    static func lilita(_ size: CGFloat) -> Font { .custom("LilitaOne", fixedSize: size) }

    static func dirt(_ size: CGFloat) -> Font { .custom("RubikDirt-Regular", fixedSize: size) }
}
