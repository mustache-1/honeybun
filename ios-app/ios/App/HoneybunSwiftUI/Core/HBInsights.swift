import Foundation

// Phase 7, "Smarter Honeybun": one deterministic insight engine over the data the app already has.
//
// What it is: plain functions of the /api/nest snapshot (plus last month's expenses and the Debt Center+ settings). Every insight carries a
// trace: the rule that fired, the numbers it used, and how its priority was worked out. Nothing is random, nothing is guessed, and a
// statement is only made when the numbers behind it clear a threshold. When there is not enough history, it says nothing (or, at most,
// says what Bun is waiting for).
//
// What it is not: financial advice. It describes the user's own budgeting data ("you've spent $86 less than at this point last month").
//
// What it reuses (no second copy of any of these): HBPlan.forecast / beforePayday / spentByCategory / payoffPlan / compareStrategies /
// extraImpact, HBHeadsUpRules (budgets at 80%+, price changes), HBRecur.occurrences, HBDay.
//
// Privacy: the snapshot already leaves out other members' private entries. Household ("together") insights go further and use ONLY entries
// that are shared and not private, shared bills, and debt payments, so nothing about anyone's private spending can reach them.

enum HBInsightKind: String, Equatable {
    case safeToSpend, forecast, budget, pace, comparison, bills, recurring, debt, goal, together, onboarding
    /// Home shows at most one insight per group, so one idea never fills the screen
    var group: String { self == .pace ? "budget" : rawValue }
}
enum HBInsightTone: String, Equatable { case positive, neutral, watch, warning }

/// one labelled number an insight was built from (shown under "Why am I seeing this?")
struct HBInsightFact: Equatable { let label: String; let value: String }

/// How an insight came to exist and how it was ranked. score = (0.40 urgency + 0.30 impact + 0.30 timing) × confidence × novelty.
struct HBInsightTrace: Equatable {
    var rule: String
    var facts: [HBInsightFact]
    var urgency: Double, impact: Double, timing: Double, confidence: Double
    var novelty: Double = 1          // 1 the first time; lower the more days it has already been on Home
    var score: Double { (0.40 * urgency + 0.30 * impact + 0.30 * timing) * confidence * novelty }
    func explanation() -> [String] {
        var out = facts.map { "\($0.label): \($0.value)" }
        out.append(String(format: "Priority %.2f (urgency %.2f, impact %.2f, timing %.2f, confidence %.2f)", score, urgency, impact, timing, confidence))
        return out
    }
}

struct HBInsight: Identifiable, Equatable {
    let id: String
    let kind: HBInsightKind
    let tone: HBInsightTone
    let title: String
    let note: String
    var category: String? = nil
    var ratio: Double? = nil         // budget rows draw a bar
    var dismissKey: String? = nil    // a price change keeps the website's own dismiss key
    var trace: HBInsightTrace
    var score: Double { trace.score }
}

/// what Home shows, and what waits behind "More from Bun"
struct HBInsightPlan: Equatable {
    var shown: [HBInsight] = []
    var more: [HBInsight] = []
}

/// which insights were dismissed, and on how many different days each one was already on Home (so Bun doesn't repeat itself)
struct HBInsightMemory: Codable, Equatable {
    var dismissed: [String] = []
    var shown: [String: Int] = [:]
    var lastDay: [String: String] = [:]
    static let key = "hb-insight-memory-v1"

    static func load(_ d: UserDefaults = .standard) -> HBInsightMemory {
        guard let data = d.data(forKey: key), let m = try? JSONDecoder().decode(HBInsightMemory.self, from: data) else { return HBInsightMemory() }
        return m
    }
    func save(_ d: UserDefaults = .standard) { if let data = try? JSONEncoder().encode(self) { d.set(data, forKey: HBInsightMemory.key) } }
    static func clear(_ d: UserDefaults = .standard) { d.removeObject(forKey: key) }

    mutating func dismiss(_ id: String) {
        if !dismissed.contains(id) { dismissed.append(id) }
        if dismissed.count > 200 { dismissed = Array(dismissed.suffix(200)) }
    }
    /// counts a day on Home once per day per insight
    mutating func markShown(_ ids: [String], day: String) {
        for id in ids where lastDay[id] != day { shown[id, default: 0] += 1; lastDay[id] = day }
        if shown.count > 300 { // forget the oldest-looking half (ids carry their month, so they age out on their own)
            for k in shown.keys.sorted().prefix(150) { shown[k] = nil; lastDay[k] = nil }
        }
    }
    /// 1 the first time, then 0.8, 0.6, 0.4 (never lower, so a still-urgent thing never disappears)
    func novelty(_ id: String) -> Double { 1 - 0.2 * Double(Swift.min(3, shown[id] ?? 0)) }
}

/// one expense from last month, kept only as small facts (never labels), for "same point last month" comparisons
struct HBPrevRow: Equatable { let day: Int; let category: String; let amount: Double; let shared: Bool; let recurring: Bool }
struct HBPrevMonth: Equatable {
    let month: String
    let rows: [HBPrevRow]
    init(month: String, entries: [HBEntry]) {
        self.month = month
        var built: [HBPrevRow] = []
        for e in entries where !e.isIncome {
            let day: Int = Int(e.date.suffix(2)) ?? 1
            let category: String = e.category ?? "other"
            let isShared: Bool = e.shared == 1 && e.isPrivate == 0
            built.append(HBPrevRow(day: day, category: category, amount: e.amount, shared: isShared, recurring: e.recurring_id != nil))
        }
        self.rows = built
    }
    var total: Double { rows.reduce(0) { $0 + $1.amount } }
    var dim: Int {
        guard let first = HBDay.parse(month + "-01"), let span = HBDay.cal.range(of: .day, in: .month, for: first) else { return 30 }
        return span.count
    }
    func everyday(through day: Int, sharedOnly: Bool = false) -> Double {
        var total: Double = 0
        for r in rows where !r.recurring && r.day <= day {
            if sharedOnly && !r.shared { continue }
            total += r.amount
        }
        return total
    }
    func everydayByCategory(through day: Int) -> [String: Double] {
        var by: [String: Double] = [:]
        for r in rows where !r.recurring && r.day <= day { by[r.category, default: 0] += r.amount }
        return by
    }
}

struct HBInsightContext {
    var snapshot: HBNestSnapshot
    var entries: [HBEntry]            // the month's entries as Home counts them (anything saved offline included)
    var month: String
    var today: Date = HBDay.startOfToday()
    var myID: String
    var me: HBMember? = nil
    var prev: HBPrevMonth? = nil
    var strategy: HBDebtStrategy = .snowball
    var extra: Double = 0
    var priceSeen: [String] = []
    var memory = HBInsightMemory()
}

