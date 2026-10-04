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
print(failures == 0 ? "ALL PASSED" : "\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
