import Foundation

// Decodes a real /api/nest response (fixtures/nest.json, captured by api-contract.mjs from the actual worker) with the app's own models,
// then runs the Coming Up logic and the request builders. Compiled and run by CI on macOS.
var failures = 0
func check(_ name: String, _ ok: Bool) { print((ok ? "PASS " : "FAIL ") + name); if !ok { failures += 1 } }

guard CommandLine.arguments.count > 1,
      let data = FileManager.default.contents(atPath: CommandLine.arguments[1]),
      let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let snapJSON = root["snapshot"],
      let snapData = try? JSONSerialization.data(withJSONObject: snapJSON) else { print("FAIL could not read fixture"); exit(1) }

do {
    let s = try JSONDecoder().decode(HBNestSnapshot.self, from: snapData)
    check("real /api/nest decodes with HBNestSnapshot", true)
    check("me + nest + members present", s.me != nil && !s.nest.id.isEmpty && s.members.count == 1)
    check("entries decoded (expense and income)", s.entries.contains { $0.type == "expense" } && s.entries.contains { $0.type == "income" })
    check("income entry has nil category (optional)", s.entries.first { $0.isIncome }?.category == nil)
    check("amounts are cents → dollars", s.entries.contains { $0.amount_cents == 300000 && $0.amount == 3000.0 })
    check("recurring + logged + goals decoded", s.recurring.count >= 2 && !s.logged.isEmpty && s.goals.count == 1)

    let up = HBRecur.upcoming(s)
    let names = up.map { $0.recurring.label }
    check("Coming Up has the unpaid bill and payday", names.contains("Phone bill") && names.contains("Side payday"))
    check("Coming Up is sorted by date", zip(up, up.dropFirst()).allSatisfy { $0.date <= $1.date })
    check("every bill appears once", Set(up.map { $0.recurring.id }).count == up.count)
    let paid = s.logged.first!
    check("an occurrence that was logged is skipped", !up.contains { $0.recurring.id == paid.recurring_id && $0.dateString == paid.occ_date })

    // Money chart: bars come only from the real entries' dates and amounts
    let daily = HBChartMath.dailyExpenses(s.entries)
    let totalOut = s.entries.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
    check("chart: per-day expense sums add up to the month's real spending", abs(daily.values.reduce(0, +) - totalOut) < 0.001)
    let sl = HBChartMath.slices(daily: daily, daysInMonth: 30)
    check("chart: 15 two-day slices for a 30-day month, total preserved", sl.count == 15 && abs(sl.reduce(0, +) - totalOut) < 0.001)
    let probe = try JSONDecoder().decode([HBEntry].self, from: Data(#"[{"id":"a","member_id":"m","type":"expense","amount_cents":1000,"label":"x","category":"food","shared":0,"private":0,"date":"2026-09-02"},{"id":"b","member_id":"m","type":"expense","amount_cents":2500,"label":"y","category":null,"shared":0,"private":0,"date":"2026-09-03"},{"id":"c","member_id":"m","type":"expense","amount_cents":700,"label":"z","category":"car","shared":0,"private":0,"date":"2026-09-30"},{"id":"d","member_id":"m","type":"income","amount_cents":999900,"label":"pay","category":null,"shared":0,"private":0,"date":"2026-09-03"}]"#.utf8))
    let ps = HBChartMath.slices(daily: HBChartMath.dailyExpenses(probe), daysInMonth: 30)
    check("chart: day 2 → slice 0, day 3 → slice 1, day 30 → last slice", ps[0] == 10 && ps[1] == 25 && ps[14] == 7 && ps.reduce(0, +) == 42)
    check("chart: income never appears in the spending bars", HBChartMath.dailyExpenses(probe)[3] == 25)
    check("category names are the account's own", HBCategory.groc.label == "Groceries" && HBCategory.food.label == "Eating out" && HBCategory.home.label == "Housing" && HBCategory.car.label == "Car")

    // month-end clamp: a bill anchored on the 31st lands on the last day of shorter months
    let r = try JSONDecoder().decode(HBRecurring.self, from: Data(#"{"id":"x","type":"expense","label":"Rent","amount_cents":100000,"category":null,"member_id":"m","shared":0,"split_mode":null,"split_value":null,"freq":"monthly","anchor_date":"2026-01-31"}"#.utf8))
    let feb = HBRecur.occurrences(r, from: HBDay.parse("2026-02-01")!, to: HBDay.parse("2026-02-28")!)
    check("monthly bill on the 31st lands on Feb 28", feb.count == 1 && HBDay.string(feb[0]) == "2026-02-28")
    let wk = try JSONDecoder().decode(HBRecurring.self, from: Data(#"{"id":"y","type":"income","label":"Pay","amount_cents":1,"category":null,"member_id":"m","shared":0,"split_mode":null,"split_value":null,"freq":"biweekly","anchor_date":"2026-01-02"}"#.utf8))
    let bw = HBRecur.occurrences(wk, from: HBDay.parse("2026-01-20")!, to: HBDay.parse("2026-02-20")!)
    check("every-2-weeks payday steps 14 days", bw.map { HBDay.string($0) } == ["2026-01-30", "2026-02-13"])

    // request bodies the backend requires
    var d = HBEntryDraft(date: "2026-10-04", memberID: "abc"); d.amount = 12.5; d.label = "Lunch"; d.category = "food"
    let j = d.json
    check("expense body has member_id, amount, date, category", (j["member_id"] as? String) == "abc" && (j["amount"] as? Double) == 12.5 && (j["date"] as? String) == "2026-10-04" && (j["category"] as? String) == "food")
    var inc = HBEntryDraft(type: "income", date: "2026-10-04", memberID: "abc"); inc.amount = 10
    check("income body has no category", inc.json["category"] == nil)
    check("shared body carries its split", { var x = d; x.shared = true; x.splitMode = "percent"; x.splitValue = 60; return (x.json["split_mode"] as? String) == "percent" }())
} catch {
    print("FAIL decode threw: \(error)")
    failures += 1
}
#if DEBUG
// the screenshot fixture must decode with the app's own models and add up to the numbers it is meant to show
if let pd = HBPreviewData.json.data(using: .utf8), let ps = try? JSONDecoder().decode(HBNestSnapshot.self, from: pd) {
    let inc = ps.entries.filter { $0.isIncome }.reduce(0) { $0 + $1.amount_cents }, out = ps.entries.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount_cents }
    check("preview fixture decodes and totals 2540.00 in / 1897.82 out", inc == 254000 && out == 189782)
    check("preview fixture has 3 bills and a 12-day streak", ps.recurring.count == 3 && ps.members.first?.streak == 12)
} else { check("preview fixture decodes", false) }
#endif
print(failures == 0 ? "ALL PASSED" : "\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
