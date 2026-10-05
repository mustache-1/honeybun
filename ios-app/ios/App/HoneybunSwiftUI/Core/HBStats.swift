import Foundation

// The numbers behind Stats: the year chart, "where it went", the 50/30/20 split, the monthly recap and the CSV export.
// Ported from renderStats / drawRecap / exportCsv in app.js.
struct HBYearTotals: Equatable {
    var income = [Double](repeating: 0, count: 12)
    var spent = [Double](repeating: 0, count: 12)
    var byCategory: [String: Double] = [:]
    var totalIn: Double { income.reduce(0, +) }
    var totalOut: Double { spent.reduce(0, +) }
    /// share of income kept (whole %), nil when nothing came in
    var keptPct: Int? { totalIn > 0 ? Int(((totalIn - totalOut) / totalIn * 100).rounded()) : nil }
    var monthsWithEntries = 0
}

struct HBRule: Equatable { let needs: Int; let wants: Int; let saved: Int; let ok: Bool; let verdict: String }

struct HBRecap {
    let month: String
    let keptPct: Int?
    let income: Double, spent: Double
    let topCategory: (id: String, amount: Double)?
    let streak: Int, bestStreak: Int
    let level: Int, levelTitle: String
    let budgetsKept: Int, budgetsTotal: Int
    let message: String
}

enum HBStats {
    static let needs = ["home", "groc", "bills", "car", "pets", "debt"]
    static let wants = ["food", "date", "fun", "subs", "other"]

    static func year(_ d: HBYearData) -> HBYearTotals {
        var t = HBYearTotals()
        var months = Set<String>()
        for e in d.entries {
            guard e.date.count >= 7, let m = Int(e.date.dropFirst(5).prefix(2)), m >= 1, m <= 12 else { continue }
            months.insert(String(e.date.prefix(7)))
            if e.isIncome { t.income[m - 1] += e.amount } else { t.spent[m - 1] += e.amount; t.byCategory[e.category ?? "other", default: 0] += e.amount }
        }
        t.monthsWithEntries = months.count
        return t
    }

    /// "Where it went": the five biggest, then everything else together
    static func whereItWent(_ data: [String: Double]) -> (rows: [(id: String, amount: Double)], rest: Double) {
        let sorted = data.filter { $0.value > 0 }.sorted { $0.value > $1.value }.map { (id: $0.key, amount: $0.value) }
        return (Array(sorted.prefix(5)), sorted.dropFirst(5).reduce(0) { $0 + $1.amount })
    }

    /// 50 / 30 / 20 for the month on screen; nil until some income is logged
    static func rule(_ s: HBNestSnapshot) -> HBRule? {
        let income = s.entries.filter { $0.isIncome }.reduce(0) { $0 + $1.amount }
        guard income > 0 else { return nil }
        let by = HBPlan.spentByCategory(s.entries)
        let n = needs.reduce(0) { $0 + (by[$1] ?? 0) }, w = wants.reduce(0) { $0 + (by[$1] ?? 0) }
        func pc(_ v: Double) -> Int { Int((v / income * 100).rounded()) }
        let saved = max(0, income - n - w)
        let ok = pc(n) <= 55 && pc(w) <= 35
        return HBRule(needs: pc(n), wants: pc(w), saved: pc(saved), ok: ok, verdict: ok ? "On track" : (pc(n) > 55 ? "Needs are high" : "Wants are high"))
    }

    /// the data behind the shareable monthly recap card
    static func recap(_ s: HBNestSnapshot, month: String, me: HBMember?, today: Date = HBDay.startOfToday()) -> HBRecap {
        let income = s.entries.filter { $0.isIncome }.reduce(0) { $0 + $1.amount }
        let spent = s.entries.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
        let kept: Int? = income > 0 ? Int(((income - spent) / income * 100).rounded()) : nil
        let by = HBPlan.spentByCategory(s.entries)
        var top: (id: String, amount: Double)? = nil
        for (k, v) in by where v > (top?.amount ?? 0) { top = (id: k, amount: v) }
        let streak = me.map { HBProgress.streak($0, today: today) } ?? 0
        let li = HBProgress.levelInfo(me?.xp ?? 0)
        let budgets = s.budgets ?? []
        let under = budgets.filter { (by[$0.category] ?? 0) <= Double($0.limit_cents) / 100.0 }.count
        let msg: String
        if let k = kept, k >= 20 { msg = "Look at you go! Your bunny is so proud ♡" }
        else if streak >= 3 { msg = "Keep hopping. Your bunny is proud of you." }
        else { msg = "Every little log helps your bunny grow ♡" }
        return HBRecap(month: month, keptPct: kept, income: income, spent: spent, topCategory: top, streak: streak, bestStreak: me?.best_streak ?? 0,
                       level: li.level, levelTitle: li.title, budgetsKept: under, budgetsTotal: budgets.count, message: msg)
    }

    /// the spreadsheet of the whole year: Date, Type, Category, Description, Who, Amount, Split, Private
    static func csv(_ d: HBYearData, memberName: (String) -> String, categoryName: (String?) -> String) -> String {
        func q(_ v: String) -> String { "\"" + v.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        var rows = [["Date", "Type", "Category", "Description", "Who", "Amount", "Split", "Private"]]
        for e in d.entries {
            let signed = (e.isIncome ? 1.0 : -1.0) * Double(e.amount_cents) / 100.0
            rows.append([e.date, e.isIncome ? "Income" : "Expense", e.isIncome ? "Income" : categoryName(e.category), e.label, memberName(e.member_id),
                         String(format: "%.2f", signed), (e.shared ?? 0) == 1 ? "Yes" : "No", (e.isPrivate ?? 0) == 1 ? "Yes" : "No"])
        }
        return "\u{FEFF}" + rows.map { $0.map(q).joined(separator: ",") }.joined(separator: "\r\n")
    }
}
