import SwiftUI

@available(iOS 15.0, *)
enum HB {
    static let bg = Color(red: 0.051, green: 0.035, blue: 0.075)
    static let card = Color(red: 0.118, green: 0.090, blue: 0.145)
    static let cardTop = Color(red: 0.18, green: 0.13, blue: 0.21)
    static let orange = Color(red: 1.0, green: 0.69, blue: 0.30)
    static let orangeDeep = Color(red: 0.96, green: 0.60, blue: 0.24)
    static let green = Color(red: 0.45, green: 0.90, blue: 0.62)
    static let red = Color(red: 1.0, green: 0.56, blue: 0.64)
    static let soft = Color.white.opacity(0.62)
    static let line = Color.white.opacity(0.09)
    static let gutter: CGFloat = 16
    /// space between the bottom of a screen and the floating tab bar
    static let barGap: CGFloat = 6
}

@available(iOS 15.0, *)
struct HBCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(LinearGradient(colors: [HB.cardTop.opacity(0.9), HB.card], startPoint: .top, endPoint: .bottom)))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(HB.line, lineWidth: 1))
    }
}

@available(iOS 15.0, *)
extension View { func hbCard() -> some View { modifier(HBCardStyle()) } }

enum HBFormat {
    static func money(_ v: Double, cents: Bool = true) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.currencySymbol = "$"
        f.minimumFractionDigits = cents ? 2 : 0
        f.maximumFractionDigits = cents ? 2 : 0
        return f.string(from: NSNumber(value: v)) ?? "$\(v)"
    }
}

// MARK: fonts

import UIKit
import CoreText

// The honeybun wordmark uses Fredoka SemiBold, the same face as the website. The font file lives in the asset catalog (as a data asset) and is
// registered once at launch, so nothing else in the Xcode project has to change. If it ever fails to load, the system rounded font is used.
enum HBFonts {
    static let wordmarkName = "Fredoka-SemiBold"
    private static var registered = false
    static func register() {
        guard !registered else { return }
        registered = true
        guard let asset = NSDataAsset(name: "HBFredokaSemiBold"), let provider = CGDataProvider(data: asset.data as CFData), let font = CGFont(provider) else { return }
        CTFontManagerRegisterGraphicsFont(font, nil)
    }
}

@available(iOS 15.0, *)
extension Font {
    static func hbWordmark(_ size: CGFloat) -> Font {
        UIFont(name: HBFonts.wordmarkName, size: size) != nil ? Font.custom(HBFonts.wordmarkName, size: size) : Font.system(size: size, weight: .bold, design: .rounded)
    }
}

// MARK: shared look

@available(iOS 15.0, *)
extension Color {
    init(rgb: (Double, Double, Double)) { self.init(red: rgb.0, green: rgb.1, blue: rgb.2) }
}

// The Halloween night: deep plum, an ember glow behind the hero, and the forest scene fading in from the top. Everything is relative to the
// screen it is drawn on, so it fits any iPhone.
@available(iOS 15.0, *)
struct HBBackground: View {
    var glow: Bool = true
    var scene: Bool = true
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .top) {
                LinearGradient(colors: [Color(red: 0.075, green: 0.045, blue: 0.105), Color(red: 0.043, green: 0.030, blue: 0.065)], startPoint: .top, endPoint: .bottom)
                if scene { Image("HBScene").resizable().scaledToFill()
                    .frame(width: g.size.width, height: g.size.height * 0.5, alignment: .top).clipped()
                    .opacity(0.20)
                    .mask(LinearGradient(colors: [.black, .black.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom)) }
                if glow {
                    RadialGradient(colors: [Color(red: 1.0, green: 0.5, blue: 0.15).opacity(0.22), .clear], center: UnitPoint(x: 0.82, y: 0.05), startRadius: 0, endRadius: g.size.width * 0.9)
                    RadialGradient(colors: [Color(red: 0.55, green: 0.25, blue: 0.85).opacity(0.14), .clear], center: UnitPoint(x: 0.05, y: 0.0), startRadius: 0, endRadius: g.size.width * 0.8)
                }
            }
            .frame(width: g.size.width, height: g.size.height)
        }
        .ignoresSafeArea()
    }
}

// "honeybun" with its heart, as on the website: Fredoka SemiBold, honey gradient.
@available(iOS 15.0, *)
struct HBWordmark: View {
    var size: CGFloat = 34
    var body: some View {
        HStack(alignment: .top, spacing: 3) {
            Text("honeybun").font(.hbWordmark(size))
                .foregroundStyle(LinearGradient(colors: [Color(red: 1.0, green: 0.89, blue: 0.65), Color(red: 0.98, green: 0.69, blue: 0.29)], startPoint: .top, endPoint: .bottom))
                .shadow(color: Color(red: 1, green: 0.6, blue: 0.2).opacity(0.3), radius: 8)
            Image(systemName: "heart.fill").font(.system(size: size * 0.36)).foregroundColor(Color(red: 1.0, green: 0.37, blue: 0.53)).padding(.top, size * 0.16)
        }
        .accessibilityElement(children: .ignore).accessibilityLabel("honeybun")
    }
}

// The real top safe-area inset of the screen (Dynamic Island / notch / status bar height), read from the window so it adapts to every iPhone.
enum HBSafeArea {
    static var top: CGFloat {
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap { $0.windows }
        return (windows.first { $0.isKeyWindow } ?? windows.first)?.safeAreaInsets.top ?? 47
    }
}
