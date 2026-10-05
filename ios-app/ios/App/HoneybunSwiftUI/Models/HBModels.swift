import Foundation

// Shapes of the existing /api/nest and /api/me responses (checked against src/worker.js). Extra fields are ignored.
struct HBUser: Decodable, Identifiable {
    let id: String; var name: String; var email: String?
    var verified: Bool?; var has_email: Bool?; var has_password: Bool?; var apple: Bool?   // how this account signs in (from /api/me)
    var mail: HBMailPrefs?                                                                   // the email reminders this account has switched on
    var ref: HBRefSummary?                                                                   // referral progress (nil if the account has none)
    var shortcut: HBShortcutInfo?                                                            // the Apple Pay / Shortcuts key, if one was made
}
struct HBRefSummary: Decodable { let code: String; let goal: Int; let reward_cents: Int; let qualified: Int; let pending: Int; let rejected: Int }
struct HBShortcutInfo: Decodable { let created_at: Double?; let last_used: Double?; let uses: Int? }
struct HBMailPrefs: Decodable { var bills: Bool?; var streak: Bool?; var weekly: Bool? }
struct HBPasskeyInfo: Decodable, Identifiable { let id: String; let name: String; let created_at: Double?; let last_used: Double? }
struct HBPasskeyList: Decodable { let passkeys: [HBPasskeyInfo] }
struct HBMeEnvelope: Decodable { let user: HBUser?; let nest_id: String? }

struct HBMember: Decodable, Identifiable {
    let id: String; let name: String; let emoji: String?; let color: String?; let streak: Int?; let xp: Int?
    var best_streak: Int? = nil; var last_day: String? = nil; var week_key: String? = nil; var week_xp: Int? = nil; var logs: Int? = nil   // progression (levels, streaks, badges)
}

struct HBEntry: Decodable, Identifiable {
    let id: String; let member_id: String; let type: String; let amount_cents: Int; let label: String
    let category: String?; let shared: Int; let split_mode: String?; let split_value: Int?
    let isPrivate: Int; let date: String; let recurring_id: String?; let occ_date: String?
    var pending: Bool = false      // saved on this iPhone, waiting to sync (never sent by the server)
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
    var prev_amount_cents: Int? = nil; var price_changed_at: String? = nil     // set when the price of a bill or subscription changed
    var amount: Double { Double(amount_cents) / 100.0 }
    var isIncome: Bool { type == "income" }
}

struct HBLogged: Decodable { let recurring_id: String; let occ_date: String }
struct HBGoal: Decodable, Identifiable {
    let id: String; let name: String; let emoji: String?; let target_cents: Int; let saved_cents: Int
    var progress: Double { target_cents > 0 ? min(1, Double(saved_cents) / Double(target_cents)) : 0 }
    var saved: Double { Double(saved_cents) / 100.0 }
    var target: Double { Double(target_cents) / 100.0 }
    var isDone: Bool { target_cents > 0 && saved_cents >= target_cents }
}
/// one deposit (+) or withdrawal (−) on a savings goal, from /api/nest "jar" (the latest 60)
struct HBJarMove: Decodable, Identifiable {
    let id: String; let goal_id: String?; let member_id: String; let amount_cents: Int; let created_at: Double
    var amount: Double { Double(amount_cents) / 100.0 }
    var date: Date { Date(timeIntervalSince1970: created_at) }
}
struct HBNest: Decodable { let id: String; let name: String; let kind: String?; let joint: Int?; let invite_code: String?; let accent: String?; let rollover: Int? }
/// one "X paid Y back" from /api/nest "settlements" (the latest 10)
struct HBSettlement: Decodable, Identifiable {
    let id: String; let from_id: String; let to_id: String; let amount_cents: Int; let date: String
    var amount: Double { Double(amount_cents) / 100.0 }
}
/// one line of the shared shopping list, from GET /api/shopping
struct HBShopItem: Decodable, Identifiable {
    let id: String; var label: String; let added_by: String?; var done: Bool; let done_by: String?
}
struct HBShopEnvelope: Decodable { let items: [HBShopItem] }
struct HBSearchEnvelope: Decodable { let entries: [HBEntry] }

/// one value inside an inbox message's small "data" object (text, number or flag)
enum HBJSONValue: Decodable {
    case string(String), number(Double), bool(Bool), null
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let d = try? c.decode(Double.self) { self = .number(d) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else { self = .null }
    }
    var string: String? { if case let .string(s) = self { return s }; return nil }
    var double: Double? { if case let .number(d) = self { return d }; return nil }
    var bool: Bool { if case let .bool(b) = self { return b }; return false }
}
/// one of Bun's messages, from GET /api/inbox (kind + a small data object; the app turns it into friendly text)
struct HBInboxMessage: Decodable, Identifiable {
    let id: String; let kind: String; let data: [String: HBJSONValue]; let created_at: Double; var read_at: Double?
    var isUnread: Bool { read_at == nil }
    var date: Date { Date(timeIntervalSince1970: created_at) }
    func str(_ k: String) -> String { data[k]?.string ?? "" }
    func num(_ k: String) -> Double { data[k]?.double ?? 0 }
    func flag(_ k: String) -> Bool { data[k]?.bool ?? false }
}
struct HBInboxEnvelope: Decodable { let messages: [HBInboxMessage] }
/// "New month! August ended at $X. Carry it over?" (nil once you have decided)
struct HBCarryPrompt: Decodable { let from: String; let amount_cents: Int }
struct HBCustomCategory: Decodable, Identifiable { let id: String; let name: String; let emoji: String? }
struct HBCarry: Decodable { let amount_cents: Int; let accepted: Bool? }