enum HBInsights {
    // MARK: tuning (every threshold in one place; each is covered by a test)
    static let minScore = 0.18
    static let homeCount = 3, urgentExtra = 0.75
    static let weekChangeMin = 40.0           // Safe to Spend must move this much in 7 days before Bun mentions it
    static let pastLeftMin = 5.0

    // MARK: helpers
    static func clamp(_ v: Double) -> Double { Swift.min(1, Swift.max(0, v)) }
    static func whole(_ v: Double) -> String { HBHeadsUpRules.whole(v) }
    static func fmt(_ v: Double) -> String { HBHeadsUpRules.fmt(v) }
    static func cap(_ s: String) -> String { s.prefix(1).uppercased() + s.dropFirst() }
    static func name(_ category: String) -> String { HBCatStyle.of(category).label }

    struct Cal {
        let isCurrent: Bool, day: Int, dim: Int, daysLeft: Int
        init(_ c: HBInsightContext) {
            isCurrent = c.month == HBDay.monthKey(c.today)
            let first = HBDay.parse(c.month + "-01") ?? c.today
            dim = HBDay.cal.range(of: .day, in: .month, for: first)?.count ?? 30
            day = isCurrent ? HBDay.cal.component(.day, from: c.today) : dim
            daysLeft = dim - day
        }
    }

    static func trace(_ rule: String, _ facts: [(String, String)], u: Double, m: Double, t: Double, c: Double = 1) -> HBInsightTrace {
        HBInsightTrace(rule: rule, facts: facts.map { HBInsightFact(label: $0.0, value: $0.1) }, urgency: clamp(u), impact: clamp(m), timing: clamp(t), confidence: clamp(c))
    }

    static func sum(_ es: [HBEntry]) -> Double { es.reduce(0) { $0 + $1.amount } }
    static func income(_ c: HBInsightContext) -> Double { sum(c.entries.filter { $0.isIncome }) }
    static func spent(_ c: HBInsightContext) -> Double { sum(c.entries.filter { !$0.isIncome }) }
    static func carryIn(_ c: HBInsightContext) -> Double { Double(c.snapshot.carry_in?.amount_cents ?? 0) / 100.0 }
    /// the same number as Home's "Safe to spend": income − spending + carry-over
    static func left(_ c: HBInsightContext) -> Double { income(c) - spent(c) + carryIn(c) }
    /// bills Home may speak about: yours and the shared ones (the forecast uses the same rule)
    static func visible(_ r: HBRecurring, _ c: HBInsightContext) -> Bool { r.type != "expense" || r.shared == 1 || r.member_id == c.myID }
    static func perMonth(_ r: HBRecurring) -> Double { r.amount * (HBPlan.perMonthFactor[r.freq] ?? 1) }

    // MARK: the whole list

    /// every insight that applies, dismissed ones removed, best first
    static func all(_ c: HBInsightContext) -> [HBInsight] {
        let clock = Cal(c)
        var out: [HBInsight] = []
        out += headsUp(c, clock)
        out += safeToSpend(c, clock)
        out += forecast(c, clock)
        out += pace(c, clock)
        out += comparisons(c, clock)
        out += bills(c, clock)
        out += recurringCosts(c, clock)
        out += debts(c, clock)
        out += goals(c, clock)
        out += together(c, clock)
        // low-data nudges only when nothing else has anything to say
        if out.isEmpty { out += onboarding(c, clock) }
        var ranked: [HBInsight] = []
        for var i in out where !c.memory.dismissed.contains(i.id) {
            i.trace.novelty = c.memory.novelty(i.id)
            ranked.append(i)
        }
        return ranked.sorted(by: byScore)
    }

    /// Which few to show. At most `homeCount` (a fourth only when it is urgent), one per group, nothing below `minScore`, and a good-news
    /// insight gets a place whenever there is one, so Honeybun doesn't only speak up when something is wrong.
    /// best first; equal scores fall back to the id so the order never changes between runs
    static func byScore(_ a: HBInsight, _ b: HBInsight) -> Bool {
        let sa: Double = a.score, sb: Double = b.score
        if sa != sb { return sa > sb }
        return a.id < b.id
    }

    static func home(_ c: HBInsightContext) -> HBInsightPlan { pick(all(c)) }

    static func pick(_ ranked: [HBInsight]) -> HBInsightPlan {
        let eligible = ranked.filter { $0.score >= minScore }
        var shown: [HBInsight] = []
        var groups = Set<String>()
        for i in eligible {
            if groups.contains(i.kind.group) { continue }
            if shown.count >= homeCount {
                // a fourth only when it is urgent
                if shown.count == homeCount && i.score >= urgentExtra { shown.append(i); groups.insert(i.kind.group) }
                continue
            }
            shown.append(i); groups.insert(i.kind.group)
        }
        if !shown.contains(where: { $0.tone == .positive }), let good = eligible.first(where: { $0.tone == .positive && $0.score >= 0.25 && !groups.contains($0.kind.group) }) {
            if shown.count < homeCount { shown.append(good) }
            else if let last = shown.last, !(last.tone == .warning && last.score >= urgentExtra) { shown[shown.count - 1] = good }
        }
        shown.sort(by: byScore)
        let ids = Set(shown.map { $0.id })
        return HBInsightPlan(shown: shown, more: eligible.filter { !ids.contains($0.id) })
    }

    // MARK: Heads up from Bun (the existing rules, now ranked with everything else)

    static func headsUp(_ c: HBInsightContext, _ k: Cal) -> [HBInsight] {
        var out: [HBInsight] = []
        // the forecast row is replaced by the richer forecast insight below, so it is switched off here
        let hu = HBHeadsUpRules.compute(c.snapshot, month: c.month, me: c.me, today: c.today, seen: c.priceSeen, forecast: .notThisMonth)
        let aggregate = recurringIncrease(c, k) != nil     // one note covers every recent increase, so the separate price rows step aside
        for r in hu.rows {
            switch r.kind {
            case let .budget(category, ratio):
                let lim = Double(c.snapshot.budgets?.first { $0.category == category }?.limit_cents ?? 0) / 100.0
                out.append(HBInsight(id: "budget-\(category)-\(c.month)", kind: .budget, tone: ratio > 1 ? .warning : .watch, title: r.title, note: r.note, category: category, ratio: ratio,
                    trace: trace("budget at 80% or more", [("Budget used", "\(Int((ratio * 100).rounded()))%"), ("Monthly limit", whole(lim)), ("Days left", "\(k.daysLeft)")],
                                 u: 0.5 + (ratio - 0.8) * 1.5, m: lim / 500, t: k.isCurrent ? Double(k.day) / Double(k.dim) : 0.3)))
            case .priceUp:
                if aggregate { continue }
                out.append(HBInsight(id: "price-" + (r.dismissKey ?? r.id), kind: .recurring, tone: .watch, title: r.title, note: r.note, dismissKey: r.dismissKey,
                    trace: trace("recurring price went up in the last 30 days", [("Change", r.note), ("Now", r.title)], u: 0.4, m: 0.3, t: 0.5)))
            case .priceDown:
                out.append(HBInsight(id: "price-" + (r.dismissKey ?? r.id), kind: .recurring, tone: .positive, title: r.title, note: r.note, dismissKey: r.dismissKey,
                    trace: trace("recurring price went down in the last 30 days", [("Change", r.note), ("Now", r.title)], u: 0.2, m: 0.3, t: 0.5)))
            case .forecast: break
            }
        }
        return out
    }

