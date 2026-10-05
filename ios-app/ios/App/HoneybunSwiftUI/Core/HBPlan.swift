import Foundation

// The numbers behind Plan: budgets, the bill calendar, subscriptions, the month-end forecast. Pure functions of the /api/nest snapshot, ported from
// the website's own rules (spentByCat / renderPlan / renderCalendar / forecast in app.js), so Classic and native always agree.

struct HBBudgetRow: Identifiable, Equatable {
    let category: String
    let limit: Double       // the monthly limit plus anything rolled over from earlier months
    let spent: Double
    let carry: Double
    var id: String { category }
    var ratio: Double { limit > 0 ? spent / limit : 0 }
    var left: Double { limit - spent }
    var over: Bool { spent > limit }
    var warn: Bool { ratio > 0.8 && !over }
}
struct HBBudgetSummary: Equatable {
    var rows: [HBBudgetRow]
    var totalLimit: Double, totalSpent: Double, totalCarry: Double
    var over: Bool { totalSpent > totalLimit }
    var warn: Bool { totalLimit > 0 && totalSpent > totalLimit * 0.8 && !over }
}

struct HBCalItem { let recurring: HBRecurring; let date: Date; let done: Bool }
struct HBCalDay: Identifiable { let day: Int; let date: String; let items: [HBCalItem]; var id: Int { day } }

struct HBSubsSummary {
    let rows: [HBRecurring]          // soonest charge first
    let perMonth: Double
    let perYear: Double
    let next: (recurring: HBRecurring, date: Date)?
}

struct HBForecast {
    let day: Int, dim: Int, daysLeft: Int
    let endLeft: Double, leftNow: Double, pays: Double, bills: Double, ahead: Double
    let points: [(day: Int, left: Double)]
    let risky: (category: String, projected: Double, limit: Double)?
    let saveEach: Double, saveEnd: Double
    let vsLastMonthPct: Int?         // spending pace against last month, when last month is known
}
enum HBForecastResult { case notThisMonth, wait(day: Int), ready(HBForecast) }

enum HBPlan {
    static func spentByCategory(_ entries: [HBEntry]) -> [String: Double] {
        var by: [String: Double] = [:]
        for e in entries where !e.isIncome { by[e.category ?? "other", default: 0] += e.amount }
        return by
    }

    // MARK: budgets

    /// rows for every category that has a limit, the most-used first (the order the website shows)
    static func budgets(_ s: HBNestSnapshot) -> HBBudgetSummary {
        let by = spentByCategory(s.entries)
        let rows = (s.budgets ?? []).filter { $0.limit_cents > 0 }.map { b -> HBBudgetRow in
            let carry = Double(s.carry?[b.category] ?? 0) / 100.0
            return HBBudgetRow(category: b.category, limit: Double(b.limit_cents) / 100.0 + carry, spent: by[b.category] ?? 0, carry: carry)
        }.sorted { $0.ratio > $1.ratio }
        return HBBudgetSummary(rows: rows, totalLimit: rows.reduce(0) { $0 + $1.limit }, totalSpent: rows.reduce(0) { $0 + $1.spent }, totalCarry: rows.reduce(0) { $0 + $1.carry })
    }

    // MARK: calendar

    /// the days of a month with the bills / paydays that fall on them; `leadingBlanks` is how many empty cells come before the 1st (weeks start on Sunday)
    static func calendar(month: String, snapshot s: HBNestSnapshot) -> (leadingBlanks: Int, days: [HBCalDay]) {
        guard let first = HBDay.parse(month + "-01"), let span = HBDay.cal.range(of: .day, in: .month, for: first) else { return (0, []) }
        let last = HBDay.addDays(first, span.count - 1)
        let logged = Set(s.logged.map { $0.recurring_id + "|" + $0.occ_date })
        var by: [Int: [HBCalItem]] = [:]
        for r in s.recurring {
            for d in HBRecur.occurrences(r, from: first, to: last) {
                by[HBDay.cal.component(.day, from: d), default: []].append(HBCalItem(recurring: r, date: d, done: logged.contains(r.id + "|" + HBDay.string(d))))
            }
        }
        let blanks = HBDay.cal.component(.weekday, from: first) - 1
        return (blanks, (1...span.count).map { d in HBCalDay(day: d, date: String(format: "%@-%02d", month, d), items: by[d] ?? []) })
    }

    // MARK: subscriptions (repeating expenses in the Subscriptions category)

    static let perMonthFactor: [String: Double] = ["weekly": 52.0 / 12.0, "biweekly": 26.0 / 12.0, "monthly": 1]
    static func nextDate(_ r: HBRecurring, today: Date = HBDay.startOfToday()) -> Date? { HBRecur.occurrences(r, from: today, to: HBDay.addDays(today, 400)).first }
    static func monthlyCost(_ r: HBRecurring) -> Double { r.amount * (perMonthFactor[r.freq] ?? 1) }
    static func isSubscription(_ r: HBRecurring) -> Bool { r.type == "expense" && r.category == "subs" }

