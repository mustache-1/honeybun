import Foundation

// Which icon a goal gets: the same keyword rules the website uses (goalKind() in app.js), applied to the goal's name and its stored emoji.
// The emoji only feeds those rules and is sent back to the backend as the goal's "kind"; the screen draws icons, not emoji.
enum HBGoalKind: String, CaseIterable {
    case palm, pc, shield, car, home, heart, gift, cap, paw, coin

    init(name: String, emoji: String?) {
        let t = (name + " " + (emoji ?? "")).lowercased()
        func has(_ pattern: String) -> Bool { t.range(of: pattern, options: .regularExpression) != nil }
        if has("vacation|travel|trip|holiday|beach|island|flight|cruise|honeymoon|getaway|🏝|✈|🌴|🧳|⛱") { self = .palm }
        else if has("\\b(pc|computer|laptop|gaming|console|monitor|setup|tech|phone|iphone|camera|tv)\\b|🖥|💻|🎮|📱|📷") { self = .pc }
        else if has("emergency|safety|rainy|insurance|buffer|backup|security|cushion|🛡|🛟|🆘") { self = .shield }
        else if has("\\b(car|truck|vehicle|bike|motorcycle|tires)\\b|🚗|🚙|🏍|🚲") { self = .car }
        else if has("\\b(house|home|rent|deposit|mortgage|apartment|move|moving|furniture)\\b|🏠|🏡") { self = .home }
        else if has("wedding|ring|engage|anniversary|date|💍|💒|❤") { self = .heart }
        else if has("gift|christmas|birthday|present|🎁|🎄|🎂") { self = .gift }
        else if has("school|college|tuition|course|study|degree|class|🎓|📚") { self = .cap }
        else if has("\\b(pet|dog|cat|vet|puppy|kitten)\\b|🐶|🐱|🐾") { self = .paw }
        else { self = .coin }
    }

    var symbol: String {
        switch self {
        case .palm: return "beach.umbrella.fill"; case .pc: return "desktopcomputer"; case .shield: return "shield.fill"; case .car: return "car.fill"
        case .home: return "house.fill"; case .heart: return "heart.fill"; case .gift: return "gift.fill"; case .cap: return "graduationcap.fill"
        case .paw: return "pawprint.fill"; case .coin: return "dollarsign.circle.fill"
        }
    }
    /// symbol colour (r, g, b) and the pale disc behind it
    var ink: (Double, Double, Double) {
        switch self {
        case .palm: return (0.10, 0.62, 0.45); case .pc: return (0.16, 0.34, 0.85); case .shield: return (0.12, 0.30, 0.78); case .car: return (0.92, 0.45, 0.12)
        case .home: return (0.85, 0.55, 0.10); case .heart: return (0.90, 0.25, 0.45); case .gift: return (0.85, 0.28, 0.25); case .cap: return (0.45, 0.30, 0.85)
        case .paw: return (0.70, 0.42, 0.18); case .coin: return (0.85, 0.58, 0.10)
        }
    }
    var disc: (Double, Double, Double) {
        switch self {
        case .palm: return (0.78, 0.95, 0.96); case .pc, .shield: return (0.86, 0.86, 0.98); case .car: return (1.0, 0.88, 0.76); case .home: return (1.0, 0.93, 0.72)
        case .heart: return (1.0, 0.84, 0.90); case .gift: return (1.0, 0.86, 0.82); case .cap: return (0.90, 0.85, 1.0); case .paw: return (0.98, 0.88, 0.76); case .coin: return (1.0, 0.92, 0.70)
        }
    }
}

enum HBGoalStyle {
    /// the ten goal emoji the backend accepts (src/worker.js GOAL_EMOJIS), in order
    static let emojis = ["🍯", "✈️", "🏠", "💍", "🚗", "🎓", "🐶", "🎄", "🛟", "🎁"]
    /// the picker shows an icon + word for each of them (the emoji is what gets stored)
    static let choices: [(emoji: String, label: String, kind: HBGoalKind)] = [
        ("🍯", "Savings", .coin), ("✈️", "Trip", .palm), ("🏠", "Home", .home), ("💍", "Wedding", .heart), ("🚗", "Car", .car),
        ("🎓", "School", .cap), ("🐶", "Pet", .paw), ("🎄", "Holiday", .gift), ("🛟", "Safety", .shield), ("🎁", "Gift", .gift),
    ]
}