    // MARK: Safe to Spend (the number itself is unchanged: income − spending + carry-over)

    struct Week { let spent: Double, usual: Double, basis: String }
    /// everyday spending (not bills) in the last 7 days against a typical week: this month's earlier weeks when there are at least two, otherwise last month's average
    static func week(_ c: HBInsightContext, _ k: Cal) -> Week? {
        guard k.isCurrent, k.day >= 7 else { return nil }
        let start = HBDay.string(HBDay.addDays(c.today, -6)), end = HBDay.string(c.today)
        let loose = c.entries.filter { !$0.isIncome && $0.recurring_id == nil }
        let last7 = sum(loose.filter { $0.date >= start && $0.date <= end })
        let daysBefore = k.day - 7
        if daysBefore >= 14 { return Week(spent: last7, usual: sum(loose.filter { $0.date < start }) / (Double(daysBefore) / 7.0), basis: "this month") }
        if let p = c.prev {
            let total = p.rows.filter { !$0.recurring }.reduce(0) { $0 + $1.amount }
            if total >= 150 { return Week(spent: last7, usual: total / (Double(p.dim) / 7.0), basis: "last month") }
        }
        return nil
    }
    static func weekHigh(_ w: Week) -> Bool { w.spent >= w.usual * 1.4 && w.spent - w.usual >= 30 }
    static func weekLow(_ w: Week) -> Bool { w.usual >= 60 && w.spent <= w.usual * 0.6 && w.usual - w.spent >= 30 }

    /// money that came in / went out in the last 7 days (needs a whole week inside the month)
    static func weekNet(_ c: HBInsightContext, _ k: Cal) -> (came: Double, spent: Double)? {
        guard k.isCurrent, k.day >= 7 else { return nil }
        let start = HBDay.string(HBDay.addDays(c.today, -6)), end = HBDay.string(c.today)
        let win = c.entries.filter { $0.date >= start && $0.date <= end }
        return (sum(win.filter { $0.isIncome }), sum(win.filter { !$0.isIncome }))
    }

    static func safeToSpend(_ c: HBInsightContext, _ k: Cal) -> [HBInsight] {
        guard k.isCurrent else { return [] }
        var out: [HBInsight] = []
        let l = left(c)
        // only once income has been logged: with nothing recorded as coming in, a negative number just means the month is new
        if l < -pastLeftMin && income(c) + carryIn(c) > 0 {
            out.append(HBInsight(id: "over-\(c.month)", kind: .safeToSpend, tone: .warning, title: "You're \(whole(-l)) past what has come in",
                note: "\(whole(spent(c))) spent against \(whole(income(c) + carryIn(c))) in this month (carry-over counted). More income or lighter everyday spending would bring it back.",
                trace: trace("left this month is below zero", [("Came in", whole(income(c))), ("Carry-over", whole(carryIn(c))), ("Spent", whole(spent(c))), ("Left", fmt(l))], u: 0.5 + 0.5 * clamp(-l / 200), m: -l / 300, t: 0.8)))
        }
        if let w = weekNet(c, k) {
            let net = w.came - w.spent
            let wk = week(c, k)
            if net <= -weekChangeMin {
                var note = "You spent \(whole(w.spent))" + (w.came > 0 ? " and \(whole(w.came)) came in" : "") + " over the last 7 days."
                var facts: [(String, String)] = [("Spent, last 7 days", fmt(w.spent)), ("Came in, last 7 days", fmt(w.came)), ("Change", fmt(net))]
                if let wk = wk, weekHigh(wk) {
                    note += " That's more than a usual week (about \(whole(wk.usual)))."
                    facts += [("Everyday spending, last 7 days", fmt(wk.spent)), ("A usual week (\(wk.basis))", fmt(wk.usual))]
                }
                out.append(HBInsight(id: "sts-down-\(c.month)-w\((k.day - 1) / 7)", kind: .safeToSpend, tone: .watch, title: "Safe to spend is down \(whole(-net)) this week", note: note,
                    trace: trace("net money over the last 7 days is negative", facts, u: -net / 300, m: -net / 400, t: 0.6)))
            } else if net >= weekChangeMin {
                out.append(HBInsight(id: "sts-up-\(c.month)-w\((k.day - 1) / 7)", kind: .safeToSpend, tone: .positive, title: "Safe to spend is up \(whole(net)) this week",
                    note: "\(whole(w.came)) came in and you spent \(whole(w.spent)) over the last 7 days.",
                    trace: trace("net money over the last 7 days is positive", [("Came in, last 7 days", fmt(w.came)), ("Spent, last 7 days", fmt(w.spent)), ("Change", fmt(net))], u: 0.15, m: net / 500, t: 0.6)))
            }
        }
        return out
    }

    /// The one line under Home's Safe to Spend number. Only statements the numbers support; it never claims bills are "already accounted for"
    /// (Safe to Spend is income − spending + carry-over; upcoming bills are shown separately, and that is what this says).
    static func safeLine(_ c: HBInsightContext) -> String? {
        let k = Cal(c)
        let l = left(c)
        if l < 0 { return "\(whole(-l)) more has gone out than has come in\(carryIn(c) != 0 ? " (carry-over counted)" : "")." }
        if k.isCurrent, let b = HBPlan.beforePayday(c.snapshot, today: c.today), b.due > 0 {
            let when = b.payday.map { "before \(HBDay.dayName($0))'s payday" } ?? "in the next 30 days"
            let after = l - b.due
            let due: String = whole(b.due)
            if after >= 0 { return "\(due) of bills are due \(when); you'd have \(whole(after)) after them." }
            return "\(due) of bills are due \(when), about \(whole(-after)) more than you have left."
        }
        if income(c) + carryIn(c) > 0 { return "\(whole(income(c) + carryIn(c))) in\(carryIn(c) != 0 ? " (carry-over counted)" : "") minus \(whole(spent(c))) spent." }
        return nil
    }