    static func subscriptions(_ s: HBNestSnapshot, today: Date = HBDay.startOfToday()) -> HBSubsSummary {
        let subs = s.recurring.filter(isSubscription)
        let withNext = subs.map { ($0, nextDate($0, today: today)) }
        let sorted = withNext.sorted { ($0.1 ?? .distantFuture) < ($1.1 ?? .distantFuture) }
        let perMonth = subs.reduce(0) { $0 + monthlyCost($1) }
        let next = sorted.first.flatMap { x in x.1.map { (x.0, $0) } }
        return HBSubsSummary(rows: sorted.map { $0.0 }, perMonth: perMonth, perYear: perMonth * 12, next: next)
    }
    /// bills and paydays (everything except subscriptions), soonest first
    static func billsAndPaydays(_ s: HBNestSnapshot, today: Date = HBDay.startOfToday()) -> [HBRecurring] {
        s.recurring.filter { !isSubscription($0) }.sorted { (nextDate($0, today: today) ?? .distantFuture) < (nextDate($1, today: today) ?? .distantFuture) }
    }

    // MARK: forecast ("Month-end forecast" on the website's Stats screen)

    static func forecast(_ s: HBNestSnapshot, month: String, today: Date = HBDay.startOfToday(), myID: String, lastMonthSpent: Double? = nil) -> HBForecastResult {
        guard month == HBDay.monthKey(today), let first = HBDay.parse(month + "-01"), let span = HBDay.cal.range(of: .day, in: .month, for: first) else { return .notThisMonth }
        let dim = span.count, day = HBDay.cal.component(.day, from: today), daysLeft = dim - day
        let exp = s.entries.filter { !$0.isIncome }, inc = s.entries.filter { $0.isIncome }
        let spent = exp.reduce(0) { $0 + $1.amount }, came = inc.reduce(0) { $0 + $1.amount }
        if day < 7 || exp.count < 5 { return .wait(day: day) }
        // one-off big purchases already happened: count them once, don't repeat them every day
        let loose = exp.filter { $0.recurring_id == nil }
        let amts = loose.map { $0.amount }.sorted()
        let med = amts.isEmpty ? 0 : amts[amts.count / 2]
        let bigCut = max(150, med * 6)
        let perDay = loose.filter { $0.amount <= bigCut }.reduce(0) { $0 + $1.amount } / Double(day)
        let end = HBDay.addDays(first, dim - 1)
        let logged = Set(s.logged.map { $0.recurring_id + "|" + $0.occ_date })
        var bills = 0.0, pays = 0.0
        for r in s.recurring {
            if r.type == "expense" && !(r.shared == 1 || r.member_id == myID) { continue }
            for d in HBRecur.occurrences(r, from: today, to: end) where !logged.contains(r.id + "|" + HBDay.string(d)) {
                if r.isIncome { pays += r.amount } else { bills += r.amount }
            }
        }
        let carryIn = Double(s.carry_in?.amount_cents ?? 0) / 100.0
        let leftNow = came - spent + carryIn
        let endLeft = leftNow + pays - bills - perDay * Double(daysLeft)
        var byDay = [Double](repeating: 0, count: dim + 1)
        for e in s.entries { if let d = Int(e.date.suffix(2)), d >= 1, d <= dim { byDay[d] += e.isIncome ? e.amount : -e.amount } }
        var pts: [(Int, Double)] = []; var run = carryIn
        for d in 1...day { run += byDay[d]; pts.append((d, run)) }
        let by = spentByCategory(s.entries)
        let risky = (s.budgets ?? []).map { b -> (String, Double, Double) in (b.category, (by[b.category] ?? 0) / Double(day) * Double(dim), Double(b.limit_cents) / 100.0) }
            .filter { $0.2 > 0 && $0.1 > $0.2 * 1.05 }.sorted { $0.1 / $0.2 > $1.1 / $1.2 }.first
        var vs: Int? = nil
        if let last = lastMonthSpent, last > 0 { vs = Int((((spent + perDay * Double(daysLeft) + bills) / last - 1) * 100).rounded()) }
        return .ready(HBForecast(day: day, dim: dim, daysLeft: daysLeft, endLeft: endLeft, leftNow: leftNow, pays: pays, bills: bills, ahead: perDay * Double(daysLeft),
                                 points: pts.map { (day: $0.0, left: $0.1) }, risky: risky.map { (category: $0.0, projected: $0.1, limit: $0.2) },
                                 saveEach: 5, saveEnd: endLeft + 5 * Double(daysLeft), vsLastMonthPct: vs))
    }
}