struct HBNestSnapshot: Decodable {
    let me: HBUser?; let nest: HBNest; let members: [HBMember]; let entries: [HBEntry]; let recurring: [HBRecurring]
    let logged: [HBLogged]; let goals: [HBGoal]; let shopping_open: Int?; let carry_in: HBCarry?; let inbox: HBInboxCount?; let jar: [HBJarMove]?
    let balances: [String: Int]?; let settlements: [HBSettlement]?
    let carry_pending: HBCarryPrompt?; let categories: [HBCustomCategory]?; let setup_done: Bool?
    let budgets: [HBBudget]?; let debts: [HBDebt]?; let debt_payments: [HBDebtPayment]?
    let carry: [String: Int]?            // per-category budget roll-over from earlier months (cents)
    let repeats: [HBRepeat]?             // your most common expenses (one-tap repeats on the Add screen)
}

/// one of your most common expenses of the last 90 days, from /api/nest "repeats"
struct HBRepeat: Decodable, Identifiable {
    let label: String; let category: String?; let amount_cents: Int
    let shared: Int?; let split_mode: String?; let split_value: Int?; let isPrivate: Int?; let count: Int?
    enum CodingKeys: String, CodingKey { case label, category, amount_cents, shared, split_mode, split_value, count; case isPrivate = "private" }
    var id: String { label.lowercased() + "|" + (category ?? "other") }
    var amount: Double { Double(amount_cents) / 100.0 }
}

/// a monthly limit for one category (built-in id or a custom "c_…" id)
struct HBBudget: Decodable { let category: String; let limit_cents: Int }
/// a debt: start_cents is what was owed when it was added, paid_cents is what the logged payments add up to
struct HBDebt: Decodable, Identifiable {
    let id: String; let name: String; let start_cents: Int; let apr_bp: Int; let min_cents: Int; let paid_cents: Int
    var remaining: Double { Double(max(0, start_cents - paid_cents)) / 100.0 }
    var start: Double { Double(start_cents) / 100.0 }
    var apr: Double { Double(apr_bp) / 100.0 }
    var minimum: Double { Double(min_cents) / 100.0 }
    var progress: Double { start_cents > 0 ? min(1, Double(paid_cents) / Double(start_cents)) : 0 }
    var paidOff: Bool { remaining <= 0 }
}
struct HBDebtPayment: Decodable, Identifiable { let id: String; let debt_id: String; let member_id: String; let amount_cents: Int; let date: String; var amount: Double { Double(amount_cents) / 100.0 } }

enum HBCategory: String, CaseIterable, Identifiable {
    case home, groc, food, date, bills, subs, car, fun, pets, debt, other
    var id: String { rawValue }
    // the account's own category names (same as the website and classic app)
    var label: String {
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
        case .pets: return "pawprint.fill"; case .debt: return "creditcard.fill"; case .other: return "ellipsis"
        }
    }
    /// RGB of the category's accent (used for its circle in lists and forms)
    var rgb: (Double, Double, Double) {
        switch self {
        case .food: return (1.00, 0.62, 0.22)
        case .groc: return (1.00, 0.40, 0.55)
        case .bills: return (0.62, 0.58, 1.00)
        case .car: return (0.40, 0.62, 1.00)
        case .fun: return (1.00, 0.42, 0.62)
        case .home: return (1.00, 0.76, 0.33)
        case .date: return (1.00, 0.45, 0.62)
        case .subs: return (0.66, 0.50, 1.00)
        case .pets: return (0.55, 0.85, 0.65)
        case .debt: return (1.00, 0.55, 0.45)
        case .other: return (0.45, 0.72, 1.00)
        }
    }
    static func of(_ raw: String?) -> HBCategory { HBCategory(rawValue: raw ?? "") ?? .other }
}

struct HBInboxCount: Decodable { let unread: Int? }   // the badge number inside /api/nest

// What the app sends to POST/PATCH /api/entries. Editing keeps the entry's own split so a save never silently changes how it was shared.
struct HBEntryDraft: Codable, Equatable {
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

// What the app sends to POST/PATCH /api/goals (the backend keeps one of its ten goal emoji; the app shows icons, never the emoji).
struct HBGoalDraft {
    var name: String = ""
    var target: Double = 0
    var emoji: String = HBGoalStyle.emojis[0]
    var json: [String: Any] { ["name": name, "target": target, "emoji": emoji] }
}

// MARK: - Stats (/api/year), referrals (/api/referrals)

struct HBYearEntry: Decodable {
    let type: String; let amount_cents: Int; let category: String?; let label: String; let member_id: String; let date: String
    let shared: Int?; let isPrivate: Int?
    enum CodingKeys: String, CodingKey { case type, amount_cents, category, label, member_id, date, shared; case isPrivate = "private" }
    var isIncome: Bool { type == "income" }
    var amount: Double { Double(amount_cents) / 100.0 }
}
struct HBYearData: Decodable { let entries: [HBYearEntry] }

struct HBReferralPerson: Decodable { let name: String?; let status: String; let reason: String?; let created_at: Double; let active_days: Int }
struct HBReward: Decodable { let amount_cents: Int; let status: String?; let created_at: Double; let sent_at: Double? }
struct HBReferrals: Decodable {
    let code: String; let goal: Int; let reward_cents: Int; let qualified: Int; let pending: Int; let rejected: Int
    let link: String; let days_needed: Int; let active_days_needed: Int
    let people: [HBReferralPerson]; let rewards: [HBReward]
    var inCycle: Int { goal > 0 ? qualified % goal : 0 }
}