    // MARK: month-end forecast (HBPlan.forecast is the engine; this words it and adds what is behind it)

    /// the biggest everyday-spending categories so far, only when there is enough to say
    static func topCategories(_ c: HBInsightContext) -> [(category: String, share: Double)] {
        let loose = c.entries.filter { !$0.isIncome && $0.recurring_id == nil }
        let total = sum(loose)
        guard loose.count >= 4, total > 0 else { return [] }
        var by: [String: Double] = [:]
        for e in loose { by[e.category ?? "other", default: 0] += e.amount }
        var shares: [(category: String, share: Double)] = []
        for (category, amount) in by {
            let share: Double = amount / total
            if share >= 0.2 { shares.append((category: category, share: share)) }
        }
        shares.sort { (a: (category: String, share: Double), b: (category: String, share: Double)) -> Bool in
            if a.share != b.share { return a.share > b.share }
            return a.category < b.category
        }
        return Array(shares.prefix(2))
    }

    static func forecastResult(_ c: HBInsightContext) -> HBForecastResult {
        HBPlan.forecast(c.snapshot, month: c.month, today: c.today, myID: c.myID, lastMonthSpent: c.prev?.total)
    }

    /// "how much less would put me back on track": spending `perWeek` less on everyday things for the rest of the month ends the month at $0
    static func backOnTrack(_ f: HBForecast) -> (perDay: Double, perWeek: Double)? {
        guard f.endLeft < 0, f.daysLeft >= 3, f.ahead > 0 else { return nil }
        let need = -f.endLeft / Double(f.daysLeft)
        let everyday = f.ahead / Double(f.daysLeft)
        guard need <= everyday * 0.8 else { return nil }      // only when it is a believable amount to ease off
        return (need, (need * 7).rounded(.up))
    }

    static func forecast(_ c: HBInsightContext, _ k: Cal) -> [HBInsight] {
        switch forecastResult(c) {
        case .notThisMonth: return []
        case let .wait(day):
            // not enough yet: say what Bun is waiting for, only to someone who has started logging
            guard !c.entries.isEmpty else { return [] }
            return [HBInsight(id: "forecast-wait-\(c.month)", kind: .forecast, tone: .neutral, title: "Bun is still learning your month",
                note: "A month-end forecast needs about a week of spending (day \(day) now, \(c.entries.filter { !$0.isIncome }.count) expenses logged). Keep logging and it appears here.",
                trace: trace("not enough history for a forecast", [("Day of month", "\(day)"), ("Expenses logged", "\(c.entries.filter { !$0.isIncome }.count)"), ("Needs", "day 7 and 5 expenses")], u: 0.1, m: 0.1, t: 0.3))]
        case let .ready(f):
            let end = f.endLeft
            let month = HBDay.monthName(c.month)
            let facts: [(String, String)] = [("Left now", fmt(f.leftNow)), ("Paychecks still due", fmt(f.pays)), ("Bills still due", fmt(f.bills)), ("Everyday spending ahead", fmt(f.ahead)), ("Projected month-end", fmt(end))]
            let conf: Double = f.day >= 10 ? 1.0 : 0.7
            let monthTiming: Double = 0.5 + 0.5 * Double(f.day) / Double(f.dim)
            let shortUrgency: Double = 0.6 + Swift.min(0.4, -end / 500 * 0.4)
            if end < 0 {
                var note = "At your current pace you'd finish \(month) about \(whole(-end)) short."
                let top = topCategories(c)
                if !top.isEmpty { note += " Most of your everyday spending so far is \(top.map { name($0.category) }.joined(separator: " and "))." }
                if let b = backOnTrack(f) { note += " Spending about \(whole(b.perWeek)) less a week on everyday things would put you back on track." }
                return [HBInsight(id: "forecast-\(c.month)", kind: .forecast, tone: .warning, title: "Heading toward -\(whole(-end))", note: note,
                    trace: trace("projected month-end is below zero", facts, u: shortUrgency, m: -end / 300, t: monthTiming, c: conf))]
            }
            if end < 50 {
                return [HBInsight(id: "forecast-\(c.month)", kind: .forecast, tone: .watch, title: "Cutting it close: about \(whole(end)) left",
                    note: "At your current pace you'd finish \(month) with about \(whole(end)) remaining.",
                    trace: trace("projected month-end is under $50", facts, u: 0.35, m: 0.2, t: monthTiming, c: conf))]
            }
            return [HBInsight(id: "forecast-\(c.month)", kind: .forecast, tone: .positive, title: "On track for +\(whole(end))",
                note: "At your current pace you're projected to finish \(month) with about \(whole(end)) remaining.",
                trace: trace("projected month-end is comfortably above zero", facts, u: 0.1, m: end / 600, t: 0.4 + 0.4 * Double(f.day) / Double(f.dim), c: conf))]
        }
    }

    /// extra lines for the forecast card in Plan: what is behind the projection and what would change it
    static func forecastNotes(_ c: HBInsightContext) -> [String] {
        guard case let .ready(f) = forecastResult(c) else { return [] }
        var out: [String] = []
        let top = topCategories(c)
        if !top.isEmpty { out.append("Most of your everyday spending so far is \(top.map { name($0.category) }.joined(separator: " and ")).") }
        if let b = backOnTrack(f) { out.append("Spending about \(whole(b.perWeek)) less a week on everyday things for the rest of the month would put you back on track.") }
        return out
    }

    // MARK: spending pace and comparisons

