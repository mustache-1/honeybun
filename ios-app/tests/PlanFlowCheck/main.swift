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
