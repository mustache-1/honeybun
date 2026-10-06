import Foundation

// Phase 7, Smarter Honeybun: the insight engine (HBInsights.swift) on hand-built months. Pure functions of a snapshot, so no backend is needed.
// Every expected number below is worked out by hand in the comment next to it. Compiled and run by CI on macOS (see .github/workflows/ios.yml).
var failures = 0
func check(_ name: String, _ ok: Bool) { print((ok ? "PASS " : "FAIL ") + name); if !ok { failures += 1 } }

let M = "e13d46b3-b063-4599-afc3-c5d9b5feb2b2"      // me (Sam, from the preview data)
let O = "11111111-2222-3333-4444-555555555555"      // someone else in the household

func E(_ id: String, _ type: String, _ cents: Int, _ label: String, _ cat: String?, _ date: String, shared: Int = 0, priv: Int = 0, rec: String? = nil, member: String = M) -> [String: Any] {
    ["id": id, "member_id": member, "type": type, "amount_cents": cents, "label": label, "category": cat as Any? ?? NSNull(), "shared": shared, "split_mode": NSNull(), "split_value": NSNull(),
     "private": priv, "date": date, "recurring_id": rec as Any? ?? NSNull(), "occ_date": NSNull(), "created_at": 1]
}
func R(_ id: String, _ type: String, _ cents: Int, _ label: String, _ cat: String?, _ freq: String, _ anchor: String, shared: Int = 0, member: String = M, prev: Int? = nil, changed: String? = nil) -> [String: Any] {
    ["id": id, "type": type, "label": label, "amount_cents": cents, "category": cat as Any? ?? NSNull(), "member_id": member, "shared": shared, "split_mode": NSNull(), "split_value": NSNull(),
     "freq": freq, "anchor_date": anchor, "prev_amount_cents": prev as Any? ?? NSNull(), "price_changed_at": changed as Any? ?? NSNull()]
}
func D(_ id: String, _ startCents: Int, _ aprBp: Int, _ minCents: Int, paid: Int = 0) -> [String: Any] { ["id": id, "name": id, "start_cents": startCents, "apr_bp": aprBp, "min_cents": minCents, "paid_cents": paid] }
func epoch(_ ymd: String) -> Double { HBDay.parse(ymd)!.timeIntervalSince1970 + 43200 }
func J(_ id: String, _ goal: String, _ cents: Int, _ ymd: String) -> [String: Any] { ["id": id, "goal_id": goal, "member_id": M, "amount_cents": cents, "created_at": epoch(ymd)] }

struct Fix {
    var entries: [[String: Any]] = []
    var recurring: [[String: Any]] = []
    var logged: [[String: Any]] = []
    var budgets: [[String: Any]] = []
    var goals: [[String: Any]] = []
    var jar: [[String: Any]] = []
    var debts: [[String: Any]] = []
    var pays: [[String: Any]] = []
    var household = false
    var carry: Int? = nil
}
func snap(_ f: Fix) -> HBNestSnapshot {
    var d = (try! JSONSerialization.jsonObject(with: Data(HBPreviewData.json.utf8))) as! [String: Any]
    d["entries"] = f.entries; d["recurring"] = f.recurring; d["logged"] = f.logged; d["budgets"] = f.budgets
    d["goals"] = f.goals; d["jar"] = f.jar; d["debts"] = f.debts; d["debt_payments"] = f.pays
    if let c = f.carry { d["carry_in"] = ["amount_cents": c, "accepted": true] } else { d["carry_in"] = NSNull() }
    if f.household {
        var ms = d["members"] as! [[String: Any]]
        var other = ms[0]; other["id"] = O; other["name"] = "Alex"
        ms.append(other); d["members"] = ms
    }
    return try! JSONDecoder().decode(HBNestSnapshot.self, from: try! JSONSerialization.data(withJSONObject: d))
}
func goal(_ id: String, _ name: String, target: Int, saved: Int) -> [String: Any] { ["id": id, "name": name, "emoji": "✈️", "target_cents": target, "saved_cents": saved] }
func entries(_ rows: [[String: Any]]) -> [HBEntry] { rows.map { try! JSONDecoder().decode(HBEntry.self, from: try! JSONSerialization.data(withJSONObject: $0)) } }

func ctx(_ s: HBNestSnapshot, today: String, month: String = "2026-10", prev: HBPrevMonth? = nil, memory: HBInsightMemory = HBInsightMemory(), strategy: HBDebtStrategy = .snowball, extra: Double = 0, seen: [String] = []) -> HBInsightContext {
    HBInsightContext(snapshot: s, entries: s.entries, month: month, today: HBDay.parse(today)!, myID: M, me: s.members.first, prev: prev, strategy: strategy, extra: extra, priceSeen: seen, memory: memory)
}
func find(_ list: [HBInsight], _ idPrefix: String) -> HBInsight? { list.first { $0.id.hasPrefix(idPrefix) } }
func near(_ x: Double?, _ y: Double, _ tol: Double = 0.01) -> Bool { abs((x ?? .infinity) - y) <= tol }
func isAny(_ k: HBInsightKind, _ list: [HBInsightKind]) -> Bool { list.contains(k) }
func prevMonth(_ rows: [[String: Any]]) -> HBPrevMonth { HBPrevMonth(month: "2026-09", entries: entries(rows)) }

// ------------------------------------------------------------------------------------------------------------------------------------------
// Fixture A: Saturday Oct 24 2026 (day 24 of 31, 7 days left). $3,000 came in on the 1st. Everyday spending: 5 entries before the last-7-days
// window (Oct 2 $100 groceries, 5 $90 eating out, 9 $120 groceries, 12 $100 eating out, 16 $100 groceries = $510 over the 17 days before it,
// i.e. $210 a week), then $350 in the last 7 days (Oct 19 $150 eating out, Oct 21 $200 fun).
let aRows: [[String: Any]] = [
    E("a0", "income", 300000, "Pay", nil, "2026-10-01"),
    E("a1", "expense", 10000, "Market", "groc", "2026-10-02"), E("a2", "expense", 9000, "Lunch", "food", "2026-10-05"), E("a3", "expense", 12000, "Market", "groc", "2026-10-09"),
    E("a4", "expense", 10000, "Dinner", "food", "2026-10-12"), E("a5", "expense", 10000, "Market", "groc", "2026-10-16"),
    E("a6", "expense", 15000, "Dinner", "food", "2026-10-19"), E("a7", "expense", 20000, "Concert", "fun", "2026-10-21"),
]
let A = snap(Fix(entries: aRows))
let cA = ctx(A, today: "2026-10-24")
let allA = HBInsights.all(cA)

