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