    static func pace(_ c: HBInsightContext, _ k: Cal) -> [HBInsight] {
        var out: [HBInsight] = []
        guard k.isCurrent, k.day >= 5 else { return out }
        let by = HBPlan.spentByCategory(c.entries)
        let timeRatio = Double(k.day) / Double(k.dim)
        // budgets running ahead of the calendar (the 80%+ ones are Heads up rows above)
        for b in c.snapshot.budgets ?? [] where b.limit_cents > 0 {
            let lim = Double(b.limit_cents) / 100.0, sp = by[b.category] ?? 0, ratio = sp / lim
            guard ratio < 0.8, ratio >= 0.5, ratio - timeRatio >= 0.15 else { continue }
            let projected = sp / Double(k.day) * Double(k.dim)
            out.append(HBInsight(id: "pace-\(b.category)-\(c.month)", kind: .pace, tone: .watch, title: "\(name(b.category)) spending is running high",
                note: "You've used \(Int((ratio * 100).rounded()))% of your \(name(b.category).lowercased()) budget with \(k.daysLeft) \(k.daysLeft == 1 ? "day" : "days") left.", category: b.category, ratio: ratio,
                trace: trace("budget used is well ahead of the month", [("Budget used", "\(Int((ratio * 100).rounded()))%"), ("Month elapsed", "\(Int((timeRatio * 100).rounded()))%"), ("Spent", fmt(sp)), ("Limit", fmt(lim)), ("Projected at this pace", fmt(projected))],
                             u: (ratio - timeRatio) / 0.4, m: (projected - lim) / 150, t: timeRatio, c: k.day >= 10 ? 1 : 0.7)))
        }
        // this week against a usual week
        if let w = week(c, k) {
            if weekHigh(w) {
                out.append(HBInsight(id: "week-high-\(c.month)-w\((k.day - 1) / 7)", kind: .pace, tone: .watch, title: "This week has been a bigger one",
                    note: "\(whole(w.spent)) of everyday spending in the last 7 days, against about \(whole(w.usual)) in a usual week.",
                    trace: trace("last 7 days of everyday spending well above a usual week", [("Last 7 days", fmt(w.spent)), ("A usual week (\(w.basis))", fmt(w.usual))], u: (w.spent - w.usual) / 200, m: (w.spent - w.usual) / 250, t: 0.6)))
            } else if weekLow(w) {
                out.append(HBInsight(id: "week-low-\(c.month)-w\((k.day - 1) / 7)", kind: .pace, tone: .positive, title: "A lighter week",
                    note: "\(whole(w.spent)) of everyday spending in the last 7 days, against about \(whole(w.usual)) in a usual week.",
                    trace: trace("last 7 days of everyday spending well below a usual week", [("Last 7 days", fmt(w.spent)), ("A usual week (\(w.basis))", fmt(w.usual))], u: 0.1, m: (w.usual - w.spent) / 250, t: 0.5)))
            }
        }
        return out
    }

    static func comparisons(_ c: HBInsightContext, _ k: Cal) -> [HBInsight] {
        var out: [HBInsight] = []
        guard k.isCurrent, k.day >= 7, let p = c.prev, p.total >= 100 else { return out }
        let loose = c.entries.filter { !$0.isIncome && $0.recurring_id == nil && (Int($0.date.suffix(2)) ?? 99) <= k.day }
        let now = sum(loose), before = p.everyday(through: k.day)
        guard before >= 50 else { return out }
        let diff = now - before
        let facts: [(String, String)] = [("Everyday spending so far", fmt(now)), ("Same point last month", fmt(before)), ("Difference", fmt(diff))]
        if abs(diff) >= Swift.max(25, 0.10 * before) {
            if diff < 0 {
                out.append(HBInsight(id: "vs-less-\(c.month)", kind: .comparison, tone: .positive, title: "You're doing better than last month",
                    note: "You've spent \(whole(-diff)) less on everyday things than at this point last month.",
                    trace: trace("everyday spending is meaningfully below the same point last month", facts, u: 0.1, m: -diff / 200, t: 0.5, c: k.day >= 10 ? 1 : 0.8)))
            } else {
                out.append(HBInsight(id: "vs-more-\(c.month)", kind: .comparison, tone: .watch, title: "Spending is a little ahead of last month",
                    note: "\(whole(diff)) more on everyday things than at this point last month (\(whole(now)) vs \(whole(before))).",
                    trace: trace("everyday spending is meaningfully above the same point last month", facts, u: diff / 300, m: diff / 250, t: 0.5, c: k.day >= 10 ? 1 : 0.8)))
            }
        }
        // categories that moved a lot (one up, one down at most)
        var byNow: [String: Double] = [:]
        for e in loose { byNow[e.category ?? "other", default: 0] += e.amount }
        let byPrev = p.everydayByCategory(through: k.day)
        var rows: [(cat: String, now: Double, prev: Double, diff: Double)] = []
        for cat in Set(byNow.keys).union(byPrev.keys) {
            let n = byNow[cat] ?? 0, pr = byPrev[cat] ?? 0
            guard Swift.max(n, pr) >= 40, abs(n - pr) >= Swift.max(25, 0.30 * Swift.max(pr, 1)) else { continue }
            rows.append((cat, n, pr, n - pr))
        }
        rows.sort { (a: (cat: String, now: Double, prev: Double, diff: Double), b: (cat: String, now: Double, prev: Double, diff: Double)) -> Bool in
            let da: Double = abs(a.diff), db: Double = abs(b.diff)
            if da != db { return da > db }
            return a.cat < b.cat
        }
        if let up = rows.first(where: { $0.diff > 0 }) {
            out.append(HBInsight(id: "cat-up-\(up.cat)-\(c.month)", kind: .comparison, tone: .watch, title: "More going to \(name(up.cat).lowercased()) than last month",
                note: "\(whole(up.now)) so far, \(whole(up.diff)) more than at this point last month.", category: up.cat,
                trace: trace("a category is well above the same point last month", [("This month so far", fmt(up.now)), ("Same point last month", fmt(up.prev)), ("Difference", fmt(up.diff))], u: up.diff / 250, m: up.diff / 200, t: 0.5)))
        }
        if let down = rows.first(where: { $0.diff < 0 }) {
            out.append(HBInsight(id: "cat-down-\(down.cat)-\(c.month)", kind: .comparison, tone: .positive, title: "Less going to \(name(down.cat).lowercased()) than last month",
                note: "\(whole(down.now)) so far, \(whole(-down.diff)) less than at this point last month.", category: down.cat,
                trace: trace("a category is well below the same point last month", [("This month so far", fmt(down.now)), ("Same point last month", fmt(down.prev)), ("Difference", fmt(down.diff))], u: 0.1, m: -down.diff / 200, t: 0.5)))
        }
        return out
    }

    // MARK: bills, subscriptions and paydays

