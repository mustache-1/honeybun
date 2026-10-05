import Foundation

// Plan through the app's REAL data path (HBAPI -> URLSession -> JSON -> HBNestSnapshot decoder) against the in-process stand-in backend, plus the
// pure Plan logic (budgets, calendar, subscriptions, forecast) the screens show. Compiled and run by CI on macOS; it does not tap SwiftUI views.
var failures = 0
func check(_ name: String, _ ok: Bool) { print((ok ? "PASS " : "FAIL ") + name); if !ok { failures += 1 } }

func run() async {
    HBMockServer.install(seed: "default")
    let api = HBAPI.shared
    func snap() async -> HBNestSnapshot? { let s = try? await api.nest(month: "2026-09"); HBCatStyle.custom = s?.categories ?? []; return s }
    func refused(_ work: () async throws -> Void) async -> Bool { do { try await work(); return false } catch { return true } }
    let oct4 = HBDay.parse("2026-10-04")!

    var s = await snap()
    guard let first = s else { check("seed loads", false); return }
    check("seed loads with no budgets, debts or own categories (empty states)", (first.budgets ?? []).isEmpty && (first.debts ?? []).isEmpty && (first.categories ?? []).isEmpty && HBPlan.budgets(first).rows.isEmpty)

    // subscriptions (repeating expenses in the Subscriptions category)
    let subs = HBPlan.subscriptions(first, today: oct4)
    check("SUBSCRIPTIONS: Netflix + Discord = $25.98 a month, $311.76 a year; the next charge is Netflix on Oct 5",
          subs.rows.count == 2 && abs(subs.perMonth - 25.98) < 0.001 && abs(subs.perYear - 311.76) < 0.001 && subs.next?.recurring.label == "Netflix" && HBDay.string(subs.next!.date) == "2026-10-05")
    check("SUBSCRIPTIONS: Bills & paydays lists everything else (Rent) without the subscriptions", HBPlan.billsAndPaydays(first, today: oct4).map { $0.label } == ["Rent"])
    check("SUBSCRIPTIONS: weekly and every-2-weeks costs are scaled to a month (52/12 and 26/12)", abs((HBPlan.perMonthFactor["weekly"] ?? 0) - 52.0 / 12) < 1e-9 && abs((HBPlan.perMonthFactor["biweekly"] ?? 0) - 26.0 / 12) < 1e-9)

    // calendar
    let cal = HBPlan.calendar(month: "2026-10", snapshot: first)
    check("CALENDAR: October 2026 has 31 days and starts on a Thursday (4 blank cells, weeks begin on Sunday)", cal.days.count == 31 && cal.leadingBlanks == 4)
    check("CALENDAR: Netflix shows on Oct 5 and Discord on Oct 8, nothing on Oct 6", cal.days[4].items.map { $0.recurring.label } == ["Netflix"] && cal.days[7].items.map { $0.recurring.label } == ["Discord Nitro"] && cal.days[5].items.isEmpty)
    check("CALENDAR: February 2027 has 28 days", HBPlan.calendar(month: "2027-02", snapshot: first).days.count == 28)

    // budgets
    let spentGroc = HBPlan.spentByCategory(first.entries)["groc"] ?? 0
    let spentFood = HBPlan.spentByCategory(first.entries)["food"] ?? 0
    try? await api.saveBudgets(["groc": 400, "food": 200, "fun": 0], rollover: true)
    s = await snap()
    var b = HBPlan.budgets(s!)
    check("BUDGETS: saving two limits stores two (a 0 limit means none) and switches roll-over on", (s?.budgets ?? []).count == 2 && s?.nest.rollover == 1)
    check("BUDGETS: each row's spent comes from this month's real entries and rows sort most-used first",
          b.rows.count == 2 && abs((b.rows.first { $0.category == "groc" }?.spent ?? -1) - spentGroc) < 0.001 && abs((b.rows.first { $0.category == "food" }?.spent ?? -1) - spentFood) < 0.001
          && b.rows[0].ratio >= b.rows[1].ratio && abs(b.totalLimit - 600) < 0.001 && abs(b.totalSpent - (spentGroc + spentFood)) < 0.001)
    let foodRow = b.rows.first { $0.category == "food" }!
    check("BUDGETS: Eating out is over its $200 limit (spent more) and says by how much", foodRow.over == (spentFood > 200) && foodRow.left == 200 - spentFood)
    try? await api.saveBudgets(["food": 200], rollover: false)
    s = await snap(); b = HBPlan.budgets(s!)
    check("BUDGETS: saving again replaces them all (one row now) and roll-over is off", b.rows.count == 1 && s?.nest.rollover == 0)
    try? await api.saveBudgets(["not_a_category": 50], rollover: false)
    s = await snap()
    check("BUDGETS: an unknown category is ignored by the backend (nothing was stored)", (s?.budgets ?? []).isEmpty)

    // custom categories
    let newID = (try? await api.createCategory(name: "Pets", emoji: "🐶")) ?? ""
    s = await snap()
    check("CATEGORIES: a new category appears with its name and emoji, and every screen can look it up", newID.hasPrefix("c_") && s?.categories?.first?.name == "Pets" && HBCatStyle.of(newID).label == "Pets" && HBCatStyle.of(newID).emoji == "🐶" && HBCatStyle.of(newID).isCustom)
    check("CATEGORIES: the list of categories to file under is the 11 built-in ones plus the account's own", HBCatStyle.all.count == 12 && HBCatStyle.all.last?.id == newID)
    check("CATEGORIES: a blank name is refused", await refused { _ = try await api.createCategory(name: "  ", emoji: "🐶") })
    try? await api.saveBudgets([newID: 75], rollover: false)
    var e = HBEntryDraft(date: "2026-09-29", memberID: first.me?.id ?? ""); e.amount = 12.5; e.label = "Dog food"; e.category = newID
    try? await api.addEntry(e)
    s = await snap()
    check("CATEGORIES: an expense filed under it counts toward its budget (spent $12.50 of $75)", { let r = HBPlan.budgets(s!).rows.first; return r?.category == newID && abs((r?.spent ?? 0) - 12.5) < 0.001 && abs((r?.limit ?? 0) - 75) < 0.001 }())
    try? await api.updateCategory(id: newID, name: "Pet care", emoji: "🐱")
    s = await snap()
    check("CATEGORIES: renaming it changes its name and emoji everywhere", HBCatStyle.of(newID).label == "Pet care" && HBCatStyle.of(newID).emoji == "🐱")
    try? await api.deleteCategory(id: newID)
    s = await snap()
    check("CATEGORIES: deleting it moves its expenses to Other and removes its budget (nothing is lost)",
          (s?.categories ?? []).isEmpty && (s?.budgets ?? []).isEmpty && s?.entries.first { $0.label == "Dog food" }?.category == "other" && HBCatStyle.of(newID).label == "Other")
    var many = 0
    for i in 0..<13 { if (try? await api.createCategory(name: "C\(i)", emoji: "🎨")) != nil { many += 1 } }
    check("CATEGORIES: up to 12 of your own, the 13th is refused", many == 12)

    // debts
    var d = HBDebtDraft(); d.name = "Visa"; d.balance = 1000; d.apr = 19.99; d.minimum = 35
    try? await api.addDebt(d)
    s = await snap()
    guard let visa = s?.debts?.first else { check("DEBTS: add", false); return }
    check("DEBTS: a new debt stores balance, APR and minimum exactly (APR is kept in basis points)", s?.debts?.count == 1 && visa.start_cents == 100000 && visa.apr_bp == 1999 && visa.min_cents == 3500 && visa.paid_cents == 0 && abs(visa.remaining - 1000) < 0.001)
    check("DEBTS: APR is shown without trailing zeros (19.99, and 5 not 5.00)", HBPlanText.percent(visa.apr) == "19.99" && HBPlanText.percent(5) == "5" && HBPlanText.percent(4.5) == "4.50")
    check("DEBTS: a blank name is refused", await refused { var x = HBDebtDraft(); x.balance = 10; try await api.addDebt(x) })
    check("DEBTS: a debt with no balance is refused", await refused { var x = HBDebtDraft(); x.name = "Zero"; try await api.addDebt(x) })
    check("DEBTS: an interest rate over 100% is refused", await refused { var x = HBDebtDraft(); x.name = "Loan"; x.balance = 10; x.apr = 150; try await api.addDebt(x) })
    d.name = "Visa Platinum"; d.apr = 17; try? await api.updateDebt(id: visa.id, d)
    s = await snap()
    check("DEBTS: editing changes the name and APR and keeps the payments", s?.debts?.first?.name == "Visa Platinum" && s?.debts?.first?.apr_bp == 1700)
    let me = first.me?.id ?? ""
    try? await api.payDebt(id: visa.id, amount: 100, memberID: me, date: "2026-09-29")
    s = await snap()
    let after = s?.debts?.first
    check("DEBTS: a $100 payment leaves $900 and 10% paid, and is listed as a recent payment", abs((after?.remaining ?? 0) - 900) < 0.001 && abs((after?.progress ?? 0) - 0.1) < 0.001 && s?.debt_payments?.first?.amount_cents == 10000)
    // Debt Center+: who paid what, all time (the server sends per-member totals; /api/nest only lists the latest payments)
    check("DEBT CENTER: the server's per-member totals show my $100 on the Visa", s?.debt_paid_by?.contains(HBDebtContribution(debt_id: visa.id, member_id: me, paid_cents: 10000)) == true)
    let mine = s.map { HBPlan.contributions(for: visa, snapshot: $0) } ?? []
    check("DEBT CENTER: contributions(for:) lists the payer with their dollars, and nobody who has paid nothing", mine.count == 1 && mine.first?.memberID == me && abs((mine.first?.paid ?? 0) - 100) < 0.001)
    check("DEBTS: the payment is also filed as a 'Payment: …' expense in Debt, so it counts in the month", s?.entries.contains { $0.label == "Payment: Visa Platinum" && $0.category == "debt" && $0.amount_cents == 10000 } == true)
    check("DEBTS: a payment of $0 is refused", await refused { try await api.payDebt(id: visa.id, amount: 0, memberID: me, date: "2026-09-29") })
    try? await api.payDebt(id: visa.id, amount: 900, memberID: me, date: "2026-09-30")
    s = await snap()
    check("DEBTS: paying the rest marks it paid off (nothing left, 100%)", s?.debts?.first?.paidOff == true && s?.debts?.first?.progress == 1)
    if let pid = s?.debt_payments?.first?.id { try? await api.deleteDebtPayment(id: pid) }
    s = await snap()
    check("DEBTS: removing a payment puts it back on the debt and removes its expense", abs((s?.debts?.first?.remaining ?? 0) - 900) < 0.001 && !(s?.entries.contains { $0.amount_cents == 90000 } ?? true))
    try? await api.deleteDebt(id: visa.id)
    s = await snap()
    check("DEBTS: deleting a debt removes it and its payment history (payments already in spending stay)", (s?.debts ?? []).isEmpty && (s?.debt_payments ?? []).isEmpty && s?.entries.contains { $0.label == "Payment: Visa Platinum" } == true)

    // debt payoff planner (Snowball / Avalanche / extra monthly payment / debt-free month), checked against the website's payoffPlan() by hand-worked cases
    func debt(_ id: String, _ bal: Int, _ aprPct: Double, _ min: Int, paid: Int = 0) -> HBDebt {
        let j = "{\"id\":\"\(id)\",\"name\":\"\(id)\",\"start_cents\":\(bal * 100),\"apr_bp\":\(Int(aprPct * 100)),\"min_cents\":\(min * 100),\"paid_cents\":\(paid * 100)}"
        return try! JSONDecoder().decode(HBDebt.self, from: Data(j.utf8))
    }
    let small = debt("small", 500, 10, 50), big = debt("big", 5000, 24, 100), mid = debt("mid", 1200, 3, 40)
    let snow = HBPlan.payoffPlan([big, small, mid], strategy: .snowball, extra: 0)
    let aval = HBPlan.payoffPlan([big, small, mid], strategy: .avalanche, extra: 0)
    check("PAYOFF: Snowball pays the smallest balance first (small, mid, big)", snow.order == ["small", "mid", "big"])
    check("PAYOFF: Avalanche pays the highest interest first (big 24%, small 10%, mid 3%)", aval.order == ["big", "small", "mid"])
    check("PAYOFF: a tie on rate goes to the smaller balance (Avalanche), and equal balances keep the order they were added (Snowball)",
          HBPlan.payoffPlan([debt("a", 900, 12, 30), debt("b", 400, 12, 30)], strategy: .avalanche, extra: 0).order == ["b", "a"]
          && HBPlan.payoffPlan([debt("x", 300, 5, 20), debt("y", 300, 9, 20)], strategy: .snowball, extra: 0).order == ["x", "y"])
    check("PAYOFF: every debt gets a payoff month, the debt-free month is the last of them, and an extra payment makes it sooner",
          snow.months != nil && snow.done.count == 3 && snow.months == snow.done.values.max() && HBPlan.payoffPlan([big, small, mid], strategy: .snowball, extra: 200).months! < snow.months!)
    // one debt, no interest: $1,000 at $100 a month is exactly 10 months; with $150 extra it is 4 months
    let flat = debt("flat", 1000, 0, 100)
    check("PAYOFF: $1,000 at 0% with $100 a month is 10 months; with $150 extra it is 4 months (1000/250)", HBPlan.payoffPlan([flat], strategy: .snowball, extra: 0).months == 10 && HBPlan.payoffPlan([flat], strategy: .snowball, extra: 150).months == 4)
    // with interest: $1,000 at 12% (1% a month), $100 a month. Month 1: 1000 -> 1010 -> 910 ... the standard annuity answer is 11 months
    check("PAYOFF: $1,000 at 12% APR with $100 a month takes 11 months (interest added each month before the payment)", HBPlan.payoffPlan([debt("loan", 1000, 12, 100)], strategy: .snowball, extra: 0).months == 11)
    let noMin = debt("n", 500, 5, 0)
    check("PAYOFF: no minimums and no extra means no date (the 'Add minimum payments' message); an extra payment alone is enough to plan with",
          HBPlan.payoffPlan([noMin], strategy: .snowball, extra: 0).months == nil && (HBPlan.payoffPlan([noMin], strategy: .snowball, extra: 25).months ?? 0) > 18)
    check("PAYOFF: a minimum too small to cover the interest never pays off (capped at 600 months → no date)", HBPlan.payoffPlan([debt("trap", 10000, 36, 50)], strategy: .snowball, extra: 0).months == nil)
    check("PAYOFF: paid-off debts are left out of the plan; nothing owed is 0 months", HBPlan.payoffPlan([debt("done", 100, 5, 10, paid: 100)], strategy: .snowball, extra: 0).months == 0 && HBPlan.payoffPlan([], strategy: .avalanche, extra: 10).order.isEmpty)
    check("PAYOFF: debts are listed in plan order with paid-off ones last", HBPlan.debtsInPlanOrder([debt("done", 100, 5, 10, paid: 100), big, small], plan: HBPlan.payoffPlan([debt("done", 100, 5, 10, paid: 100), big, small], strategy: .snowball, extra: 0)).map { $0.id } == ["small", "big", "done"])
    // the debt-free month label counts months like the website's setMonth (the 31st rolls over)
    let jan31 = HBDay.parse("2026-01-31")!, oct4b = HBDay.parse("2026-10-04")!
    check("PAYOFF: month labels: Oct 4 + 10 months = Aug 2027; Oct 4 + 0 = Oct 2026; Jan 31 + 1 month rolls into March like the website", HBPlan.monthsOut(10, from: oct4b) == "Aug 2027" && HBPlan.monthsOut(0, from: oct4b) == "Oct 2026" && HBPlan.monthsOut(1, from: jan31) == "Mar 2026")
    // remembered choices
    let ud = UserDefaults(suiteName: "hb-test-debtprefs")!; ud.removePersistentDomain(forName: "hb-test-debtprefs")
    check("PAYOFF: the strategy defaults to Snowball and the extra to 0; both are remembered", HBDebtPrefs.strategy(ud) == .snowball && HBDebtPrefs.extra(ud) == 0)
    HBDebtPrefs.setStrategy(.avalanche, ud); HBDebtPrefs.setExtra(75.5, ud)
    check("PAYOFF: …after choosing Avalanche and $75.50 extra they come back, and a negative extra is 0", HBDebtPrefs.strategy(ud) == .avalanche && HBDebtPrefs.extra(ud) == 75.5 && { HBDebtPrefs.setExtra(-5, ud); return HBDebtPrefs.extra(ud) == 0 }())

    // Debt Center+: every number on the new screen comes from the same payoffPlan() run (hand-checked against a literal port of the website's loop)
    func near(_ x: Double?, _ y: Double, _ tol: Double = 0.01) -> Bool { abs((x ?? .infinity) - y) <= tol }
    let flatRun = HBPlan.payoffPlan([flat], strategy: .snowball, extra: 0)
    check("DEBT CENTER: with 0% interest the run costs $0 in interest and the balance falls $100 a month from $1,000 to $0 (11 points)",
          flatRun.interest == 0 && flatRun.balances.count == 11 && flatRun.balances.first == 1000 && flatRun.balances.last == 0 && flatRun.balances[3] == 700)
    let loanRun = HBPlan.payoffPlan([debt("loan", 1000, 12, 100)], strategy: .snowball, extra: 0)
    check("DEBT CENTER: $1,000 at 12% APR, $100 a month: 11 months, $58.98 of interest, balances 1000 → 910 → 819.10 … 0",
          loanRun.months == 11 && near(loanRun.interest, 58.98) && loanRun.balances.count == 12 && near(loanRun.balances[1], 910) && near(loanRun.balances[2], 819.10) && loanRun.balances.last == 0)
    check("DEBT CENTER: the new read-outs change nothing about the plan itself (same months, order and payoff months as before)", snow.months == 58 && aval.months == 57 && snow.order == ["small", "mid", "big"] && aval.order == ["big", "small", "mid"])
    check("DEBT CENTER: nothing owed, or no payment to plan with, gives no interest and a flat balance path", HBPlan.payoffPlan([], strategy: .snowball, extra: 0).balances == [0] && HBPlan.payoffPlan([noMin], strategy: .snowball, extra: 0).balances == [500] && HBPlan.payoffPlan([noMin], strategy: .snowball, extra: 0).interest == 0)

    let sum = HBPlan.debtSummary([big, small, mid, debt("done", 100, 5, 10, paid: 100)])
    // 4 debts: $5,000 + $500 + $1,200 + $100 (already paid off) = $6,800 started; the $100 one is the only payment; 3 are still open
    check("DEBT CENTER: summary: 4 debts, 3 still open, $6,800 started, $100 paid, $6,700 left, $190 in minimums, ~$107.17 of interest a month, ~1.47% paid",
          sum.count == 4 && sum.openCount == 3 && near(sum.startTotal, 6800) && near(sum.paidTotal, 100) && near(sum.remaining, 6700) && near(sum.minimums, 190) && near(sum.interestPerMonth, 107.1667, 0.001) && near(sum.progress, 100.0 / 6800, 1e-9)
          && near(sum.startTotal - sum.paidTotal, sum.remaining))
    let over = HBPlan.debtSummary([debt("over", 100, 0, 10, paid: 150), small])
    check("DEBT CENTER: an overpaid debt counts as paid only up to what was owed ($100, not $150), so started − paid = left and progress stays honest (100 of 600)",
          near(over.startTotal, 600) && near(over.paidTotal, 100) && near(over.remaining, 500) && near(over.startTotal - over.paidTotal, over.remaining) && near(over.progress, 100.0 / 600, 1e-9) && over.openCount == 1)
    check("DEBT CENTER: summary of nothing is all zeros", HBPlan.debtSummary([]) == HBDebtSummary())

    let cmp0 = HBPlan.compareStrategies([big, small, mid], extra: 0)
    check("DEBT CENTER: each side of the comparison IS the real planner's answer for that strategy", cmp0.snowball == snow && cmp0.avalanche == aval && cmp0.plan(.avalanche) == aval)
    check("DEBT CENTER: with the minimums only, Avalanche (57 months, $4,017.40) beats Snowball (58 months, $4,187.61): saves $170.21 and 1 month",
          cmp0.better == .avalanche && snow.months == 58 && near(snow.interest, 4187.61) && near(aval.interest, 4017.40) && near(cmp0.interestSaved, 170.21) && cmp0.monthsSooner == 1)
    let cmp200 = HBPlan.compareStrategies([big, small, mid], extra: 200)
    check("DEBT CENTER: with $200 extra both finish in 21 months and Avalanche still saves $282.09 ($1,164.87 vs $1,446.96), 0 months sooner",
          cmp200.better == .avalanche && cmp200.snowball.months == 21 && cmp200.avalanche.months == 21 && near(cmp200.interestSaved, 282.09) && cmp200.monthsSooner == 0)
    let cmpFlat = HBPlan.compareStrategies([flat], extra: 0)
    check("DEBT CENTER: one debt has nothing to compare (no 'better', nothing saved); a plan that never pays off has no 'better' either",
          cmpFlat.better == nil && cmpFlat.interestSaved == 0 && cmpFlat.monthsSooner == 0 && HBPlan.compareStrategies([debt("trap", 10000, 36, 50)], extra: 0).better == nil)

    let plus200 = HBPlan.extraImpact([big, small, mid], strategy: .snowball, extra: 0, adding: 200)
    check("DEBT CENTER: 'what if +$200 a month' on the Snowball plan: debt-free in 21 months instead of 58 (37 sooner), $2,740.65 less interest, and it is exactly the planner's own $200 plan",
          plus200.plan == HBPlan.payoffPlan([big, small, mid], strategy: .snowball, extra: 200) && plus200.plan.months == 21 && plus200.monthsSooner == 37 && near(plus200.interestSaved, 2740.65))
    let plus0 = HBPlan.extraImpact([big, small, mid], strategy: .snowball, extra: 0, adding: 0)
    check("DEBT CENTER: adding $0 changes nothing; adding on top of an existing extra is measured against that extra",
          plus0.monthsSooner == 0 && plus0.interestSaved == 0 && HBPlan.extraImpact([big, small, mid], strategy: .snowball, extra: 200, adding: 50).plan == HBPlan.payoffPlan([big, small, mid], strategy: .snowball, extra: 250))
    let giveDate = HBPlan.extraImpact([noMin], strategy: .snowball, extra: 0, adding: 25)
    check("DEBT CENTER: a debt with no minimum has no date, but an extra amount gives it one (no 'sooner' claim is made)", giveDate.plan.months != nil && giveDate.monthsSooner == nil && giveDate.interestSaved == nil)
    check("DEBT CENTER: lengths read like people say them (3 mo, 1 yr, 1 yr 2 mo, 2 yrs)", HBPlan.duration(months: 3) == "3 mo" && HBPlan.duration(months: 12) == "1 yr" && HBPlan.duration(months: 14) == "1 yr 2 mo" && HBPlan.duration(months: 24) == "2 yrs")

    // forecast
    let sep29 = HBDay.parse("2026-09-29")!, sep3 = HBDay.parse("2026-09-03")!
    s = await snap()
    if case let .ready(f) = HBPlan.forecast(s!, month: "2026-09", today: sep29, myID: me) {
        let income = s!.entries.filter { $0.isIncome }.reduce(0) { $0 + $1.amount }, spent = s!.entries.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
        check("FORECAST: leftNow is what came in minus what went out (carry-over aside); a month-end line projects below it", abs(f.leftNow - (income - spent)) < 0.001 && f.endLeft < f.leftNow && f.dim == 30 && f.daysLeft == 1 && f.points.count == 29)
    } else { check("FORECAST: ready late in the month", false) }
    if case .wait = HBPlan.forecast(s!, month: "2026-09", today: sep3, myID: me) { check("FORECAST: in the first week it says to check back in a few days", true) } else { check("FORECAST: in the first week it says to check back in a few days", false) }
    if case .notThisMonth = HBPlan.forecast(s!, month: "2026-08", today: sep29, myID: me) { check("FORECAST: only for the current month", true) } else { check("FORECAST: only for the current month", false) }
}

let done = DispatchSemaphore(value: 0)
Task { await run(); done.signal() }
if done.wait(timeout: .now() + 90) == .timedOut { print("FAIL timed out"); exit(1) }
print(failures == 0 ? "ALL PLAN FLOW CHECKS PASSED" : "\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
