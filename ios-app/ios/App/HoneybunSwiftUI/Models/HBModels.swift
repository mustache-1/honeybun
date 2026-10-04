import Foundation

// Shapes of the existing /api/nest and /api/me responses (checked against src/worker.js). Extra fields are ignored.
struct HBUser: Decodable, Identifiable { let id: String; var name: String; var email: String? }
struct HBMeEnvelope: Decodable { let user: HBUser?; let nest_id: String? }

struct HBMember: Decodable, Identifiable {
    let id: String; let name: String; let emoji: String?; let color: String?; let streak: Int?; let xp: Int?
}

struct HBEntry: Decodable, Identifiable {
    let id: String; let member_id: String; let type: String; let amount_cents: Int; let label: String
    let category: String?; let shared: Int; let split_mode: String?; let split_value: Int?
    let isPrivate: Int; let date: String; let recurring_id: String?; let occ_date: String?
    enum CodingKeys: String, CodingKey {
        case id, member_id, type, amount_cents, label, category, shared, split_mode, split_value, date, recurring_id, occ_date
        case isPrivate = "private"
    }
    var amount: Double { Double(amount_cents) / 100.0 }
    var isIncome: Bool { type == "income" }
}

struct HBRecurring: Decodable, Identifiable {
    let id: String; let type: String; let label: String; let amount_cents: Int; let category: String?
    let member_id: String; let shared: Int; let split_mode: String?; let split_value: Int?
    let freq: String; let anchor_date: String
    var amount: Double { Double(amount_cents) / 100.0 }
    var isIncome: Bool { type == "income" }
}

struct HBLogged: Decodable { let recurring_id: String; let occ_date: String }
struct HBGoal: Decodable, Identifiable {
    let id: String; let name: String; let emoji: String?; let target_cents: Int; let saved_cents: Int
    var progress: Double { target_cents > 0 ? min(1, Double(saved_cents) / Double(target_cents)) : 0 }
}
struct HBNest: Decodable { let id: String; let name: String; let kind: String?; let joint: Int? }
struct HBCarry: Decodable { let amount_cents: Int; let accepted: Bool? }

struct HBNestSnapshot: Decodable {
    let me: HBUser?; let nest: HBNest; let members: [HBMember]; let entries: [HBEntry]; let recurring: [HBRecurring]
    let logged: [HBLogged]; let goals: [HBGoal]; let shopping_open: Int?; let carry_in: HBCarry?
}

enum HBCategory: String, CaseIterable, Identifiable {
    case home, groc, food, date, bills, subs, car, fun, pets, debt, other
    var id: String { rawValue }
    var name: String {
        switch self {
        case .home: return "Housing"; case .groc: return "Groceries"; case .food: return "Eating out"; case .date: return "Date night"
        case .bills: return "Bills"; case .subs: return "Subscriptions"; case .car: return "Car"; case .fun: return "Fun"
        case .pets: return "Pets"; case .debt: return "Debt"; case .other: return "Other"
        }
    }
    var symbol: String {
        switch self {
        case .home: return "house.fill"; case .groc: return "cart.fill"; case .food: return "fork.knife"; case .date: return "heart.fill"
        case .bills: return "doc.text.fill"; case .subs: return "play.rectangle.fill"; case .car: return "car.fill"; case .fun: return "gamecontroller.fill"
        case .pets: return "pawprint.fill"; case .debt: return "creditcard.fill"; case .other: return "ellipsis.circle.fill"
        }
    }
    static func of(_ raw: String?) -> HBCategory { HBCategory(rawValue: raw ?? "") ?? .other }
}

// What the app sends to POST/PATCH /api/entries. Editing keeps the entry's own split so a save never silently changes how it was shared.
struct HBEntryDraft {
    var type: String = "expense"
    var amount: Double = 0
    var label: String = ""
    var category: String = "other"
    var shared: Bool = false
    var date: String
    var memberID: String
    var splitMode: String? = nil
    var splitValue: Double? = nil
    var isPrivate: Bool = false
    var json: [String: Any] {
        var d: [String: Any] = ["type": type, "amount": amount, "label": label, "date": date, "member_id": memberID, "shared": shared, "private": isPrivate]
        if type == "expense" { d["category"] = category }
        if shared, let m = splitMode { d["split_mode"] = m; if let v = splitValue { d["split_value"] = v } }
        return d
    }
}

struct HBRecurringDraft {
    var type: String = "expense"
    var amount: Double = 0
    var label: String = ""
    var category: String = "bills"
    var freq: String = "monthly"
    var date: String
    var memberID: String
    var shared: Bool = false
    var splitMode: String? = nil
    var splitValue: Double? = nil
    var json: [String: Any] {
        var d: [String: Any] = ["type": type, "amount": amount, "label": label, "freq": freq, "date": date, "member_id": memberID, "shared": shared]
        if type == "expense" { d["category"] = category }
        if shared, let m = splitMode { d["split_mode"] = m; if let v = splitValue { d["split_value"] = v } }
        return d
    }
}