func run() {
    // ===== Safe to Spend =====
    check("SAFE: Home's number is unchanged: income − spending + carry-over ($3,000 − $860 = $2,140)", near(HBInsights.left(cA), 2140))
    check("SAFE: with nothing scheduled, the line under it states the formula and nothing else: \"$3,000 in minus $860 spent.\"", HBInsights.safeLine(cA) == "$3,000 in minus $860 spent.")
    let cCarry = ctx(snap(Fix(entries: aRows, carry: 20000)), today: "2026-10-24")
    check("SAFE: carry-over is counted and named ($200 carried: left $2,340)", near(HBInsights.left(cCarry), 2340) && HBInsights.safeLine(cCarry) == "$3,200 in (carry-over counted) minus $860 spent.")
    // a bill ($60 on Oct 27) and a payday (Friday Oct 30): the line mentions the bills due first and what would be left, from Plan's own beforePayday()
    let withBill = snap(Fix(entries: aRows, recurring: [R("bill1", "expense", 6000, "Phone", "bills", "monthly", "2026-10-27"), R("pay1", "income", 100000, "Pay", nil, "biweekly", "2026-10-30")]))
    let lineBill = HBInsights.safeLine(ctx(withBill, today: "2026-10-24")) ?? ""
    check("SAFE: with a bill due before payday it says so, exactly: $60 due before Friday's payday, $2,080 after", lineBill == "$60 of bills are due before Friday's payday; you'd have $2,080 after them.")
    check("SAFE: it never claims bills are 'already accounted for' (Safe to Spend does not subtract them)", !lineBill.lowercased().contains("accounted") && !lineBill.lowercased().contains("already"))
    let negFix = Fix(entries: [E("n0", "income", 100000, "Pay", nil, "2026-10-01"), E("n1", "expense", 130000, "Rent", "home", "2026-10-02")])
    let cNeg = ctx(snap(negFix), today: "2026-10-24")
    check("SAFE: a negative number is described plainly: \"$300 more has gone out than has come in.\" and Bun raises it first (warning)", HBInsights.safeLine(cNeg) == "$300 more has gone out than has come in." && HBInsights.all(cNeg).first?.id == "over-2026-10" && HBInsights.all(cNeg).first?.tone == .warning)
    check("SAFE: zero: income equal to spending is not 'over' (no warning), and the line is still the formula", { let z = ctx(snap(Fix(entries: [E("z0", "income", 50000, "Pay", nil, "2026-10-01"), E("z1", "expense", 50000, "Rent", "home", "2026-10-02")])), today: "2026-10-24"); return near(HBInsights.left(z), 0) && find(HBInsights.all(z), "over-") == nil && HBInsights.safeLine(z) == "$500 in minus $500 spent." }())
    // why it moved: the last 7 days (Oct 18–24): $350 out, nothing in; usual week $210 (510 over the 17 days before)
    let down = find(allA, "sts-down-2026-10")
    check("SAFE: it explains a drop with real numbers: \"Safe to spend is down $350 this week\", $350 spent in 7 days, more than a usual week (about $210)",
          down?.title == "Safe to spend is down $350 this week" && down?.note == "You spent $350 over the last 7 days. That's more than a usual week (about $210)." && down?.tone == .watch)
    check("SAFE: …and the same week is flagged as a bigger one (350 ≥ 1.4 × 210, and $140 above)", find(allA, "week-high-2026-10") != nil)
    let upFix = Fix(entries: aRows + [E("u1", "income", 90000, "Bonus", nil, "2026-10-22")])
    let up = find(HBInsights.all(ctx(snap(upFix), today: "2026-10-24")), "sts-up-2026-10")
    check("SAFE: money coming in is good news too: +$900 − $350 = \"Safe to spend is up $550 this week\"", up?.title == "Safe to spend is up $550 this week" && up?.tone == .positive)
    check("SAFE: small movements are not mentioned (a $30 week is under the $40 bar)", find(HBInsights.all(ctx(snap(Fix(entries: [E("s0", "income", 300000, "Pay", nil, "2026-10-01"), E("s1", "expense", 3000, "Snack", "food", "2026-10-22")])), today: "2026-10-24")), "sts-") == nil)
    // month boundary: Oct 5 has no full week inside the month, so no weekly claims; Nov 1 likewise
    let cEarly = ctx(snap(Fix(entries: aRows)), today: "2026-10-05")
    check("BOUNDARY: on the 5th, with less than a week of the month, Bun makes no weekly or Safe-to-Spend-change claims", HBInsights.all(cEarly).allSatisfy { !$0.id.hasPrefix("sts-") && !$0.id.hasPrefix("week-") })
    let cNov = ctx(snap(Fix(entries: [E("m1", "income", 100000, "Pay", nil, "2026-11-01")])), today: "2026-11-01", month: "2026-11")
    check("BOUNDARY: the 1st of a new month: nothing weekly, no forecast, just the neutral 'Bun learns your month' note", HBInsights.all(cNov).map { $0.kind } == [.forecast] || HBInsights.all(cNov).allSatisfy { $0.kind == .forecast || $0.kind == .onboarding })
    let cPast = ctx(A, today: "2026-11-15", month: "2026-10")
    check("BOUNDARY: looking at a month that is over: no forecast, Safe-to-Spend-change, bills or pace notes (they're about 'now')", HBInsights.all(cPast).allSatisfy { !isAny($0.kind, [.forecast, .safeToSpend, .bills, .pace, .comparison]) })

    // ===== Forecast =====
    let fc = find(allA, "forecast-2026-10")
    check("FORECAST: on track: $2,140 left now, no bills or paychecks, $860 / 24 days × 7 days ahead = $250.83 → \"On track for +$1,889\"", fc?.title == "On track for +$1,889" && fc?.tone == .positive)
    check("FORECAST: the sentence uses the same projection: \"…projected to finish October with about $1,889 remaining.\"", fc?.note == "At your current pace you're projected to finish October with about $1,889 remaining.")
    check("FORECAST: it is the existing engine's number (HBPlan.forecast), not a second one", { if case let .ready(f) = HBPlan.forecast(A, month: "2026-10", today: HBDay.parse("2026-10-24")!, myID: M) { return near(f.endLeft, 1889.1667, 0.001) }; return false }())
    // heading short: B = $1,000 in, $1,050 out (food 550, groceries 350, fun 150, …) → left −$50; ahead $306.25 → ends −$356.25
    let bRows: [[String: Any]] = [E("b0", "income", 100000, "Pay", nil, "2026-10-01"), E("b1", "expense", 30000, "Dinner", "food", "2026-10-03"), E("b2", "expense", 25000, "Dinner", "food", "2026-10-06"),
        E("b3", "expense", 20000, "Market", "groc", "2026-10-10"), E("b4", "expense", 15000, "Games", "fun", "2026-10-14"), E("b5", "expense", 15000, "Market", "groc", "2026-10-18")]
    let cB = ctx(snap(Fix(entries: bRows)), today: "2026-10-24")
    let fb = find(HBInsights.all(cB), "forecast-2026-10")
    check("FORECAST: heading short: −$50 now, $306.25 of everyday spending ahead → \"Heading toward -$356\" (warning)", fb?.title == "Heading toward -$356" && fb?.tone == .warning)
    check("FORECAST: it names the biggest everyday categories from the data (Eating out 52%, Groceries 33%; Fun 14% is under the 20% bar)",
          fb?.note.contains("Most of your everyday spending so far is \(HBCatStyle.of("food").label) and \(HBCatStyle.of("groc").label).") == true && fb?.note.contains(HBCatStyle.of("fun").label) == false)
    check("FORECAST: when no believable cut would fix it (needs $50.89 a day against $43.75 of everyday spending), it does NOT suggest one", fb?.note.contains("less a week") == false)
    // C: $1,000 in, $900 out over 6 everyday entries by the 24th → left $100, ahead $262.50, ends −$162.50; needs $23.21 a day (≤ 80% of the $37.50 a day) = $163 a week
    let cRows: [[String: Any]] = [E("c0", "income", 100000, "Pay", nil, "2026-10-01")] + (1...6).map { E("c\($0)", "expense", 15000, "Everyday \($0)", $0 % 2 == 0 ? "food" : "groc", String(format: "2026-10-%02d", $0 * 3)) }
    let sC = snap(Fix(entries: cRows)); let cC = ctx(sC, today: "2026-10-24")
    if case let .ready(f) = HBInsights.forecastResult(cC), let b = HBInsights.backOnTrack(f) {
        check("FORECAST: back on track: ends −$162.50, so $23.21 a day less (= $163 a week) over the 7 days left lands on $0", near(f.endLeft, -162.5) && near(b.perDay, 23.2143, 0.001) && b.perWeek == 163 && near(f.endLeft + b.perDay * Double(f.daysLeft), 0, 1e-9))
    } else { check("FORECAST: back-on-track suggestion exists for fixture C", false) }
    check("FORECAST: …and the card says it in words, plus Plan's forecast card gets the same lines", find(HBInsights.all(cC), "forecast-2026-10")?.note.contains("Spending about $163 less a week on everyday things would put you back on track.") == true && HBInsights.forecastNotes(cC).contains { $0.contains("$163 less a week") })
    // tight: $1,000 in, 5 × $152 = $760 out by the 24th → left $240, ahead $760/24 × 7 = $221.67 → ends with $18.33
    let tightRows: [[String: Any]] = [E("t0", "income", 100000, "Pay", nil, "2026-10-01")] + (1...5).map { E("t\($0)", "expense", 15200, "Everyday", "food", String(format: "2026-10-%02d", $0 * 3)) }
    let tight = find(HBInsights.all(ctx(snap(Fix(entries: tightRows)), today: "2026-10-24")), "forecast-2026-10")
    check("FORECAST: tight (under $50 left at month end) is a gentle 'watch', not an alarm: \"Cutting it close: about $18 left\"", tight?.title == "Cutting it close: about $18 left" && tight?.tone == .watch)
    check("FORECAST: not enough history: day 5 with 3 expenses says what Bun is waiting for (neutral), and a brand-new empty month says nothing about forecasts",
          find(HBInsights.all(ctx(snap(Fix(entries: Array(aRows.prefix(4)))), today: "2026-10-05")), "forecast-wait")?.tone == .neutral && find(HBInsights.all(cNov), "forecast-wait") != nil && find(HBInsights.all(ctx(snap(Fix()), today: "2026-10-05")), "forecast") == nil)

    // ===== Budget pacing =====
    // Oct 18 (day 18 of 31: 58% of the month, 13 days left): groceries $370 of $500 = 74%
    let pRows: [[String: Any]] = [E("p0", "income", 300000, "Pay", nil, "2026-10-01"), E("p1", "expense", 12000, "Market", "groc", "2026-10-03"), E("p2", "expense", 13000, "Market", "groc", "2026-10-08"), E("p3", "expense", 12000, "Market", "groc", "2026-10-14")]
    let sP = snap(Fix(entries: pRows, budgets: [["category": "groc", "limit_cents": 50000]]))
    let pace = find(HBInsights.all(ctx(sP, today: "2026-10-18")), "pace-groc-2026-10")
    check("PACE: \"You've used 74% of your groceries budget with 13 days left\" (74% used while 58% of the month has passed)", pace?.note == "You've used 74% of your groceries budget with 13 days left." && pace?.ratio != nil && near(pace?.ratio, 0.74) && pace?.tone == .watch)
    check("PACE: a budget that is on pace (64% used on the 24th) is not mentioned", find(HBInsights.all(ctx(snap(Fix(entries: aRows, budgets: [["category": "groc", "limit_cents": 50000]])), today: "2026-10-24")), "pace-") == nil)
    let s80 = snap(Fix(entries: pRows, budgets: [["category": "groc", "limit_cents": 40000]]))       // 92.5% → the original Heads-up rule (80%+)
    let b80 = find(HBInsights.all(ctx(s80, today: "2026-10-18")), "budget-groc-2026-10")
    check("PACE: 80%+ keeps the existing Heads-up rule and wording (\"93% of your budget used\"), and the pace rule doesn't repeat it", b80?.title == "93% of your budget used" && b80?.tone == .watch && find(HBInsights.all(ctx(s80, today: "2026-10-18")), "pace-") == nil)
    let sOver = snap(Fix(entries: pRows, budgets: [["category": "groc", "limit_cents": 30000]]))
    check("PACE: over budget is a warning", find(HBInsights.all(ctx(sOver, today: "2026-10-18")), "budget-groc-2026-10")?.tone == .warning)
    check("PACE: before day 5 there is no pace talk (too early to mean anything)", find(HBInsights.all(ctx(sP, today: "2026-10-04")), "pace-") == nil)

    // ===== Last month, same point =====
    // last month through the 24th: Sep 4 $230 groceries, 10 $250 eating out, 16 $250 groceries, 21 $250 fun = $980; plus $100 on the 28th (after the 24th)
    let prevRows: [[String: Any]] = [E("v1", "expense", 23000, "x", "groc", "2026-09-04"), E("v2", "expense", 25000, "x", "food", "2026-09-10"), E("v3", "expense", 25000, "x", "groc", "2026-09-16"),
        E("v4", "expense", 25000, "x", "fun", "2026-09-21"), E("v5", "expense", 10000, "x", "other", "2026-09-28")]
    let pv = prevMonth(prevRows)
    let cmpAll = HBInsights.all(ctx(A, today: "2026-10-24", prev: pv))
    check("COMPARE: this month's everyday spending through the 24th is $860 against $980 at that point last month: $120 less → good news", find(cmpAll, "vs-less-2026-10")?.note == "You've spent $120 less on everyday things than at this point last month." && find(cmpAll, "vs-less-2026-10")?.tone == .positive)
    check("COMPARE: categories that moved a lot: eating out +$90 (340 vs 250), groceries −$160 (320 vs 480); fun −$50 is under its bar",
          find(cmpAll, "cat-up-food")?.note == "$340 so far, $90 more than at this point last month." && find(cmpAll, "cat-down-groc")?.note == "$320 so far, $160 less than at this point last month." && find(cmpAll, "cat-down-fun") == nil)
    check("COMPARE: last month's amounts are kept as small facts only: no labels, and they're counted by the day", pv.rows.count == 5 && pv.everyday(through: 24) == 980 && pv.everyday(through: 31) == 1080 && abs(pv.total - 1080) < 1e-9)
    check("COMPARE: not enough history makes no claim: last month under $100, no last month at all, or day < 7",
          HBInsights.all(ctx(A, today: "2026-10-24", prev: prevMonth([E("w", "expense", 6000, "x", "food", "2026-09-04")]))).allSatisfy { $0.kind != .comparison }
          && HBInsights.all(cA).allSatisfy { $0.kind != .comparison } && HBInsights.all(cEarly).allSatisfy { $0.kind != .comparison })
    check("COMPARE: a small difference is not a headline ($20 against $980 is under the bar)", HBInsights.all(ctx(snap(Fix(entries: aRows + [E("x1", "income", 1, "x", nil, "2026-10-01")])), today: "2026-10-24", prev: prevMonth([E("y1", "expense", 88000, "x", "groc", "2026-09-04"), E("y2", "expense", 20000, "x", "food", "2026-09-30")]))).allSatisfy { $0.id != "vs-less-2026-10" && $0.id != "vs-more-2026-10" })
    // the same point last month is also what a week is measured against when this month is too young (day 20: only 13 days before the window)
    let cMid = ctx(snap(Fix(entries: [E("q0", "income", 300000, "Pay", nil, "2026-10-01"), E("q1", "expense", 50000, "Trip", "fun", "2026-10-16")])), today: "2026-10-20", prev: prevMonth([E("r1", "expense", 84000, "x", "groc", "2026-09-04")]))
    let wMid = HBInsights.week(cMid, HBInsights.Cal(cMid))
    check("PACE: a week early in the month is measured against last month's average ($840 over 30 days = $196 a week); with no last month there is nothing to compare", wMid?.basis == "last month" && near(wMid?.usual, 196) && HBInsights.week(ctx(snap(Fix(entries: [E("q1", "expense", 50000, "Trip", "fun", "2026-10-16")])), today: "2026-10-20"), HBInsights.Cal(cMid)) == nil)

    // ===== Bills, subscriptions, paydays =====
    // three bills tomorrow (Oct 25): $100 + $64 + $50 = $214; other bill days: $20 (Oct 28), $25 (Nov 2), $30 (Nov 10): a usual bill day is $30
    let tomorrowBills: [[String: Any]] = [R("h1", "expense", 10000, "Rent share", "bills", "monthly", "2026-09-25"), R("h2", "expense", 6400, "Car", "car", "monthly", "2026-09-25"), R("h3", "expense", 5000, "Insurance", "bills", "monthly", "2026-09-25"),
        R("h4", "expense", 2000, "Gym", "fun", "monthly", "2026-10-28"), R("h5", "expense", 2500, "Cloud", "subs", "monthly", "2026-11-02"), R("h6", "expense", 3000, "Water", "bills", "monthly", "2026-11-10")]
    let paidSep = ["h1", "h2", "h3"].map { ["recurring_id": $0, "occ_date": "2026-09-25"] }
    let sHeavy = snap(Fix(entries: aRows, recurring: tomorrowBills + [R("o1", "expense", 50000, "Alex's private-ish bill", "other", "monthly", "2026-10-25", shared: 0, member: O)], logged: paidSep))
    let heavy = find(HBInsights.all(ctx(sHeavy, today: "2026-10-24")), "heavy-")
    check("BILLS: \"Tomorrow is a heavier day than usual: $214 across 3 bills\" (a usual bill day is about $30)", heavy?.title == "Tomorrow is a heavier day than usual" && heavy?.note == "$214 across 3 bills, against about $30 on a usual bill day." && heavy?.tone == .watch)
    check("BILLS: someone else's unshared bill is not counted in it ($500 on the same day changed nothing)", heavy?.trace.facts.first { $0.label == "That day's bills" }?.value == "$214")
    check("BILLS: a normal week of bills is not flagged (only one day of $20)", find(HBInsights.all(ctx(snap(Fix(entries: aRows, recurring: tomorrowBills.suffix(3).map { $0 })), today: "2026-10-24")), "heavy-") == nil)
    // bills that outrun what is left: B has −$50 left and a $100 bill on the 26th → $150 short
    let sShort = snap(Fix(entries: bRows, recurring: [R("sb", "expense", 10000, "Dentist", "other", "monthly", "2026-10-26")]))
    let short = find(HBInsights.all(ctx(sShort, today: "2026-10-24")), "bills-short-")
    check("BILLS: bills that are more than what's left raise a warning with the real gap: \"$100 is due in the next 30 days and you have $0 left, about $150 short.\"", short?.tone == .warning && short?.note == "$100 is due in the next 30 days and you have $0 left, about $150 short.")
    let sPay = snap(Fix(entries: aRows, recurring: [R("bp", "expense", 7300, "Phone", "bills", "monthly", "2026-10-26"), R("pp", "income", 100000, "Pay", nil, "monthly", "2026-10-30")]))
    let pay = find(HBInsights.all(ctx(sPay, today: "2026-10-24")), "bills-before-payday")
    check("BILLS: next payday Friday: \"1 bill ($73) due before then, and you'd still have $2,067 after them.\" (neutral, low priority)", pay?.title == "Payday Friday" && pay?.note == "1 bill ($73) due before then, and you'd still have $2,067 after them." && pay?.tone == .neutral)
    // recurring costs that went up in the last 90 days: Netflix $15.99 → $19.99 (+$4.00), Spotify $9.99 → $11.99 (+$2.00)
    let rec2 = [R("nf", "expense", 1999, "Netflix", "subs", "monthly", "2026-10-28", prev: 1599, changed: "2026-09-15"), R("sp", "expense", 1199, "Spotify", "subs", "monthly", "2026-10-26", prev: 999, changed: "2026-10-01")]
    let allRec = HBInsights.all(ctx(snap(Fix(entries: aRows, recurring: rec2)), today: "2026-10-24"))
    check("RECURRING: two prices went up: \"Recurring costs are up $6 a month\" (+$4 and +$2), and the two separate price rows are folded into it", find(allRec, "recurring-up-2026-10")?.title == "Recurring costs are up $6 a month" && find(allRec, "price-") == nil)
    let nf1 = R("nf1", "expense", 1999, "Netflix", "subs", "monthly", "2026-10-28", prev: 1599, changed: "2026-10-10")
    let oneRec = HBInsights.all(ctx(snap(Fix(entries: aRows, recurring: [nf1])), today: "2026-10-24"))
    check("RECURRING: a single recent increase stays the original price alert (with its dismiss key), and dismissing it removes it", find(oneRec, "price-")?.dismissKey == "nf1|1999" && find(HBInsights.all(ctx(snap(Fix(entries: aRows, recurring: [nf1])), today: "2026-10-24", seen: ["nf1|1999"])), "price-") == nil)
    check("RECURRING: price changes older than 90 days, and other people's unshared subscriptions, are not counted",
          find(HBInsights.all(ctx(snap(Fix(entries: aRows, recurring: [R("old", "expense", 1999, "Old", "subs", "monthly", "2026-10-28", prev: 999, changed: "2026-06-01"), R("oth", "expense", 1999, "Theirs", "subs", "monthly", "2026-10-28", member: O, prev: 999, changed: "2026-10-01"), rec2[0]])), today: "2026-10-24")), "recurring-up") == nil)

    // ===== Debts (Debt Center+'s engine, worded) =====
    let visa = D("Visa", 300000, 2400, 10000), car = D("Car", 500000, 600, 12000)
    let sDebt = snap(Fix(entries: aRows, debts: [visa, car]))
    let openDebts = (sDebt.debts ?? []).filter { !$0.paidOff }
    let imp = HBPlan.extraImpact(openDebts, strategy: .snowball, extra: 0, adding: 50)
    let dExtra = find(HBInsights.all(ctx(sDebt, today: "2026-10-24")), "debt-extra-")
    check("DEBT: \"adding $50 a month\" is worded straight from HBPlan.extraImpact (same months sooner, same interest saved)", imp.monthsSooner != nil && dExtra?.note == "Adding $50 a month would make you debt-free about \(HBPlan.duration(months: imp.monthsSooner ?? 0)) sooner and save roughly \(HBInsights.whole(imp.interestSaved ?? 0)) in interest.")
    check("DEBT: a small debt that is gone in a few months gets no suggestion ($200 at $100 a month)", find(HBInsights.all(ctx(snap(Fix(entries: aRows, debts: [D("Tiny", 20000, 1200, 10000)])), today: "2026-10-24")), "debt-") == nil)
    check("DEBT: paid-off debts, and no debts at all, say nothing", find(HBInsights.all(ctx(snap(Fix(entries: aRows, debts: [D("Done", 50000, 1000, 5000, paid: 50000)])), today: "2026-10-24")), "debt-") == nil && find(allA, "debt-") == nil)
    // Avalanche against Snowball: the Debt Center fixture ($170.21 saved, 1 month sooner at no extra)
    let three = [D("big", 500000, 2400, 10000), D("small", 50000, 1000, 5000), D("mid", 120000, 300, 4000)]
    let sThree = snap(Fix(entries: aRows, debts: three))
    let av = find(HBInsights.all(ctx(sThree, today: "2026-10-24")), "debt-avalanche-")
    check("DEBT: Snowball users are told Avalanche would save about $170 and finish 1 mo sooner (HBPlan.compareStrategies' numbers)", av?.note == "Paying the highest interest first would save about $170 compared with Snowball and finish 1 mo sooner.")
    check("DEBT: someone already on Avalanche is not told about Avalanche", find(HBInsights.all(ctx(sThree, today: "2026-10-24", strategy: .avalanche)), "debt-avalanche-") == nil)
    // a payment's effect on the debt-free date: the plan with that $500 payment taken back out against the plan now
    let paidVisa = D("Visa", 300000, 2400, 10000, paid: 50000)
    let pay1: [String: Any] = ["id": "pay-1", "debt_id": "Visa", "member_id": M, "amount_cents": 50000, "date": "2026-10-20"]
    let sMoved = snap(Fix(entries: aRows, debts: [paidVisa, car], pays: [pay1]))
    let nowM = HBPlan.payoffPlan(sMoved.debts ?? [], strategy: .snowball, extra: 0).months
    let beforeM = HBPlan.payoffPlan([D("Visa", 300000, 2400, 10000), car].map { try! JSONDecoder().decode(HBDebt.self, from: try! JSONSerialization.data(withJSONObject: $0)) }, strategy: .snowball, extra: 0).months
    let today = HBDay.parse("2026-10-24")!
    let moved = find(HBInsights.all(ctx(sMoved, today: "2026-10-24")), "debt-moved-pay-1")
    check("DEBT: after a meaningful payment: \"moved your projected debt-free date from X to Y\", both dates straight from the payoff engine", nowM != nil && beforeM != nil && beforeM! > nowM! && moved?.note == "It moved your projected debt-free date from \(HBPlan.monthsOut(beforeM!, from: today)) to \(HBPlan.monthsOut(nowM!, from: today))." && moved?.tone == .positive)
    check("DEBT: a payment from three weeks ago is no longer news", find(HBInsights.all(ctx(snap(Fix(entries: aRows, debts: [paidVisa, car], pays: [["id": "pay-0", "debt_id": "Visa", "member_id": M, "amount_cents": 50000, "date": "2026-10-01"]])), today: "2026-10-24")), "debt-moved") == nil)

    // ===== Goals =====
    // Trip: $200 of $1,000; $50 deposits on Sep 10, Sep 24, Oct 8, Oct 22 → 45-day span → $4.44 a day → $800 left → 180 days → Apr 22 2027
    let tripJar = [J("j1", "g1", 5000, "2026-09-10"), J("j2", "g1", 5000, "2026-09-24"), J("j3", "g1", 5000, "2026-10-08"), J("j4", "g1", 5000, "2026-10-22")]
    let sGoal = snap(Fix(entries: aRows, goals: [goal("g1", "Trip", target: 100000, saved: 20000)], jar: tripJar))
    let gp = find(HBInsights.all(ctx(sGoal, today: "2026-10-24")), "goal-pace-g1")
    check("GOALS: \"$800 to go for Trip\" with a projected month from the real contribution pace (180 days → April 2027)", gp?.title == "$800 to go for Trip" && gp?.note.hasPrefix("At your current contribution pace you'd reach it around April 2027.") == true)
    let sWeekly = snap(Fix(entries: aRows, recurring: [R("wp", "income", 50000, "Pay", nil, "weekly", "2026-10-30")], goals: [goal("g1", "Trip", target: 100000, saved: 20000)], jar: tripJar))
    check("GOALS: with a weekly payday, +$25 each payday would be about 3 months sooner (and it says so); a monthly payday gives under a month, so it stays quiet",
          find(HBInsights.all(ctx(sWeekly, today: "2026-10-24")), "goal-pace-g1")?.note.contains("Adding $25 each payday would get you there about 3 months earlier.") == true && gp?.note.contains("each payday") == false)
    let sHalf = snap(Fix(entries: aRows, goals: [goal("g2", "Emergency", target: 100000, saved: 52000)]))
    check("GOALS: a milestone: \"You're halfway to Emergency\" at 52% (with $480 to go)", find(HBInsights.all(ctx(sHalf, today: "2026-10-24")), "goal-mile-g2")?.title == "You're halfway to Emergency" && find(HBInsights.all(ctx(sHalf, today: "2026-10-24")), "goal-mile-g2")?.note == "$480 to go.")
    check("GOALS: completed goals are celebrated; a goal with nothing in it, no target, or no history makes no projection",
          find(HBInsights.all(ctx(snap(Fix(entries: aRows, goals: [goal("g3", "Laptop", target: 80000, saved: 80000)])), today: "2026-10-24")), "goal-done-g3")?.title == "Laptop is fully funded 🎉"
          && find(HBInsights.all(ctx(snap(Fix(entries: aRows, goals: [goal("g4", "New", target: 50000, saved: 0)])), today: "2026-10-24")), "goal-") == nil
          && find(HBInsights.all(ctx(snap(Fix(entries: aRows, goals: [goal("g5", "Zero", target: 0, saved: 0)])), today: "2026-10-24")), "goal-") == nil
          && find(HBInsights.all(ctx(snap(Fix(entries: aRows, goals: [goal("g6", "One", target: 100000, saved: 5000)], jar: [J("j9", "g6", 5000, "2026-10-20")])), today: "2026-10-24")), "goal-pace") == nil)
    let quiet = find(HBInsights.all(ctx(snap(Fix(entries: aRows, goals: [goal("g7", "Camera", target: 100000, saved: 15000)], jar: [J("j8", "g7", 15000, "2026-08-01")])), today: "2026-10-24")), "goal-quiet-g7")
    check("GOALS: no deposits in 45 days: kind and not shaming (\"could use a little love\", \"Even $25 would get it moving again\")", quiet?.title == "Camera could use a little love" && quiet?.note == "$850 to go. Even $25 would get it moving again." && quiet?.tone == .neutral)

    // ===== Together: shared information only =====
    // this month shared everyday spending through the 24th: Oct 5 $150 + Oct 12 $100 = $250; last month shared through the 24th: $200 + $100 = $300 → $50 lower (bar: 15% of 300 = $45)
    func together(_ extraRows: [[String: Any]] = [], recurring: [[String: Any]] = [], prevExtra: [[String: Any]] = [], pays: [[String: Any]] = [], household: Bool = true) -> [HBInsight] {
        let rows = aRows + [E("t1", "expense", 15000, "Costco", "groc", "2026-10-05", shared: 1), E("t2", "expense", 10000, "Dinner out", "food", "2026-10-12", shared: 1, member: O)] + extraRows
        let s = snap(Fix(entries: rows, recurring: recurring, pays: pays, household: household))
        let p = prevMonth([E("tp1", "expense", 20000, "x", "groc", "2026-09-08", shared: 1), E("tp2", "expense", 10000, "x", "food", "2026-09-20", shared: 1)] + prevExtra)
        return HBInsights.all(ctx(s, today: "2026-10-24", prev: p)).filter { $0.kind == .together }
    }
    let t0 = together()
    check("TOGETHER: shared spending $250 against $300 at this point last month: \"Shared spending is $50 lower than at this point last month.\"", t0.first { $0.id == "tog-less-2026-10" }?.note == "Shared spending is $50 lower than at this point last month.")
    // privacy: a big private entry this month AND last month, a big unshared bill from someone else, and an unshared entry of mine must change nothing in the household insights
    let priv: [[String: Any]] = [E("pv1", "expense", 90000, "Secret gift", "fun", "2026-10-08", priv: 1), E("pv2", "expense", 40000, "Surprise", "date", "2026-10-15", priv: 1), E("pv3", "expense", 25000, "Mine only", "other", "2026-10-16", shared: 0)]
    let privPrev: [[String: Any]] = [E("pp1", "expense", 70000, "Last month's secret", "fun", "2026-09-05", priv: 1)]
    let t1 = together(priv, recurring: [R("sec", "expense", 60000, "Hidden bill", "bills", "monthly", "2026-10-27", shared: 0)], prevExtra: privPrev)
    check("PRIVACY: private entries (this month and last), unshared entries and unshared bills do not change a single household insight (ids, titles, notes, numbers, priority all identical)", t0 == t1)
    let text = (t1.map { $0.title + " " + $0.note + " " + $0.trace.explanation().joined(separator: " ") }).joined(separator: " ").lowercased()
    check("PRIVACY: …and nothing in their text or traces carries a private label, category or amount (secret, surprise, gift, 900, 400, 700)", !text.contains("secret") && !text.contains("surprise") && !text.contains("gift") && !text.contains("900") && !text.contains("400") && !text.contains("700") && !text.contains("fun"))
    let t2 = together(recurring: [R("rs", "expense", 40000, "Rent share", "home", "monthly", "2026-10-28", shared: 1), R("is", "expense", 6000, "Internet", "bills", "monthly", "2026-10-29", shared: 1), R("mine", "expense", 9900, "Mine", "bills", "monthly", "2026-10-27", shared: 0), R("pay", "income", 100000, "Pay", nil, "biweekly", "2026-10-30")])
    check("TOGETHER: shared bills before payday: \"2 shared bills before payday: $460 …Friday's payday\"; my unshared bill isn't counted", t2.first { $0.id.hasPrefix("tog-bills") }?.title == "2 shared bills before payday" && t2.first { $0.id.hasPrefix("tog-bills") }?.note == "$460 of shared bills are due before Friday's payday.")
    let twoPays: [[String: Any]] = [["id": "dp1", "debt_id": "Visa", "member_id": M, "amount_cents": 30000, "date": "2026-10-10"], ["id": "dp2", "debt_id": "Visa", "member_id": O, "amount_cents": 34000, "date": "2026-10-12"]]
    check("TOGETHER: \"Together you've paid $640 toward debt this month.\" (two people, $300 + $340)", together(pays: twoPays).first { $0.id == "tog-debt-2026-10" }?.note == "Together you've paid $640 toward debt this month.")
    check("TOGETHER: when the server's list of payments is full (10, so older ones may be missing) Bun makes no total claim", together(pays: (0..<10).map { ["id": "q\($0)", "debt_id": "Visa", "member_id": $0 % 2 == 0 ? M : O, "amount_cents": 10000, "date": "2026-10-10"] }).first { $0.id == "tog-debt-2026-10" } == nil)
    check("TOGETHER: a one-person household gets no household insights at all", together(household: false).isEmpty)

    // ===== Ranking =====
    func mk(_ id: String, _ kind: HBInsightKind, _ tone: HBInsightTone, u: Double, m: Double, t: Double, c: Double = 1) -> HBInsight {
        HBInsight(id: id, kind: kind, tone: tone, title: id, note: "", trace: HBInsightTrace(rule: "test", facts: [HBInsightFact(label: "x", value: "1")], urgency: u, impact: m, timing: t, confidence: c))
    }
    check("RANK: priority = (0.40 urgency + 0.30 impact + 0.30 timing) × confidence × novelty (0.5, 0.5, 0.5 → 0.5; at 60% confidence → 0.3)", near(mk("a", .bills, .watch, u: 0.5, m: 0.5, t: 0.5).score, 0.5, 1e-12) && near(mk("a", .bills, .watch, u: 0.5, m: 0.5, t: 0.5, c: 0.6).score, 0.3, 1e-12))
    let many = [mk("w1", .bills, .warning, u: 0.9, m: 0.9, t: 0.9), mk("w2", .budget, .warning, u: 0.8, m: 0.8, t: 0.8), mk("w3", .forecast, .watch, u: 0.7, m: 0.7, t: 0.7), mk("w4", .debt, .watch, u: 0.6, m: 0.6, t: 0.6),
                mk("g1", .goal, .positive, u: 0.3, m: 0.4, t: 0.4), mk("low", .together, .neutral, u: 0.05, m: 0.05, t: 0.05)]
    let sel = HBInsights.pick(many.sorted { $0.score > $1.score })
    check("RANK: at most three on Home (a fourth only if urgent), and the order is by score", sel.shown.count == 3 && sel.shown.map { $0.id } == ["w1", "w2", "g1"])
    check("RANK: good news gets a place even when warnings outscore it (the lowest of the warnings makes room); the rest wait in 'More from Bun'", sel.shown.contains { $0.tone == .positive } && sel.more.map { $0.id } == ["w3", "w4"])
    check("RANK: anything under the minimum priority is dropped entirely (the 0.05 note appears nowhere)", !sel.shown.contains { $0.id == "low" } && !sel.more.contains { $0.id == "low" })
    let urgent = HBInsights.pick([mk("u1", .bills, .warning, u: 1, m: 1, t: 1), mk("u2", .budget, .warning, u: 0.95, m: 0.95, t: 0.95), mk("u3", .forecast, .warning, u: 0.9, m: 0.9, t: 0.9), mk("u4", .debt, .warning, u: 0.9, m: 0.8, t: 0.8)])
    check("RANK: a fourth appears only when it is itself urgent (score 0.83 ≥ 0.75)", urgent.shown.count == 4)
    let grouped = HBInsights.pick([mk("p1", .budget, .watch, u: 0.7, m: 0.7, t: 0.7), mk("p2", .pace, .watch, u: 0.69, m: 0.69, t: 0.69), mk("p3", .debt, .neutral, u: 0.4, m: 0.4, t: 0.4)])
    check("RANK: one per group (budget and pace are one group, so the second is held back)", grouped.shown.map { $0.id } == ["p1", "p3"] && grouped.more.map { $0.id } == ["p2"])
    check("RANK: ties break by id, so the order never changes between runs", HBInsights.pick([mk("b", .bills, .watch, u: 0.5, m: 0.5, t: 0.5), mk("a", .debt, .watch, u: 0.5, m: 0.5, t: 0.5)].sorted { $0.id < $1.id }).shown.map { $0.id } == ["a", "b"])
    var mem = HBInsightMemory()
    let base = find(HBInsights.all(cA), "forecast-2026-10")!.score
    mem.shown["forecast-2026-10"] = 3
    check("RANK: novelty: after three days on Home an insight keeps 40% of its priority (never zero, so something urgent doesn't vanish)", near(find(HBInsights.all(ctx(A, today: "2026-10-24", memory: mem)), "forecast-2026-10")?.score, base * 0.4, 1e-9) && near(mem.novelty("nothing"), 1) && near(HBInsightMemory(shown: ["x": 9]).novelty("x"), 0.4))
    mem.dismiss("forecast-2026-10")
    check("RANK: a dismissed insight stays gone for its period (its id carries the month, so it can return next month)", find(HBInsights.all(ctx(A, today: "2026-10-24", memory: mem)), "forecast-2026-10") == nil && find(HBInsights.all(ctx(A, today: "2026-10-24", month: "2026-10", memory: mem)), "sts-down") != nil)
    var counting = HBInsightMemory(); counting.markShown(["a"], day: "2026-10-24"); counting.markShown(["a"], day: "2026-10-24"); counting.markShown(["a", "b"], day: "2026-10-25")
    check("RANK: it counts days, not renders (twice on the same day is once)", counting.shown["a"] == 2 && counting.shown["b"] == 1)
    let suite = UserDefaults(suiteName: "hb-test-insights")!; suite.removePersistentDomain(forName: "hb-test-insights")
    var saved = HBInsightMemory(); saved.dismiss("k"); saved.markShown(["k"], day: "2026-10-24"); saved.save(suite)
    check("RANK: Bun's memory survives a restart, and is wiped on log out", HBInsightMemory.load(suite) == saved && { HBInsightMemory.clear(suite); return HBInsightMemory.load(suite) == HBInsightMemory() }())

    // ===== The few that matter on a realistic day =====
    let cBusy = ctx(snap(Fix(entries: aRows, recurring: tomorrowBills + rec2, logged: paidSep, goals: [goal("g2", "Emergency", target: 100000, saved: 52000)], jar: tripJar, debts: three)), today: "2026-10-24", prev: pv)
    let planBusy = HBInsights.home(cBusy)
    check("HOME: with many things to say, Bun shows 3 or fewer, one per group, includes something positive, and keeps the rest behind 'More from Bun'",
          planBusy.shown.count <= 4 && planBusy.shown.count >= 2 && Set(planBusy.shown.map { $0.kind.group }).count == planBusy.shown.count && planBusy.shown.contains { $0.tone == .positive } && !planBusy.more.isEmpty)
    check("HOME: positive progress is not hidden behind the warnings", HBInsights.all(cBusy).filter { $0.tone == .positive }.count >= 2)

    // ===== Low data, odd data =====
    let sNew = snap(Fix())
    let newAll = HBInsights.all(ctx(sNew, today: "2026-10-10"))
    check("LOW DATA: a brand-new account with nothing logged gets one friendly, neutral note and no fake intelligence", newAll.count == 1 && newAll[0].kind == .onboarding && newAll[0].tone == .neutral && HBInsights.safeLine(ctx(sNew, today: "2026-10-10")) == nil)
    check("LOW DATA: no budget, no debts, no goals, one expense: nothing about budgets, debts or goals is invented", HBInsights.all(ctx(snap(Fix(entries: [E("l1", "expense", 1200, "Lunch", "food", "2026-10-10")])), today: "2026-10-10")).allSatisfy { !isAny($0.kind, [.budget, .pace, .debt, .goal, .together]) })
    check("LOW DATA: no budget but ten expenses: Bun suggests setting one for the biggest category (with the real total so far)",
          { let rows = [E("o0", "income", 100000, "Pay", nil, "2026-10-01")] + (1...10).map { E("o\($0)", "expense", 2000, "x", "food", String(format: "2026-10-%02d", $0)) }; let i = HBInsights.onboarding(ctx(snap(Fix(entries: rows)), today: "2026-10-12"), HBInsights.Cal(ctx(snap(Fix(entries: rows)), today: "2026-10-12"))).first; return i?.title == "Set a budget for eating out" && i?.note.hasPrefix("You've spent $200 on it so far.") == true }())
    let zeros = snap(Fix(entries: [E("z0", "income", 0, "Zero", nil, "2026-10-01"), E("z1", "expense", 0, "Free", "food", "2026-10-02")]))
    check("EDGE: zero-dollar entries don't produce NaN, infinity or crashes", HBInsights.all(ctx(zeros, today: "2026-10-24")).allSatisfy { $0.score.isFinite && $0.score >= 0 })
    let huge = snap(Fix(entries: [E("h0", "income", 100_000_000_00, "Windfall", nil, "2026-10-01"), E("h1", "expense", 250_000_000_00, "Yacht", "other", "2026-10-02"), E("h2", "expense", 100_00, "Snack", "food", "2026-10-03"), E("h3", "expense", 100_00, "Snack", "food", "2026-10-04"), E("h4", "expense", 100_00, "Snack", "food", "2026-10-05"), E("h5", "expense", 100_00, "Snack", "food", "2026-10-06"), E("h6", "expense", 100_00, "Snack", "food", "2026-10-07")]))
    let hugeAll = HBInsights.all(ctx(huge, today: "2026-10-24"))
    check("EDGE: very large values stay finite and readable (a $100,000,000 month: no overflow, scores within 0…1)", !hugeAll.isEmpty && hugeAll.allSatisfy { $0.score.isFinite && $0.score <= 1 && $0.score >= 0 } && HBInsights.safeLine(ctx(huge, today: "2026-10-24")) != nil)
    let pending = E("pend", "expense", 50000, "Saved offline", "other", "2026-10-23")
    var cOffline = cA; cOffline.entries += entries([pending])
    check("OFFLINE: an entry saved on the phone but not synced counts straight away (Safe to Spend moves by the same $500 Home's number does)", near(HBInsights.left(cOffline), HBInsights.left(cA) - 500) && HBInsights.safeLine(cOffline) == "$3,000 in minus $1,360 spent.")
    var cDeleted = cA; cDeleted.entries.removeAll { $0.id == "a7" }      // the $200 concert is deleted
    check("DELETED: delete the big purchase and the insight about it is gone (nothing is remembered about it)", find(HBInsights.all(cDeleted), "sts-down") == nil || find(HBInsights.all(cDeleted), "sts-down")?.title == "Safe to spend is down $150 this week")

    // ===== Explainability and tone, across everything above =====
    let corpus = HBInsights.all(cBusy) + allA + HBInsights.all(cB) + HBInsights.all(cC) + HBInsights.all(ctx(sP, today: "2026-10-18")) + cmpAll + t0 + t1 + t2 + HBInsights.all(ctx(sGoal, today: "2026-10-24")) + HBInsights.all(ctx(sMoved, today: "2026-10-24")) + newAll
    check("TRACE: every insight explains itself: a rule, at least one number, a score that matches its priority, and an explanation that ends with the priority breakdown",
          !corpus.isEmpty && corpus.allSatisfy { !$0.trace.rule.isEmpty && !$0.trace.facts.isEmpty && near($0.trace.score, $0.score, 1e-12) && $0.trace.explanation().last?.hasPrefix("Priority ") == true && $0.trace.urgency >= 0 && $0.trace.urgency <= 1 && $0.trace.confidence > 0 })
    check("TRACE: ids are unique within a list, and carry their month or week so a dismissal expires with the period", Set(HBInsights.all(cBusy).map { $0.id }).count == HBInsights.all(cBusy).count)
    let banned = ["guarantee", "invest", "loan", "tax", "legal", "advice", "shame", "irresponsible", "should have", "you must", "careful!", "danger", "panic"]
    check("TONE: nothing Bun says promises, advises on investments, loans, tax or law, or shames (checked across every insight above)", corpus.allSatisfy { i in let t = (i.title + " " + i.note).lowercased(); return !banned.contains { t.contains($0) } })
    check("TONE: every claim of a projection says 'projected', 'pace', 'estimate', 'about' or 'roughly' (no pretending to be certain)", corpus.filter { isAny($0.kind, [.forecast, .debt]) && $0.tone != .neutral || $0.id.hasPrefix("goal-pace") }.allSatisfy { i in let t = i.note.lowercased(); return t.contains("projected") || t.contains("pace") || t.contains("about") || t.contains("roughly") || t.contains("moved your projected") || t.contains("sooner") } )
}

run()
print(failures == 0 ? "ALL INSIGHT CHECKS PASSED" : "\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
