import Foundation

// Drives the Inbox through the app's REAL data path (HBAPI -> URLSession -> JSON -> decoders -> HBInbox logic) against the in-process stand-in
// backend (HBMockServer, which follows src/worker.js; the real worker is checked separately by api-contract.mjs). Run by CI on macOS.
var failures = 0
func check(_ name: String, _ ok: Bool) { print((ok ? "PASS " : "FAIL ") + name); if !ok { failures += 1 } }

func run() async {
    let api = HBAPI.shared
    func snap() async -> HBNestSnapshot? { try? await api.nest(month: HBDay.monthKey()) }
    func refused(_ work: () async throws -> Void) async -> String? { do { try await work(); return nil } catch { return (error as? HBAPIError)?.errorDescription ?? "\(error)" } }
    let today = HBDay.todayString

    // ---------- a full inbox ----------
    HBMockServer.install(seed: "inbox")
    var s = await snap()
    var msgs = (try? await api.inbox()) ?? []
    check("INBOX: 13 messages load, 6 unread, and the badge count from /api/nest says 6", msgs.count == 13 && msgs.filter { $0.isUnread }.count == 6 && s?.inbox?.unread == 6)
    check("INBOX: loading it twice gives the same list (nothing is consumed by reading)", ((try? await api.inbox()) ?? []).count == 13)
    let byTab = Dictionary(grouping: msgs, by: { HBInbox.tab(for: $0.kind) })
    let nBills = byTab[.bills]?.count ?? 0, nShared = byTab[.shared]?.count ?? 0, nUpdates = byTab[.updates]?.count ?? 0
    check("INBOX: tabs split the messages (Bills 5 incl. the carry question and the budget warning, Shared 2, Updates 6)", nBills == 5 && nShared == 2 && nUpdates == 6)
    let groups = HBInbox.groups(msgs)
    check("INBOX: grouped newest-first by day, starting with Today", groups.first?.title == "Today" && groups.count >= 3)
    check("INBOX: every message has text and a heading", msgs.allSatisfy { !HBInbox.text($0, today: today, categoryName: { HBCategory.of($0).label }).isEmpty && !HBInbox.heading(for: $0.kind).isEmpty })

    // the bill messages
    let billToday = msgs.first { $0.kind == "bill_today" }, billLate = msgs.first { $0.kind == "bill_late" }, billSoon = msgs.first { $0.kind == "bill_soon" }
    check("BILLS: today / overdue / upcoming read right", [billToday, billLate, billSoon].allSatisfy { $0 != nil }
          && HBInbox.text(billToday!, today: today, categoryName: { $0 }).contains("is due today")
          && HBInbox.text(billLate!, today: today, categoryName: { $0 }).contains("was due")
          && HBInbox.text(billSoon!, today: today, categoryName: { $0 }).contains("is due in 2 days"))
    let exists = { (id: String) in s?.recurring.contains { $0.id == id } ?? false }
    let a1 = billToday.flatMap { HBInbox.action(for: $0, recurringExists: exists, carryPending: false) }
    check("BILLS: the bill due today offers Paid", { if case .markPaid(_, _, "Paid")? = a1 { return true } else { return false } }())
    let entriesBefore = s?.entries.count ?? 0
    if case let .markPaid(rid, occ, _)? = a1 {
        check("PAID: before tapping, the occurrence is not logged", !(s?.logged.contains { $0.recurring_id == rid && $0.occ_date == occ } ?? true))
        check("PAID: tapping Paid succeeds", await refused({ try await api.logOccurrence(recurringID: rid, date: occ) }) == nil)
        s = await snap()
        check("PAID: the occurrence is now logged (the card turns into \"Paid ✓\") and a real expense was created", (s?.logged.contains { $0.recurring_id == rid && $0.occ_date == occ } ?? false) && (s?.entries.count ?? 0) == entriesBefore + 1 && s?.entries.first?.recurring_id == rid)
        let again: String? = await refused({ try await api.logOccurrence(recurringID: rid, date: occ) })
        let countAfter = (await snap())?.entries.count ?? 0
        check("PAID: tapping it again does not double-log", again == nil && countAfter == entriesBefore + 1)
    } else { check("PAID: found the Paid action", false) }
    check("PAID: a bill that no longer exists has no button", billLate.flatMap { HBInbox.action(for: $0, recurringExists: { _ in false }, carryPending: false) } == nil)

    // buttons that route
    func act(_ kind: String) -> HBInboxAction? { msgs.first { $0.kind == kind }.flatMap { HBInbox.action(for: $0, recurringExists: exists, carryPending: s?.carry_pending != nil) } }
    check("ROUTING: budget → Money, week → Money, goal reached → Goals, level → Home, shared → Together, streak → Add Expense",
          act("budget_warn") == .openMoney("See Money") && act("week") == .openMoney("See stats") && act("goal_done") == .openGoals("See goals") && act("level") == .openHome("See my bunny")
          && act("shared_expense") == .openTogether("Open Together") && act("settled") == .openTogether("Open Together") && act("streak_risk") == .logSomething)
    check("ROUTING: only gift-card messages hand over to Classic (no native Refer screen yet)", act("ref_intro") == .classic("Get my link") && act("welcome") == nil)
    check("ROUTING: the carry-over question opens the native sheet while it is pending", act("carry_ask") == .decideCarry)

    // carry over
    check("CARRY: the snapshot has the pending question (September, $124.50)", s?.carry_pending?.from == "2026-09" && s?.carry_pending?.amount_cents == 12450)
    check("CARRY: Carry it over succeeds", await refused({ try await api.decideCarry(month: HBDay.monthKey(), accept: true, remember: false) }) == nil)
    s = await snap()
    check("CARRY: the question is gone and carry_in is $124.50 accepted (Home and Money pick this up from the snapshot)", s?.carry_pending == nil && s?.carry_in?.accepted == true && s?.carry_in?.amount_cents == 12450)
    check("CARRY: the Decide button disappears once decided", msgs.first { $0.kind == "carry_ask" }.flatMap { HBInbox.action(for: $0, recurringExists: exists, carryPending: s?.carry_pending != nil) } == nil)
    let carryAgain: String? = await refused({ try await api.decideCarry(month: HBDay.monthKey(), accept: false, remember: false) })
    let carryStill = (await snap())?.carry_in?.accepted
    check("CARRY: deciding again is harmless", carryAgain == nil && carryStill == true)

    // reading
    check("READ: marking read succeeds", await refused({ try await api.markInboxRead() }) == nil)
    msgs = (try? await api.inbox()) ?? []
    s = await snap()
    check("READ: all 13 are read, the badge is 0", msgs.count == 13 && msgs.allSatisfy { !$0.isUnread } && s?.inbox?.unread == 0)
    check("READ: marking read twice is harmless", await refused({ try await api.markInboxRead() }) == nil)

    // ---------- an empty inbox ----------
    HBMockServer.install(seed: "inboxempty")
    s = await snap()
    msgs = (try? await api.inbox()) ?? []
    check("EMPTY: no messages, badge 0, no carry question → the \"No messages yet\" state", msgs.isEmpty && (s?.inbox?.unread ?? 0) == 0 && s?.carry_pending == nil)
    check("EMPTY: grouping an empty list gives no sections", HBInbox.groups([]).isEmpty)
}

let done = DispatchSemaphore(value: 0)
Task { await run(); done.signal() }
if done.wait(timeout: .now() + 60) == .timedOut { print("FAIL timed out"); exit(1) }
print(failures == 0 ? "ALL INBOX FLOW CHECKS PASSED" : "\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
