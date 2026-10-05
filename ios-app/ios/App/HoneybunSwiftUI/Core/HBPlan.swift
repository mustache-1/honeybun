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
        // a category that is on pace to blow past its budget (the worst one)
        var risky: (category: String, projected: Double, limit: Double)? = nil
        var worst = 0.0
        for b in s.budgets ?? [] {
            let limit = Double(b.limit_cents) / 100.0
            guard limit > 0 else { continue }
            let projected = (by[b.category] ?? 0) / Double(day) * Double(dim)
            guard projected > limit * 1.05 else { continue }
            let ratio = projected / limit
            if ratio > worst { worst = ratio; risky = (category: b.category, projected: projected, limit: limit) }
        }
        var vs: Int? = nil
        if let last = lastMonthSpent, last > 0 { vs = Int((((spent + perDay * Double(daysLeft) + bills) / last - 1) * 100).rounded()) }
        return .ready(HBForecast(day: day, dim: dim, daysLeft: daysLeft, endLeft: endLeft, leftNow: leftNow, pays: pays, bills: bills, ahead: perDay * Double(daysLeft),
                                 points: pts.map { (day: $0.0, left: $0.1) }, risky: risky,
                                 saveEach: 5, saveEnd: endLeft + 5 * Double(daysLeft), vsLastMonthPct: vs))
    }
}

// MARK: - debt payoff planner (the website's payoffPlan(): Snowball or Avalanche, an extra monthly payment, and the debt-free month)

enum HBDebtStrategy: String, CaseIterable {
    case snowball, avalanche
    var title: String { self == .snowball ? "Snowball" : "Avalanche" }
    var hint: String { self == .snowball ? "Pay the smallest balance first for quick wins." : "Pay the highest interest first to save the most money." }
}
struct HBPayoffPlan: Equatable {
    let months: Int?                 // nil: no minimum payments to plan with, or not paid off within 50 years
    let order: [String]              // debt ids, the one to pay extra on first at the front (debts with a balance only)
    let done: [String: Int]          // debt id → the month (counting from now) it reaches $0
    // Debt Center+: read-outs of the same month-by-month run (they never feed back into the plan itself)
    var interest: Double = 0         // interest added over the whole run (only meaningful when `months` is not nil)
    var balances: [Double] = []      // total still owed: [0] is today, [n] is the end of month n
}

extension HBPlan {
    /// Same rules as Classic: each month interest is added to every balance, the minimums are paid, and what is left of (minimums + extra) goes to the
    /// debts in strategy order. Snowball = smallest balance first; Avalanche = highest rate first (smaller balance breaks a tie). Stops at 600 months.
    static func payoffPlan(_ debts: [HBDebt], strategy: HBDebtStrategy, extra: Double) -> HBPayoffPlan {
        struct D { let id: String; var bal: Double; let r: Double; let min: Double }
        var ds = debts.map { D(id: $0.id, bal: max(0, Double($0.start_cents - $0.paid_cents) / 100.0), r: Double($0.apr_bp) / 10000.0 / 12.0, min: Double($0.min_cents) / 100.0) }.filter { $0.bal > 0.005 }
        // a stable sort, like the website's (equal debts keep the order they were added in)
        let ranked = ds.enumerated().sorted { x, y in
            let a = x.element, b = y.element
            if strategy == .avalanche { if a.r != b.r { return a.r > b.r }; if a.bal != b.bal { return a.bal < b.bal } }
            else if a.bal != b.bal { return a.bal < b.bal }
            return x.offset < y.offset
        }
        let order = ranked.map { $0.element.id }
        if ds.isEmpty { return HBPayoffPlan(months: 0, order: order, done: [:], interest: 0, balances: [0]) }
        let budget = ds.reduce(0) { $0 + $1.min } + extra
        var done: [String: Int] = [:]
        var interest = 0.0
        var balances = [ds.reduce(0) { $0 + $1.bal }]
        if budget <= 0 { return HBPayoffPlan(months: nil, order: order, done: done, interest: 0, balances: balances) }
        var m = 0
        while ds.contains(where: { $0.bal > 0.005 }) && m < 600 {
            m += 1
            for i in ds.indices where ds[i].bal > 0.005 { let add = ds[i].bal * ds[i].r; ds[i].bal += add; interest += add }
            var pool = budget
            for i in ds.indices where ds[i].bal > 0.005 { let p = Swift.min(ds[i].min, ds[i].bal, pool); ds[i].bal -= p; pool -= p }
            for id in order {
                guard let i = ds.firstIndex(where: { $0.id == id }) else { continue }
                if ds[i].bal > 0.005 && pool > 0 { let p = Swift.min(pool, ds[i].bal); ds[i].bal -= p; pool -= p }
            }
            for d in ds where d.bal <= 0.005 && done[d.id] == nil { done[d.id] = m }
            balances.append(Swift.max(0, ds.reduce(0) { $0 + Swift.max(0, $1.bal) }))
        }
        return HBPayoffPlan(months: m >= 600 ? nil : m, order: order, done: done, interest: interest, balances: balances)
    }