    static func bills(_ c: HBInsightContext, _ k: Cal) -> [HBInsight] {
        guard k.isCurrent else { return [] }
        var out: [HBInsight] = []
        let l = left(c)
        // 1. bills due before the next payday against what is left (the same numbers as Home's "Before payday" card)
        if let b = HBPlan.beforePayday(c.snapshot, today: c.today), b.due > 0 {
            let when = b.payday.map { "before \(HBDay.dayName($0))'s payday" } ?? "in the next 30 days"
            let after = l - b.due
            let daysToPay = b.payday.flatMap { HBDay.cal.dateComponents([.day], from: c.today, to: $0).day } ?? 30
            let facts: [(String, String)] = [("Bills due", fmt(b.due)), ("Bills", "\(b.bills.count)"), ("Left now", fmt(l)), ("Left after those bills", fmt(after)), ("Days to payday", b.payday == nil ? "none scheduled" : "\(daysToPay)")]
            if after < 0 {
                out.append(HBInsight(id: "bills-short-\(c.month)-\(HBDay.string(c.today).suffix(2))", kind: .bills, tone: .warning, title: "Bills may outrun what's left",
                    note: "\(whole(b.due)) is due \(when) and you have \(whole(Swift.max(0, l))) left, about \(whole(-after)) short.",
                    trace: trace("bills due before payday are more than what is left", facts, u: 0.9, m: -after / 300, t: daysToPay <= 7 ? 1 : 0.6)))
            } else if let pd = b.payday, daysToPay <= 7 {
                out.append(HBInsight(id: "bills-before-payday-\(HBDay.string(pd))", kind: .bills, tone: .neutral, title: "Payday \(HBDay.dayName(pd))",
                    note: "\(b.bills.count) \(b.bills.count == 1 ? "bill" : "bills") (\(whole(b.due))) due before then, and you'd still have \(whole(after)) after them.",
                    trace: trace("payday within a week with bills before it", facts, u: 0.15, m: b.due / 600, t: 1 - Double(daysToPay) / 10)))
            }
        }
        // 2. a heavier-than-usual bill day in the next week
        var perDay: [Int: (total: Double, count: Int)] = [:]
        let logged = Set(c.snapshot.logged.map { $0.recurring_id + "|" + $0.occ_date })
        for r in c.snapshot.recurring where !r.isIncome && visible(r, c) {
            for d in HBRecur.occurrences(r, from: c.today, to: HBDay.addDays(c.today, 30)) where !logged.contains(r.id + "|" + HBDay.string(d)) {
                let n = HBDay.cal.dateComponents([.day], from: c.today, to: d).day ?? 0
                perDay[n, default: (0, 0)].total += r.amount
                perDay[n, default: (0, 0)].count += 1
            }
        }
        let totals = perDay.values.map { $0.total }.sorted()
        if totals.count >= 3 {
            let median = totals[totals.count / 2]
            let week = perDay.filter { $0.key >= 0 && $0.key <= 7 }
            var heavy: (key: Int, value: (total: Double, count: Int))? = nil
            for entry in week {
                guard let best = heavy else { heavy = entry; continue }
                if entry.value.total > best.value.total || (entry.value.total == best.value.total && entry.key < best.key) { heavy = entry }
            }
            if let heavy = heavy {
                let t = heavy.value.total, n = heavy.value.count
                let heavier = n >= 2 ? (t >= 75 && t >= 1.5 * median) : (t >= 150 && t >= 2 * median)
                if heavier {
                    let date = HBDay.addDays(c.today, heavy.key)
                    let when = heavy.key == 0 ? "Today" : (heavy.key == 1 ? "Tomorrow" : HBDay.dayName(date))
                    let heavyNote: String
                    if n >= 2 { heavyNote = "\(whole(t)) across \(n) bills, against about \(whole(median)) on a usual bill day." }
                    else { heavyNote = "\(whole(t)) is due, against about \(whole(median)) on a usual bill day." }
                    out.append(HBInsight(id: "heavy-\(HBDay.string(date))", kind: .bills, tone: .watch, title: "\(when) is a heavier day than usual",
                        note: heavyNote,
                        trace: trace("one day's bills are well above a usual bill day", [("That day's bills", fmt(t)), ("Number of bills", "\(n)"), ("A usual bill day (next 30 days)", fmt(median)), ("Days away", "\(heavy.key)")],
                                     u: 1 - Double(heavy.key) / 10, m: t / 400, t: 1 - Double(heavy.key) / 8, c: totals.count >= 5 ? 1 : 0.75)))
                }
            }
        }
        return out
    }

    /// recurring costs that went up recently: (monthly increase, the biggest changes)
    static func recurringIncrease(_ c: HBInsightContext, _ k: Cal) -> (delta: Double, items: [(label: String, delta: Double)])? {
        guard k.isCurrent else { return nil }
        var items: [(label: String, delta: Double)] = []
        for r in c.snapshot.recurring where r.type == "expense" && visible(r, c) {
            guard let prev = r.prev_amount_cents, prev > 0, r.amount_cents != prev, let at = r.price_changed_at, let d = HBDay.parse(at) else { continue }
            let days = HBDay.cal.dateComponents([.day], from: d, to: c.today).day ?? 999
            guard days >= 0, days <= 90 else { continue }
            items.append((r.label, (Double(r.amount_cents - prev) / 100.0) * (HBPlan.perMonthFactor[r.freq] ?? 1)))
        }
        let ups = items.filter { $0.delta > 0 }
        let net = items.reduce(0) { $0 + $1.delta }
        guard ups.count >= 2, net >= 5 else { return nil }
        let biggestFirst = ups.sorted { (a: (label: String, delta: Double), b: (label: String, delta: Double)) -> Bool in
            if a.delta != b.delta { return a.delta > b.delta }
            return a.label < b.label
        }
        return (net, biggestFirst)
    }

    static func recurringCosts(_ c: HBInsightContext, _ k: Cal) -> [HBInsight] {
        guard let r = recurringIncrease(c, k) else { return [] }
        let top = r.items.prefix(2).map { "\($0.label) +\(fmt($0.delta))" }.joined(separator: ", ")
        return [HBInsight(id: "recurring-up-\(c.month)", kind: .recurring, tone: .watch, title: "Recurring costs are up \(fmt(r.delta)) a month",
            note: "Since prices changed in the last 3 months: \(top)\(r.items.count > 2 ? " and \(r.items.count - 2) more" : "").",
            trace: trace("two or more recurring costs went up in the last 90 days", [("Net monthly change", fmt(r.delta)), ("Items that went up", "\(r.items.count)")], u: 0.35, m: r.delta / 40, t: 0.4))]
    }

    // MARK: debts (Debt Center+'s payoff engine, worded)

