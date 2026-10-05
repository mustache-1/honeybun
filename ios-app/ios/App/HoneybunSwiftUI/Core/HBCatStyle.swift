import Foundation

// How a spending category looks and reads. The built-in categories are fixed; "your own" categories (c_… ids) come from the account
// (/api/nest `categories`) and are kept in `custom` so every screen can look them up without being passed the whole snapshot.
struct HBCatStyle: Identifiable, Equatable {
    let id: String
    let label: String
    let symbol: String          // SF Symbol for built-ins
    let emoji: String?          // set for the account's own categories
    let rgb: (Double, Double, Double)
    var isCustom: Bool { emoji != nil }
    static func == (a: HBCatStyle, b: HBCatStyle) -> Bool { a.id == b.id && a.label == b.label && a.emoji == b.emoji }

    /// the account's own categories, kept current by HBAppStore whenever a new snapshot arrives
    static var custom: [HBCustomCategory] = []
    static let customRGB: (Double, Double, Double) = (0.70, 0.62, 1.00)

    static func of(_ raw: String?) -> HBCatStyle {
        if let raw = raw, let c = custom.first(where: { $0.id == raw }) { return make(c) }
        let b = HBCategory.of(raw)
        return HBCatStyle(id: b.rawValue, label: b.label, symbol: b.symbol, emoji: nil, rgb: b.rgb)
    }
    static func make(_ c: HBCustomCategory) -> HBCatStyle { HBCatStyle(id: c.id, label: c.name, symbol: "tag.fill", emoji: (c.emoji?.isEmpty == false ? c.emoji : "✨"), rgb: customRGB) }
    /// every category an expense can be filed under: the built-in ones, then the account's own
    static var all: [HBCatStyle] { HBCategory.allCases.map { of($0.rawValue) } + custom.map(make) }
}
