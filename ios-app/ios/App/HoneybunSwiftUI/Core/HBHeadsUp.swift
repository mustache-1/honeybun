import Foundation

// "Heads up from Bun" on Home: the same rules, thresholds and wording as the website's renderBunExtras() in app.js —
// budget rows at 80% or more (top two), recent subscription price changes (top two, dismissable), the month-end forecast line,
// and the "Bun is a little sleepy" nudge after three quiet days. Pure functions of the /api/nest snapshot.
struct HBHeadsUpRow: Identifiable, Equatable {
    enum Kind: Equatable { case budget(category: String, ratio: Double), priceUp, priceDown, forecast(short: Bool) }
    let id: String
    let kind: Kind
    let title: String
    let note: String
    /// price rows carry the key that dismissing stores ("id|amount_cents")
    var dismissKey: String? = nil
}
struct HBHeadsUp: Equatable {
    var sleepyDays: Int? = nil          // days since the last logged thing (3 or more), current month only
    var rows: [HBHeadsUpRow] = []
    var isEmpty: Bool { sleepyDays == nil && rows.isEmpty }
}

enum HBHeadsUpRules {
    /// where the dismissed price changes are remembered (the website's "hb-price-seen")
    static let seenKey = "hb-price-seen"

    static func whole(_ v: Double) -> String {
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = "USD"; f.currencySymbol = "$"
        f.minimumFractionDigits = 0; f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v.rounded())) ?? "$\(Int(v.rounded()))"
    }
    static func money(_ v: Double) -> String {
        let f = NumberFormatter(); f.numberStyle = .currency; f.currencyCode = "USD"; f.currencySymbol = "$"
        f.minimumFractionDigits = 2; f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: v)) ?? "$\(v)"
    }
    /// the website's fmt(): whole dollars when there are no cents, otherwise two decimals
    static func fmt(_ v: Double) -> String { abs(v - v.rounded()) < 0.005 ? whole(v) : money(v) }

    static func seen(_ defaults: UserDefaults = .standard) -> [String] { defaults.stringArray(forKey: seenKey) ?? [] }
    static func dismiss(_ key: String, _ defaults: UserDefaults = .standard) {
        var list = seen(defaults)
        if !list.contains(key) { list.append(key) }
        defaults.set(Array(list.suffix(40)), forKey: seenKey)
    }

    /// `me` is the signed-in member (for the quiet-day nudge); `forecastEndLeft` is nil until there is enough data (or for other months)
    static func compute(_ s: HBNestSnapshot, month: String, me: HBMember?, today: Date = HBDay.startOfToday(), seen: [String], forecast: HBForecastResult) -> HBHeadsUp {
        var out = HBHeadsUp()
        let isCurrent = month == HBDay.monthKey(today)

        // quiet days: at least three days since the last thing logged
        if isCurrent, let last = me?.last_day, let d = HBDay.parse(last) {
            let gap = HBDay.cal.dateComponents([.day], from: d, to: today).day ?? 0
            if gap >= 3 { out.sleepyDays = gap }
        }

        // budgets at 80% or more (limits without roll-over, like the website), most-used first, top two
        let spentBy = HBPlan.spentByCategory(s.entries)
        let dim = HBDay.cal.range(of: .day, in: .month, for: HBDay.parse(month + "-01") ?? today)?.count ?? 30
        let daysLeft = isCurrent ? dim - HBDay.cal.component(.day, from: today) + 1 : 0
        var budgetRows: [(ratio: Double, row: HBHeadsUpRow)] = []
        for b in s.budgets ?? [] where b.limit_cents > 0 {
            let lim = Double(b.limit_cents) / 100.0, sp = spentBy[b.category] ?? 0
            guard sp >= lim * 0.8 else { continue }
            let pct = Int((sp / lim * 100).rounded())
            let name = HBCatStyle.of(b.category).label
            let title = sp > lim ? "\(name): over budget" : "\(pct)% of your budget used"
            var note = sp > lim ? "\(whole(sp - lim)) over · \(whole(sp)) of \(whole(lim))" : "\(whole(sp)) of \(whole(lim))"
            if sp <= lim && daysLeft > 1 { note += " · \(fmt((lim - sp) / Double(daysLeft))) a day left" }
            budgetRows.append((sp / lim, HBHeadsUpRow(id: "budget-" + b.category, kind: .budget(category: b.category, ratio: sp / lim), title: title, note: note)))
        }
        out.rows += budgetRows.sorted { $0.ratio > $1.ratio }.prefix(2).map { $0.row }

        // price changes in the last 30 days that weren't dismissed yet, first two
        var prices: [HBHeadsUpRow] = []
        for r in s.recurring where r.type == "expense" {
            guard let prev = r.prev_amount_cents, prev > 0, let at = r.price_changed_at, let changed = HBDay.parse(at) else { continue }
            let key = "\(r.id)|\(r.amount_cents)"
            if seen.contains(key) { continue }
            let days = HBDay.cal.dateComponents([.day], from: changed, to: today).day ?? 999
            guard days <= 30 else { continue }
            let up = r.amount_cents > prev
            prices.append(HBHeadsUpRow(id: "price-" + key, kind: up ? .priceUp : .priceDown,
                                       title: up ? "\(r.label) is now \(money(r.amount))" : "\(r.label) dropped to \(money(r.amount))",
                                       note: "It was \(money(Double(prev) / 100.0))", dismissKey: key))
        }
        out.rows += prices.prefix(2)

        // the forecast line (this month, once there is enough to go on)
        if case let .ready(f) = forecast {
            let short = f.endLeft < 0
            out.rows.append(HBHeadsUpRow(id: "forecast", kind: .forecast(short: short),
                                         title: short ? "On pace to run \(whole(-f.endLeft)) short" : "On pace to end with about \(whole(f.endLeft))",
                                         note: "See the month-end forecast"))
        }
        return out
    }
}

/// The "Please confirm your email" reminder on Home (the website's #verifyBanner): only for an account that has an email and has not confirmed it,
/// and not while it was dismissed (✕ hides it for three days, remembered like the website's "hb-verify-hide").
enum HBVerifyRules {
    static let hideKey = "hb-verify-hide"
    static let hideSeconds: TimeInterval = 3 * 86400
    static func shouldShow(_ user: HBUser?, defaults: UserDefaults = .standard, now: Date = Date()) -> Bool {
        guard let u = user, u.verified == false, u.has_email != false else { return false }
        return defaults.double(forKey: hideKey) <= now.timeIntervalSince1970
    }
    static func hide(defaults: UserDefaults = .standard, now: Date = Date()) { defaults.set(now.timeIntervalSince1970 + hideSeconds, forKey: hideKey) }
}