    static func debts(_ c: HBInsightContext, _ k: Cal) -> [HBInsight] {
        let all = c.snapshot.debts ?? []
        let open = all.filter { !$0.paidOff }
        guard !open.isEmpty else { return [] }
        var out: [HBInsight] = []
        let now = HBPlan.payoffPlan(open, strategy: c.strategy, extra: c.extra)
        // 1. the latest payment, and what it did to the debt-free date (the plan with that payment taken back out vs the plan now)
        if k.isCurrent, let p = (c.snapshot.debt_payments ?? []).max(by: { $0.date < $1.date }),
           let days = HBDay.parse(p.date).flatMap({ HBDay.cal.dateComponents([.day], from: $0, to: c.today).day }), days >= 0, days <= 14,
           let nowM = HBPlan.payoffPlan(all, strategy: c.strategy, extra: c.extra).months {
            let without = all.map { d in d.id == p.debt_id ? HBDebt(id: d.id, name: d.name, start_cents: d.start_cents, apr_bp: d.apr_bp, min_cents: d.min_cents, paid_cents: Swift.max(0, d.paid_cents - p.amount_cents)) : d }
            if let beforeM = HBPlan.payoffPlan(without, strategy: c.strategy, extra: c.extra).months, beforeM > nowM {
                let from = HBPlan.monthsOut(beforeM, from: c.today), to = HBPlan.monthsOut(nowM, from: c.today)
                if from != to {
                    out.append(HBInsight(id: "debt-moved-\(p.id)", kind: .debt, tone: .positive, title: "That payment shortened your payoff",
                        note: "It moved your projected debt-free date from \(from) to \(to).",
                        trace: trace("the latest debt payment moved the projected date", [("Payment", fmt(p.amount)), ("Debt-free before it", from), ("Debt-free now", to), ("Months sooner", "\(beforeM - nowM)"), ("Strategy", c.strategy.title)],
                                     u: 0.15, m: Double(beforeM - nowM) / 6, t: 1 - Double(days) / 14)))
                }
            }
        }
        // 2. what a little extra each month would do (only when it is a real difference)
        if let m = now.months, m >= 6 {
            let imp = HBPlan.extraImpact(open, strategy: c.strategy, extra: c.extra, adding: 50)
            if let sooner = imp.monthsSooner, let saved = imp.interestSaved, sooner >= 2, saved >= 25 {
                out.append(HBInsight(id: "debt-extra-\(c.month)", kind: .debt, tone: .neutral, title: "A little extra goes a long way",
                    note: "Adding \(whole(50)) a month would make you debt-free about \(HBPlan.duration(months: sooner)) sooner and save roughly \(whole(saved)) in interest.",
                    trace: trace("an extra $50 a month shortens the payoff", [("Debt-free now", HBPlan.monthsOut(m, from: c.today)), ("Months sooner with +$50", "\(sooner)"), ("Interest saved (estimate)", fmt(saved)), ("Strategy", c.strategy.title), ("Extra planned now", fmt(c.extra))],
                                 u: 0.2, m: saved / 500, t: 0.3)))
            }
        }
        // 3. Avalanche against Snowball
        if c.strategy == .snowball, open.count >= 2 {
            let cmp = HBPlan.compareStrategies(open, extra: c.extra)
            if cmp.better == .avalanche, cmp.interestSaved >= 50 {
                out.append(HBInsight(id: "debt-avalanche-\(c.month)", kind: .debt, tone: .neutral, title: "Avalanche would cost less interest",
                    note: "Paying the highest interest first would save about \(whole(cmp.interestSaved)) compared with Snowball\(cmp.monthsSooner > 0 ? " and finish \(HBPlan.duration(months: cmp.monthsSooner)) sooner" : "").",
                    trace: trace("Avalanche beats Snowball for these debts", [("Interest saved (estimate)", fmt(cmp.interestSaved)), ("Months sooner", "\(cmp.monthsSooner)"), ("Your strategy", c.strategy.title)], u: 0.2, m: cmp.interestSaved / 500, t: 0.3)))
            }
        }
        return out
    }

    // MARK: goals

    /// when a goal would be reached at the pace of the last 90 days of contributions; nil unless there is a believable pace
    static func goalPace(_ g: HBGoal, _ c: HBInsightContext) -> (days: Double, perDay: Double, deposits: Int)? {
        guard !g.isDone, g.target_cents > 0 else { return nil }
        let start = HBDay.addDays(c.today, -90)
        let moves = (c.snapshot.jar ?? []).filter { $0.goal_id == g.id && $0.date >= start && $0.date <= HBDay.addDays(c.today, 1) }
        let deposits = moves.filter { $0.amount_cents > 0 }
        guard deposits.count >= 2 else { return nil }
        let net = moves.reduce(0) { $0 + $1.amount }
        guard net > 0, let first = deposits.map({ $0.date }).min() else { return nil }
        let span = Swift.max(30.0, (c.today.timeIntervalSince(first) / 86400.0).rounded(.up) + 1)
        let perDay = net / span
        let remaining = Double(g.target_cents - g.saved_cents) / 100.0
        let days = remaining / perDay
        if days > 1825 { return nil }
        return (days, perDay, deposits.count)
    }
    /// how many paydays a month the household's income has (for "add $25 each payday"), from the scheduled income
    static func paydaysPerMonth(_ c: HBInsightContext) -> Double? {
        let mine = c.snapshot.recurring.filter { $0.isIncome && $0.member_id == c.myID }
        guard let r = mine.first ?? c.snapshot.recurring.first(where: { $0.isIncome }) else { return nil }
        return HBPlan.perMonthFactor[r.freq]
    }
    static func monthLabel(_ d: Date, from today: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = HBDay.cal.component(.year, from: d) == HBDay.cal.component(.year, from: today) ? "MMMM" : "MMMM yyyy"
        return f.string(from: d)
    }

    static func goals(_ c: HBInsightContext, _ k: Cal) -> [HBInsight] {
        var out: [HBInsight] = []
        for g in c.snapshot.goals where g.target_cents > 0 {
            let who = g.name
            if g.isDone {
                out.append(HBInsight(id: "goal-done-\(g.id)", kind: .goal, tone: .positive, title: "\(who) is fully funded 🎉", note: "You saved \(whole(g.saved)) of \(whole(g.target)). That's a real finish.",
                    trace: trace("goal is complete", [("Saved", fmt(g.saved)), ("Target", fmt(g.target))], u: 0.1, m: 0.5, t: 0.4)))
                continue
            }
            // a milestone crossed recently
            if let m = [0.9, 0.75, 0.5, 0.25].first(where: { g.progress >= $0 && g.progress - $0 < 0.10 }) {
                let text: String
                if m == 0.5 { text = "You're halfway to \(who)" }
                else if m == 0.25 { text = "A quarter of the way to \(who)" }
                else if m == 0.75 { text = "Three quarters of the way to \(who)" }
                else { text = "Almost there: \(who)" }
                out.append(HBInsight(id: "goal-mile-\(g.id)-\(Int(m * 100))", kind: .goal, tone: .positive, title: text, note: "\(whole(g.target - g.saved)) to go.",
                    trace: trace("goal crossed a milestone in the last 10 points", [("Progress", "\(Int((g.progress * 100).rounded()))%"), ("Milestone", "\(Int(m * 100))%"), ("Saved", fmt(g.saved)), ("Target", fmt(g.target))], u: 0.1, m: 0.45, t: 0.4)))
                continue
            }
            let togo = g.target - g.saved
            if let p = goalPace(g, c) {
                let when = HBDay.addDays(c.today, Int(p.days.rounded(.up)))
                var note = "At your current contribution pace you'd reach it around \(monthLabel(when, from: c.today))."
                var facts: [(String, String)] = [("To go", fmt(togo)), ("Pace (last 90 days)", fmt(p.perDay * 30.4) + "/month"), ("Deposits counted", "\(p.deposits)")]
                if let ppm = paydaysPerMonth(c) {
                    let faster = togo / (p.perDay + 25 * ppm / 30.4)
                    let sooner = (p.days - faster) / 30.4
                    if sooner >= 1 { note += " Adding \(whole(25)) each payday would get you there about \(Int(sooner.rounded())) \(Int(sooner.rounded()) == 1 ? "month" : "months") earlier."; facts.append(("With +$25 each payday", "\(Int(sooner.rounded())) months sooner")) }
                }
                out.append(HBInsight(id: "goal-pace-\(g.id)-\(c.month)", kind: .goal, tone: .neutral, title: "\(whole(togo)) to go for \(who)", note: note,
                    trace: trace("goal has a believable contribution pace", facts, u: 0.1, m: 0.3, t: 0.3, c: p.deposits >= 3 ? 1 : 0.7)))
            } else if g.saved_cents > 0, !(c.snapshot.jar ?? []).contains(where: { $0.goal_id == g.id && $0.amount_cents > 0 && $0.date >= HBDay.addDays(c.today, -45) }) {
                out.append(HBInsight(id: "goal-quiet-\(g.id)-\(c.month)", kind: .goal, tone: .neutral, title: "\(who) could use a little love",
                    note: "\(whole(togo)) to go. Even \(whole(25)) would get it moving again.",
                    trace: trace("no deposits in 45 days on a goal that has savings", [("To go", fmt(togo)), ("Saved so far", fmt(g.saved))], u: 0.12, m: 0.15, t: 0.3)))
            }
        }
        return out
    }

