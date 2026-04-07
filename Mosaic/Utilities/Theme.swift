import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Cross-platform image alias

#if os(macOS)
typealias PlatformImage = NSImage
#else
typealias PlatformImage = UIImage
#endif

// MARK: - Theme

enum MosaicTheme {
    static let ink = Color(hex: "0D0D0D")
    static let charcoal = Color(hex: "1C1C1E")
    static let graphite = Color(hex: "2C2C2E")
    static let stone = Color(hex: "8A8580")
    static let cream = Color(hex: "F5F0EB")
    static let saffron = Color(hex: "E8A838")
    static let saffronLight = Color(hex: "F5C563")
    static let ember = Color(hex: "D4654A")
    static let surface = Color(hex: "161618")
    static let canvasBackground = Color(hex: "111113")

    static let saffronGradient = LinearGradient(
        colors: [saffron, Color(hex: "D4943A")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let subtleGlow = LinearGradient(
        colors: [saffron.opacity(0.15), .clear],
        startPoint: .top,
        endPoint: .bottom
    )
}

// MARK: - Color from Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - View Modifiers

struct GlassBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .background(MosaicTheme.charcoal.opacity(0.6))
    }
}

extension View {
    func glassBackground() -> some View {
        modifier(GlassBackground())
    }
}