    /// "Mar 2027": n months from `from`, the way the website's monthsOut() counts it (it adds months to the date, so the 31st can roll into the next month)
    static func monthsOut(_ n: Int, from: Date = Date()) -> String {
        let cal = HBDay.cal
        let c = cal.dateComponents([.year, .month, .day], from: from)
        var t = DateComponents(); t.year = c.year; t.month = (c.month ?? 1) + n; t.day = c.day
        let d = cal.date(from: t) ?? from
        let f = DateFormatter(); f.dateFormat = "MMM yyyy"; f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: d)
    }

    /// the debts in plan order (debts with a balance first, then paid-off ones), as the website lists them
    static func debtsInPlanOrder(_ debts: [HBDebt], plan: HBPayoffPlan) -> [HBDebt] {
        debts.enumerated().sorted { x, y in
            let ia = plan.order.firstIndex(of: x.element.id) ?? 999, ib = plan.order.firstIndex(of: y.element.id) ?? 999
            return ia != ib ? ia < ib : x.offset < y.offset
        }.map { $0.element }
    }
}

// MARK: - Debt Center+ (read-outs built on payoffPlan above; nothing here is a second payoff engine)

/// The headline numbers for the whole household's debts.
struct HBDebtSummary: Equatable {
    var count = 0, openCount = 0
    var startTotal = 0.0, paidTotal = 0.0, remaining = 0.0
    var minimums = 0.0                    // minimum payments per month, debts with a balance only
    var interestPerMonth = 0.0            // roughly what the current balances cost in interest each month
    /// 0…1 share of everything originally owed that has been paid
    var progress: Double { startTotal > 0 ? Swift.min(1, paidTotal / startTotal) : 0 }
}

/// Snowball and Avalanche run side by side with the same extra payment.
struct HBStrategyCompare: Equatable {
    let snowball: HBPayoffPlan
    let avalanche: HBPayoffPlan
    /// the strategy that costs less interest (then finishes sooner); nil when they come out the same or one of them never pays off
    let better: HBDebtStrategy?
    var interestSaved: Double {      // what `better` saves over the other one
        guard let b = better else { return 0 }
        return Swift.max(0, b == .avalanche ? snowball.interest - avalanche.interest : avalanche.interest - snowball.interest)
    }
    var monthsSooner: Int {           // how many months sooner `better` is debt-free (0 when they finish together)
        guard let b = better, let s = snowball.months, let a = avalanche.months else { return 0 }
        return b == .avalanche ? Swift.max(0, s - a) : Swift.max(0, a - s)
    }
    func plan(_ s: HBDebtStrategy) -> HBPayoffPlan { s == .snowball ? snowball : avalanche }
}