    // MARK: Together (shared information only)

    /// Everything here reads ONLY: entries that are shared and not private, shared bills, and debt payments. Never an unshared or private entry.
    static func together(_ c: HBInsightContext, _ k: Cal) -> [HBInsight] {
        guard c.snapshot.members.count > 1, k.isCurrent else { return [] }
        var out: [HBInsight] = []
        let sharedNow = sum(c.entries.filter { !$0.isIncome && $0.shared == 1 && $0.isPrivate == 0 && $0.recurring_id == nil && (Int($0.date.suffix(2)) ?? 99) <= k.day })
        if k.day >= 7, let p = c.prev {
            let before = p.everyday(through: k.day, sharedOnly: true)
            if before >= 60 {
                let diff = sharedNow - before
                if abs(diff) >= Swift.max(30, 0.15 * before) {
                    let facts: [(String, String)] = [("Shared spending so far", fmt(sharedNow)), ("Same point last month", fmt(before))]
                    if diff < 0 {
                        out.append(HBInsight(id: "tog-less-\(c.month)", kind: .together, tone: .positive, title: "Household spending is on a good track",
                            note: "Shared spending is \(whole(-diff)) lower than at this point last month.", trace: trace("shared spending below the same point last month", facts, u: 0.1, m: -diff / 250, t: 0.4)))
                    } else {
                        out.append(HBInsight(id: "tog-more-\(c.month)", kind: .together, tone: .watch, title: "Shared spending is running higher",
                            note: "Shared spending is \(whole(diff)) higher than at this point last month.", trace: trace("shared spending above the same point last month", facts, u: diff / 300, m: diff / 250, t: 0.4)))
                    }
                }
            }
        }
        // shared bills still to come before the next payday
        if let b = HBPlan.beforePayday(c.snapshot, today: c.today), let pd = b.payday {
            let logged = Set(c.snapshot.logged.map { $0.recurring_id + "|" + $0.occ_date })
            var n = 0; var total = 0.0
            for r in c.snapshot.recurring where !r.isIncome && r.shared == 1 {
                for d in HBRecur.occurrences(r, from: c.today, to: HBDay.addDays(pd, -1)) where !logged.contains(r.id + "|" + HBDay.string(d)) { n += 1; total += r.amount }
            }
            if n >= 2 {
                out.append(HBInsight(id: "tog-bills-\(HBDay.string(pd))", kind: .together, tone: .neutral, title: "\(n) shared bills before payday",
                    note: "\(whole(total)) of shared bills are due before \(HBDay.dayName(pd))'s payday.", trace: trace("two or more shared bills before the next payday", [("Shared bills", "\(n)"), ("Total", fmt(total)), ("Next payday", HBDay.string(pd))], u: 0.25, m: total / 500, t: 0.5)))
            }
        }
        // debt paid together this month (only when the whole month's list is there: the server lists the latest 10)
        let pays = c.snapshot.debt_payments ?? []
        if pays.count < 10 {
            let mine = pays.filter { $0.date.hasPrefix(c.month) }
            let total = mine.reduce(0) { $0 + $1.amount }
            if total >= 50, Set(mine.map { $0.member_id }).count >= 2 {
                out.append(HBInsight(id: "tog-debt-\(c.month)", kind: .together, tone: .positive, title: "Paying down debt together",
                    note: "Together you've paid \(whole(total)) toward debt this month.", trace: trace("two or more members paid toward debt this month", [("Paid this month", fmt(total)), ("People who paid", "\(Set(mine.map { $0.member_id }).count)")], u: 0.1, m: total / 600, t: 0.4)))
            }
        }
        return out
    }

    // MARK: low-data nudges

    static func onboarding(_ c: HBInsightContext, _ k: Cal) -> [HBInsight] {
        guard k.isCurrent else { return [] }
        let exp = c.entries.filter { !$0.isIncome }
        if c.entries.isEmpty {
            return [HBInsight(id: "onboard-first-\(c.month)", kind: .onboarding, tone: .neutral, title: "Bun learns your month as you log it",
                note: "Add an expense or some income and your safe-to-spend, forecast and pace notes start to fill in.",
                trace: trace("nothing logged this month", [("Entries", "0")], u: 0.2, m: 0.2, t: 0.3))]
        }
        if (c.snapshot.budgets ?? []).isEmpty, exp.count >= 10, let top = HBPlan.spentByCategory(c.entries).max(by: { $0.value != $1.value ? $0.value < $1.value : $0.key > $1.key }) {
            return [HBInsight(id: "onboard-budget-\(c.month)", kind: .onboarding, tone: .neutral, title: "Set a budget for \(name(top.key).lowercased())",
                note: "You've spent \(whole(top.value)) on it so far. With a monthly limit, Bun can tell you when it's running ahead.",
                trace: trace("no budgets set and enough spending to suggest one", [("Biggest category", name(top.key)), ("Spent", fmt(top.value)), ("Expenses logged", "\(exp.count)")], u: 0.2, m: 0.2, t: 0.3))]
        }
        return []
    }
}
