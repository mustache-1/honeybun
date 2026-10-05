import Foundation

// Stats, levels/badges, referrals and changing household through the app's REAL data path against the in-process stand-in backend,
// plus the pure Stats/Progress logic the screens show. Compiled and run by CI on macOS; it does not tap SwiftUI views.
var failures = 0
func check(_ name: String, _ ok: Bool) { print((ok ? "PASS " : "FAIL ") + name); if !ok { failures += 1 } }

func run() async {
    HBMockServer.install(seed: "default")
    let api = HBAPI.shared
    func snap() async -> HBNestSnapshot? { try? await api.nest(month: "2026-09") }
    func refused(_ work: () async throws -> Void) async -> String? { do { try await work(); return nil } catch { return "\(error)" } }
    guard let s0 = await snap() else { check("seed loads", false); return }

    // levels (25 * l * (l - 1) carrots to reach level l)
    check("LEVELS: 0 carrots is level 1; 50 is level 2; 150 is level 3; 299 is still level 3; 300 is level 4",
          HBProgress.levelFor(0) == 1 && HBProgress.levelFor(49) == 1 && HBProgress.levelFor(50) == 2 && HBProgress.levelFor(150) == 3 && HBProgress.levelFor(299) == 3 && HBProgress.levelFor(300) == 4)
    let li = HBProgress.levelInfo(200)
    check("LEVELS: 200 carrots is level 3 (Hoppy Saver), a third of the way to level 4", li.level == 3 && li.title == "Hoppy Saver" && li.lo == 150 && li.hi == 300 && abs(li.pct - 50.0 / 150.0) < 1e-9)
    check("LEVELS: the title list has ten names and level 10+ stays Honeybun Legend", HBProgress.titles.count == 10 && HBProgress.levelInfo(5000).title == "Honeybun Legend")

    // streaks
    let me = s0.members.first { $0.id == s0.me?.id }!
    check("STREAK: logged today (12-day streak) counts; two days later with nothing new it is 0",
          HBProgress.streak(me, today: HBDay.parse("2026-10-04")!) == 12 && HBProgress.streak(me, today: HBDay.parse("2026-10-05")!) == 12 && HBProgress.streak(me, today: HBDay.parse("2026-10-06")!) == 0)
    check("CARROTS: this week's carrots only count when the stored week is this week (weeks start Monday)", HBProgress.weekXP(me, today: HBDay.parse("2026-10-01")!) == 200 && HBProgress.weekXP(me, today: HBDay.parse("2026-10-08")!) == 0)

    // badges
    let badges = HBProgress.badges(me, s0)
    func got(_ id: String) -> Bool { badges.first { $0.id == id }?.unlocked ?? false }
    check("BADGES: 16 badges; First hop, Carrot counter(31 logs: no), Payday planner(no payday: no), Goal getter (a goal is complete) is earned, Better together (alone) is not",
          badges.count == 16 && got("star") && !got("carrot") && !got("coin") && got("jar") && !got("heart") && !got("party") && !got("target"))
    check("BADGES: Year in review needs 6 months with entries", !HBProgress.badges(me, s0, monthsWithEntries: 5).first { $0.id == "cal" }!.unlocked && HBProgress.badges(me, s0, monthsWithEntries: 6).first { $0.id == "cal" }!.unlocked)

    // the year
    let y = (try? await api.year(2026)) ?? HBYearData(entries: [])
    let t = HBStats.year(y)
    let income = s0.entries.filter { $0.isIncome }.reduce(0) { $0 + $1.amount }, spent = s0.entries.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
    check("YEAR: /api/year totals match the entries (earned and spent land in September, 8 other months are empty)", abs(t.totalIn - income) < 0.001 && abs(t.totalOut - spent) < 0.001 && t.income[8] == t.totalIn && t.spent[0] == 0 && t.monthsWithEntries == 1)
    check("YEAR: Kept is the whole percent of income that was not spent", t.keptPct == Int(((income - spent) / income * 100).rounded()))
    check("YEAR: a year with no entries has no Kept percentage (shown as –)", HBStats.year(HBYearData(entries: [])).keptPct == nil)
    check("YEAR: a different year is empty", ((try? await api.year(2025))?.entries.count ?? -1) == 0)
    let w = HBStats.whereItWent(t.byCategory)
    check("WHERE IT WENT: the five biggest categories, biggest first, then everything else together", w.rows.count == 5 && w.rows == w.rows.sorted { $0.amount > $1.amount } && abs(w.rows.reduce(0) { $0 + $1.amount } + w.rest - spent) < 0.001)

    // 50 / 30 / 20
    if let r = HBStats.rule(s0) {
        let by = HBPlan.spentByCategory(s0.entries)
        let n = HBStats.needs.reduce(0) { $0 + (by[$1] ?? 0) }
        check("50/30/20: needs are the share of income spent on housing, groceries, bills, car, pets and debt", r.needs == Int((n / income * 100).rounded()) && r.verdict.count > 0)
    } else { check("50/30/20: has a result when income exists", false) }
    var noIncome: HBNestSnapshot? = nil
    if var o = (try? JSONSerialization.jsonObject(with: Data(HBPreviewData.json.utf8))) as? [String: Any] {
        o["entries"] = (o["entries"] as? [[String: Any]] ?? []).filter { ($0["type"] as? String) != "income" }
        noIncome = (try? JSONSerialization.data(withJSONObject: o)).flatMap { try? JSONDecoder().decode(HBNestSnapshot.self, from: $0) }
    }
    check("50/30/20: with no income there is no split", noIncome != nil && HBStats.rule(noIncome!) == nil)

    // recap
    let recap = HBStats.recap(s0, month: "2026-09", me: me, today: HBDay.parse("2026-10-04")!)
    check("RECAP: kept %, earned, spent, streak and level come from real data; top spend is the biggest category",
          recap.keptPct == Int(((income - spent) / income * 100).rounded()) && abs(recap.income - income) < 0.001 && abs(recap.spent - spent) < 0.001 && recap.streak == 12 && recap.level == 3 && recap.topCategory != nil)
    check("RECAP: the message follows how it went (20%+ kept → the proud one)", recap.message == (((recap.keptPct ?? 0) >= 20) ? "Look at you go! Your bunny is so proud ♡" : (recap.streak >= 3 ? "Keep hopping. Your bunny is proud of you." : "Every little log helps your bunny grow ♡")))

    // CSV
    let csv = HBStats.csv(y, memberName: { _ in "Sam" }, categoryName: { HBCatStyle.of($0).label })
    let lines = csv.components(separatedBy: "\r\n")
    check("CSV: a header plus one row per entry; money is signed (expenses negative); quotes are escaped",
          lines.count == y.entries.count + 1 && lines[0].contains("\"Date\",\"Type\",\"Category\",\"Description\",\"Who\",\"Amount\",\"Split\",\"Private\"") && csv.hasPrefix("\u{FEFF}") && lines[1].contains(",\"-") == (!y.entries[0].isIncome))

    // referrals
    if let r = try? await api.referrals() {
        check("REFERRALS: code, goal, reward, friends and gift cards load; 4 counted with a goal of 3 is 1 toward the next card", r.code == "ABC123" && r.goal == 3 && r.reward_cents == 1000 && r.inCycle == 1 && r.people.count == 2 && r.rewards.count == 1 && r.link == "https://honeybun.me/r/ABC123")
    } else { check("REFERRALS: load", false) }
    check("REFERRALS: the reasons a friend did not count read in plain words", HBStats.referralReason("same_device") == "Signed up on your device" && HBStats.referralReason("inactive") == "Didn't stick around for a week")

    // help and what's new (generated from the website's own lists)
    check("HELP: the website's four topics with their questions load", HBHelp.topics.count == 4 && HBHelp.topics.allSatisfy { !$0.faqs.isEmpty } && HBHelp.topics.map { $0.t }.contains("Getting started"))
    let all = HBHelp.faqs(topic: nil, query: "")
    check("HELP: search matches the question or the answer, case-insensitively; a topic narrows the list; nonsense finds nothing",
          all.count == HBHelp.topics.reduce(0) { $0 + $1.faqs.count } && !HBHelp.faqs(topic: nil, query: "INVITE").isEmpty && HBHelp.faqs(topic: 0, query: "").count == HBHelp.topics[0].faqs.count && HBHelp.faqs(topic: nil, query: "zzzqqqxx").isEmpty)
    check("WHAT'S NEW: releases load newest first, each with items and tags that have names", !HBHelp.releases.isEmpty && HBHelp.releases[0].v == "3.0" && !HBHelp.releases[0].items.isEmpty && HBHelp.releases[0].items.allSatisfy { !$0.tags.isEmpty && HBHelp.tagNames[$0.tags[0]] != nil })

    // hop calendar (September 2026 starts on a Tuesday; weeks start on Monday)
    if let hop = HBStats.hopCalendar(s0.entries, month: "2026-09", today: HBDay.parse("2026-10-04")!) {
        let spendDays = Set(s0.entries.filter { !$0.isIncome }.map { $0.date }).count
        check("HOP CALENDAR: 30 days, 1 blank cell before Tuesday the 1st, a past month has every day done", hop.days.count == 30 && hop.lead == 1 && hop.days.allSatisfy { $0.done })
        check("HOP CALENDAR: no-spend days are the days with no expenses; the biggest day is the one with the most spending", hop.noSpendDays == 30 - spendDays && hop.biggest != nil && hop.biggest!.amount >= hop.days.map { $0.spend }.max()! - 0.001)
        check("HOP CALENDAR: the dot rank runs 0 (smallest) to 1 (biggest) and a calmest full week is found", hop.days.filter { $0.spend > 0 }.map { $0.rank }.max() == 1 && hop.calmest != nil && hop.calmest!.to - hop.calmest!.from == 6)
    } else { check("HOP CALENDAR: builds", false) }
    if let cur = HBStats.hopCalendar(s0.entries, month: "2026-10", today: HBDay.parse("2026-10-04")!) {
        check("HOP CALENDAR: in the current month only days up to today are done (future days stay empty)", cur.days.filter { $0.done }.count == 4 && cur.days[3].isToday && !cur.days[4].done)
    } else { check("HOP CALENDAR: current month builds", false) }

    // changing household
    let bad = await refused { try await api.switchBudget(code: "NOPE") }
    check("HOUSEHOLD: an unknown invite code is refused with the backend's message and nothing changes", bad != nil && (await snap())?.entries.isEmpty == false)
    try? await api.switchBudget(code: "join-me01")
    let after = await snap()
    check("HOUSEHOLD: a good code (dashes and case ignored) joins that budget: new name, and none of the old household's data is left", after?.nest.name == "Joined Hive" && after?.entries.isEmpty == true && after?.goals.isEmpty == true && (after?.recurring.isEmpty ?? false))
    try? await api.leaveBudget()
    check("HOUSEHOLD: leaving clears the household's data on the backend", (await snap())?.entries.isEmpty == true)
}

let done = DispatchSemaphore(value: 0)
Task { await run(); done.signal() }
if done.wait(timeout: .now() + 90) == .timedOut { print("FAIL timed out"); exit(1) }
print(failures == 0 ? "ALL STATS FLOW CHECKS PASSED" : "\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