/// "What if I put $X more toward my debt each month?", against what is planned now.
struct HBExtraImpact: Equatable {
    let add: Double                   // the additional monthly amount that was tried
    let plan: HBPayoffPlan            // the plan with (current extra + add)
    let monthsSooner: Int?            // nil unless both plans have a debt-free date
    let interestSaved: Double?        // nil unless both plans have a debt-free date
}

extension HBPlan {
    static func debtSummary(_ debts: [HBDebt]) -> HBDebtSummary {
        var s = HBDebtSummary()
        s.count = debts.count
        for d in debts {
            // paid is counted up to what was owed, so start − paid = remaining holds even if a debt was overpaid (the website's 'remaining' stops at $0 too)
            s.startTotal += d.start; s.paidTotal += Double(min(d.paid_cents, d.start_cents)) / 100.0; s.remaining += d.remaining
            if !d.paidOff { s.openCount += 1; s.minimums += d.minimum; s.interestPerMonth += d.remaining * d.apr / 100.0 / 12.0 }
        }
        return s
    }

    static func compareStrategies(_ debts: [HBDebt], extra: Double) -> HBStrategyCompare {
        let sn = payoffPlan(debts, strategy: .snowball, extra: extra), av = payoffPlan(debts, strategy: .avalanche, extra: extra)
        var better: HBDebtStrategy? = nil
        if let sm = sn.months, let am = av.months {
            let diff = sn.interest - av.interest          // > 0: Avalanche costs less
            if diff > 0.005 { better = .avalanche }
            else if diff < -0.005 { better = .snowball }
            else if am < sm { better = .avalanche }
            else if sm < am { better = .snowball }
        }
        return HBStrategyCompare(snowball: sn, avalanche: av, better: better)
    }

    static func extraImpact(_ debts: [HBDebt], strategy: HBDebtStrategy, extra: Double, adding add: Double) -> HBExtraImpact {
        let base = payoffPlan(debts, strategy: strategy, extra: extra)
        let with = payoffPlan(debts, strategy: strategy, extra: extra + Swift.max(0, add))
        if let bm = base.months, let wm = with.months { return HBExtraImpact(add: add, plan: with, monthsSooner: Swift.max(0, bm - wm), interestSaved: Swift.max(0, base.interest - with.interest)) }
        return HBExtraImpact(add: add, plan: with, monthsSooner: nil, interestSaved: nil)
    }

    /// a short, human length of time: 14 → "1 yr 2 mo", 3 → "3 mo", 24 → "2 yrs"
    static func duration(months n: Int) -> String {
        if n < 12 { return "\(n) mo" }
        let y = n / 12, m = n % 12
        return (y == 1 ? "1 yr" : "\(y) yrs") + (m > 0 ? " \(m) mo" : "")
    }

    /// Who paid how much toward `debt` (all time). Uses the server's totals when it sends them; an older server falls back to the recent payments it does send.
    static func contributions(for debt: HBDebt, snapshot s: HBNestSnapshot) -> [(memberID: String, paid: Double)] {
        var by: [String: Int] = [:]
        if let all = s.debt_paid_by { for c in all where c.debt_id == debt.id { by[c.member_id, default: 0] += c.paid_cents } }
        else { for p in s.debt_payments ?? [] where p.debt_id == debt.id { by[p.member_id, default: 0] += p.amount_cents } }
        // household order, then anyone who has since left
        let order = s.members.map { $0.id }
        let known = order.compactMap { id in by[id].map { (memberID: id, paid: Double($0) / 100.0) } }
        let gone = by.keys.filter { !order.contains($0) }.sorted().map { (memberID: $0, paid: Double(by[$0] ?? 0) / 100.0) }
        return (known + gone).filter { $0.paid > 0 }
    }
}

/// the strategy and the extra monthly amount are remembered on this device (the website keeps them in the browser the same way)
enum HBDebtPrefs {
    static let strategyKey = "hb-debt-strat", extraKey = "hb-debt-extra"
    static func strategy(_ d: UserDefaults = .standard) -> HBDebtStrategy { HBDebtStrategy(rawValue: d.string(forKey: strategyKey) ?? "") ?? .snowball }
    static func setStrategy(_ s: HBDebtStrategy, _ d: UserDefaults = .standard) { d.set(s.rawValue, forKey: strategyKey) }
    static func extra(_ d: UserDefaults = .standard) -> Double { max(0, Double(d.string(forKey: extraKey) ?? "") ?? 0) }
    static func setExtra(_ v: Double, _ d: UserDefaults = .standard) { d.set(String(max(0, v.isFinite ? v : 0)), forKey: extraKey) }
}

enum HBPlanText {
    /// 5 → "5", 5.25 → "5.25"  (the website trims a trailing .00)
    static func percent(_ v: Double) -> String { let s = String(format: "%.2f", v); return s.hasSuffix(".00") ? String(s.dropLast(3)) : s }
}


/// "Before payday": the website's upcoming() + renderDue footer. Bills still unpaid until the day before the next payday (or 30 days when there is no
/// payday), including late ones from the last month; paydays on that same day; and what is left after those bills.
struct HBBeforePayday: Equatable {
    var payday: Date?
    var bills: [(label: String, date: Date, late: Bool, amount: Double)]
    var paydays: [(label: String, date: Date, amount: Double)]
    var due: Double { bills.reduce(0) { $0 + $1.amount } }
    static func == (a: HBBeforePayday, b: HBBeforePayday) -> Bool { a.payday == b.payday && a.bills.count == b.bills.count && a.paydays.count == b.paydays.count && a.due == b.due }
}
extension HBPlan {
    static func beforePayday(_ s: HBNestSnapshot, today: Date = HBDay.startOfToday()) -> HBBeforePayday? {
        guard !s.recurring.isEmpty else { return nil }
        let logged = Set(s.logged.map { $0.recurring_id + "|" + $0.occ_date })
        var payday: Date? = nil
        var pays: [(label: String, date: Date, amount: Double)] = []
        for r in s.recurring where r.isIncome {
            guard let d = HBRecur.occurrences(r, from: today, to: HBDay.addDays(today, 62)).first(where: { !logged.contains(r.id + "|" + HBDay.string($0)) }) else { continue }
            if payday == nil || d < payday! { payday = d; pays = [(r.label, d, r.amount)] }
            else if d == payday! { pays.append((r.label, d, r.amount)) }
        }
        let until = payday.map { HBDay.addDays($0, -1) } ?? HBDay.addDays(today, 30)
        var bills: [(label: String, date: Date, late: Bool, amount: Double)] = []
        for r in s.recurring where !r.isIncome {
            for d in HBRecur.occurrences(r, from: HBDay.addDays(today, -31), to: until) where !logged.contains(r.id + "|" + HBDay.string(d)) {
                bills.append((r.label, d, d < today, r.amount))
            }
        }
        bills.sort { $0.date < $1.date }
        return HBBeforePayday(payday: payday, bills: bills, paydays: pays)
    }
}


/// The carry-over line on the website's Home ("Carried over from August +$X / This month …" or "Started this month fresh") and whether "Change" is offered.
struct HBCarryCard: Equatable {
    enum Kind: Equatable { case carried(Double), fresh }
    let kind: Kind
    let fromMonth: String
    let canChange: Bool
}
extension HBPlan {
    static func carryCard(_ s: HBNestSnapshot, month: String, today: Date = HBDay.startOfToday()) -> HBCarryCard? {
        guard let ci = s.carry_in else { return nil }
        let isCurrent = month == HBDay.monthKey(today)
        let from = HBDay.shiftMonth(month, by: -1)
        let change = isCurrent && s.carry_prev != nil
        if ci.amount_cents != 0 { return HBCarryCard(kind: .carried(Double(ci.amount_cents) / 100.0), fromMonth: from, canChange: change) }
        if isCurrent && ci.accepted == false && s.carry_prev != nil { return HBCarryCard(kind: .fresh, fromMonth: from, canChange: true) }
        return nil
    }
}
