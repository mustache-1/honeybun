import Foundation

// Drives every Together action through the app's REAL data path (HBAPI -> URLSession -> JSON -> HBNestSnapshot decoder -> HBTogether logic)
// against the in-process stand-in backend (HBMockServer, which follows src/worker.js, itself checked against the real worker by api-contract.mjs).
// It checks the numbers and states the screens would show after each step for Solo, Partner, Family and Joint accounts. Run by CI on macOS.
var failures = 0
func check(_ name: String, _ ok: Bool) { print((ok ? "PASS " : "FAIL ") + name); if !ok { failures += 1 } }

func run() async {
    let api = HBAPI.shared
    func snap() async -> HBNestSnapshot? { try? await api.nest(month: "2026-09") }
    func refused(_ work: () async throws -> Void) async -> String? { do { try await work(); return nil } catch { return (error as? HBAPIError)?.errorDescription ?? "\(error)" } }

    // ---------- Partner ----------
    HBMockServer.install(seed: "partner")
    var s = await snap()
    guard let me = s?.me?.id, let riley = s?.members.first(where: { $0.id != s?.me?.id })?.id else { print("FAIL partner seed"); exit(1) }
    check("PARTNER: two members, couple budget, not joint, invite code present", s?.members.count == 2 && s?.nest.kind == "couple" && s?.nest.joint == 0 && !(s?.nest.invite_code ?? "").isEmpty)
    check("PARTNER: situation is partner", HBTogether.situation(memberCount: s?.members.count ?? 0) == .partner)
    var pairs = HBTogether.pairs(members: s?.members ?? [], balances: s?.balances ?? [:])
    check("PARTNER: Riley owes me $42.50 (You owe $0 / Riley owes $42.50)", pairs.count == 1 && pairs[0].from.id == riley && pairs[0].to.id == me && pairs[0].amount == 42.5)
    check("PARTNER: payment history lists 2 payments, newest first", s?.settlements?.count == 2 && s?.settlements?.first?.amount == 60)

    // settle up part of it
    if let m = await refused({ try await api.settle(from: riley, to: me, amount: 20, date: "2026-10-04") }) { check("settle (\(m))", false) }
    s = await snap()
    pairs = HBTogether.pairs(members: s?.members ?? [], balances: s?.balances ?? [:])
    check("SETTLE $20: balance drops to $22.50, history has 3 rows with the new one first", pairs.first?.amount == 22.5 && s?.settlements?.count == 3 && s?.settlements?.first?.amount == 20 && s?.settlements?.first?.from_id == riley)
    // remove that payment again
    if let id = s?.settlements?.first?.id { _ = await refused({ try await api.deleteSettlement(id: id) }) }
    s = await snap()
    pairs = HBTogether.pairs(members: s?.members ?? [], balances: s?.balances ?? [:])
    check("REMOVE PAYMENT: balance goes back to $42.50, history back to 2 rows", pairs.first?.amount == 42.5 && s?.settlements?.count == 2)
    // settle in full -> all even
    _ = await refused({ try await api.settle(from: riley, to: me, amount: 42.5, date: "2026-10-04") })
    s = await snap()
    check("SETTLE IN FULL: nobody owes anything (\"You're all even\")", HBTogether.pairs(members: s?.members ?? [], balances: s?.balances ?? [:]).isEmpty)
    // overpay flips the direction
    _ = await refused({ try await api.settle(from: riley, to: me, amount: 10, date: "2026-10-04") })
    s = await snap()
    pairs = HBTogether.pairs(members: s?.members ?? [], balances: s?.balances ?? [:])
    check("OVERPAY $10: now I owe Riley $10", pairs.count == 1 && pairs[0].from.id == me && pairs[0].to.id == riley && pairs[0].amount == 10)
    check("SETTLE with yourself is refused", await refused({ try await api.settle(from: me, to: me, amount: 5, date: "2026-10-04") }) != nil)
    check("SETTLE $0 is refused", await refused({ try await api.settle(from: riley, to: me, amount: 0, date: "2026-10-04") }) != nil)

    // shopping list
    var list = (try? await api.shopping()) ?? []
    check("SHOPPING: list loads (4 open, 1 ticked)", list.count == 5 && list.filter { !$0.done }.count == 4 && list.filter { $0.done }.count == 1)
    _ = await refused({ try await api.addShopItem("Tea") })
    list = (try? await api.shopping()) ?? []
    check("SHOPPING: adding \"Tea\" puts it with the open items, above the ticked one", list.count == 6 && list[4].label == "Tea" && list.last?.done == true)
    check("SHOPPING: a blank item is refused", await refused({ try await api.addShopItem("   ") }) != nil)
    if let tea = list.first(where: { $0.label == "Tea" }) {
        _ = await refused({ try await api.setShopDone(id: tea.id, done: true) })
        list = (try? await api.shopping()) ?? []
        check("SHOPPING: ticking Tea moves it to the ticked group", list.filter { $0.done }.count == 2 && list.last?.label == "Tea" && list.last?.done_by == me)
        _ = await refused({ try await api.renameShopItem(id: tea.id, label: "Green tea") })
        list = (try? await api.shopping()) ?? []
        check("SHOPPING: renaming keeps it ticked", list.first(where: { $0.id == tea.id })?.label == "Green tea" && list.first(where: { $0.id == tea.id })?.done == true)
        _ = await refused({ try await api.setShopDone(id: tea.id, done: false) })
        list = (try? await api.shopping()) ?? []
        check("SHOPPING: unticking puts it back among the open items", list.first(where: { $0.id == tea.id })?.done == false && list.filter { $0.done }.count == 1)
        _ = await refused({ try await api.deleteShopItem(id: tea.id) })
        list = (try? await api.shopping()) ?? []
        check("SHOPPING: deleting removes it", !list.contains { $0.id == tea.id } && list.count == 5)
    }
    _ = await refused({ try await api.clearShopDone() })
    list = (try? await api.shopping()) ?? []
    check("SHOPPING: \"Clear checked items\" leaves only open ones", list.count == 4 && list.allSatisfy { !$0.done })
    if let first = list.first { _ = await refused({ try await api.setShopDone(id: first.id, done: true) }) }
    let entriesBefore = (await snap())?.entries.count ?? 0
    check("SHOPPING: checkout with $0 is refused", await refused({ try await api.shopCheckout(amount: 0, date: "2026-10-04") }) != nil)
    _ = await refused({ try await api.shopCheckout(amount: 30, date: "2026-10-04") })
    s = await snap(); list = (try? await api.shopping()) ?? []
    check("SHOPPING: \"Done shopping\" logs a $30 shared groceries expense and clears the ticked items", (s?.entries.count ?? 0) == entriesBefore + 1 && s?.entries.first?.amount_cents == 3000 && s?.entries.first?.category == "groc" && s?.entries.first?.shared == 1 && list.count == 3)
    pairs = HBTogether.pairs(members: s?.members ?? [], balances: s?.balances ?? [:])
    check("SHOPPING: and the equal split moved the balance ($15 toward me: now Riley owes me $5)", pairs.count == 1 && pairs[0].from.id == riley && pairs[0].to.id == me && pairs[0].amount == 5)

    // household: invite code, name, type, joint, edit yourself
    let code0 = s?.nest.invite_code ?? ""
    _ = await refused({ _ = try await api.newInviteCode() })
    s = await snap()
    check("INVITE: a new code replaces the old one", !(s?.nest.invite_code ?? "").isEmpty && s?.nest.invite_code != code0 && (s?.nest.invite_code ?? "").count == 8)
    _ = await refused({ try await api.patchNest(["name": "Our Hive"]) })
    s = await snap()
    check("BUDGET NAME: renamed", s?.nest.name == "Our Hive")
    _ = await refused({ try await api.patchNest(["joint": true]) })
    s = await snap()
    check("JOINT ON (couple, 2 people): the card switches to Came in / Spent", HBTogether.isJoint(kind: s?.nest.kind, joint: s?.nest.joint, memberCount: s?.members.count ?? 0) && HBTogether.pairs(members: s?.members ?? [], balances: [:]).isEmpty)
    _ = await refused({ try await api.patchNest(["joint": false]) })
    _ = await refused({ try await api.patchNest(["kind": "family"]) })
    check("JOINT is refused for a family budget", await refused({ try await api.patchNest(["joint": true]) }) != nil)
    s = await snap()
    check("FAMILY TYPE: wording changes but a 2-person budget is still the partner layout", s?.nest.kind == "family" && HBTogether.situation(memberCount: s?.members.count ?? 0) == .partner && !HBTogether.isJoint(kind: s?.nest.kind, joint: s?.nest.joint, memberCount: 2))
    check("TYPE: an unknown type is refused", await refused({ try await api.patchNest(["kind": "pirate"]) }) != nil)
    _ = await refused({ try await api.updateMe(name: "Alex", emoji: "🐼", color: "#E4EDFF") })
    s = await snap()
    let mine = s?.members.first { $0.id == me }
    check("EDIT YOURSELF: name, buddy and colour saved (buddy artwork HBBuddy_angel)", mine?.name == "Alex" && mine?.emoji == "🐼" && mine?.color == "#E4EDFF" && HBTogether.buddyAsset(mine?.emoji) == "HBBuddy_angel" && s?.me?.name == "Alex")
    check("EDIT YOURSELF: a buddy that doesn't exist is refused", await refused({ try await api.updateMe(name: "Alex", emoji: "🤖", color: "#E4EDFF") }) != nil)
    check("EDIT YOURSELF: an empty name is refused", await refused({ try await api.updateMe(name: "  ", emoji: "🐼", color: "#E4EDFF") }) != nil)

    // search
    let found = (try? await api.search(q: "", type: "income", member: "")) ?? []
    check("SEARCH: filter by type returns only income", !found.isEmpty && found.allSatisfy { $0.isIncome })
    let byWho = (try? await api.search(q: "", type: "", member: riley)) ?? []
    check("SEARCH: filter by person returns only that person's entries", !byWho.isEmpty && byWho.allSatisfy { $0.member_id == riley })
    let none = (try? await api.search(q: "zzz-nothing", type: "", member: "")) ?? [HBEntry]()
    check("SEARCH: no match → empty (screen shows \"Nothing matches that.\")", none.isEmpty)

    // ---------- Solo ----------
    HBMockServer.install(seed: "solo")
    s = await snap()
    check("SOLO: one member, solo layout, invite code ready, no payments", s?.members.count == 1 && HBTogether.situation(memberCount: 1) == .solo && !(s?.nest.invite_code ?? "").isEmpty && (s?.settlements ?? []).isEmpty)
    check("SOLO: nothing owed either way", HBTogether.pairs(members: s?.members ?? [], balances: s?.balances ?? [:]).isEmpty)
    _ = await refused({ try await api.addShopItem("Bread") })
    list = (try? await api.shopping()) ?? []
    check("SOLO: the shopping list still works on your own", list.contains { $0.label == "Bread" })
    _ = await refused({ try await api.shopCheckout(amount: 12, date: "2026-10-04") })
    check("SOLO: nothing is split when you are alone", (await snap())?.entries.first?.shared == 0)
    check("SOLO: Joint account can't be switched on for one person's solo budget", await refused({ try await api.patchNest(["joint": true]) }) != nil)

    // ---------- Family ----------
    HBMockServer.install(seed: "family")
    s = await snap()
    check("FAMILY: three members, family layout", s?.members.count == 3 && HBTogether.situation(memberCount: 3) == .family && s?.nest.kind == "family")
    pairs = HBTogether.pairs(members: s?.members ?? [], balances: s?.balances ?? [:])
    let meF = s?.me?.id ?? ""
    check("FAMILY: I owe $12 to the one who is owed; the other owes $18 (two rows, \"Mark paid\" on each)", pairs.count == 2 && pairs[0].from.id == meF && pairs[0].amount == 12 && pairs[1].amount == 18 && pairs[0].to.id == pairs[1].to.id)
    if let p = pairs.first { _ = await refused({ try await api.settle(from: p.from.id, to: p.to.id, amount: p.amount, date: "2026-10-04") }) }
    s = await snap()
    pairs = HBTogether.pairs(members: s?.members ?? [], balances: s?.balances ?? [:])
    check("FAMILY: marking my $12 paid leaves just the other $18", pairs.count == 1 && pairs[0].amount == 18 && pairs[0].from.id != meF)
    let totals = HBTogether.totals(members: s?.members ?? [], entries: s?.entries ?? [])
    check("FAMILY: fair share lists all three people with their own totals", totals.count == 3 && totals.reduce(0) { $0 + $1.spent } > 0)

    // ---------- Joint couple ----------
    HBMockServer.install(seed: "joint")
    s = await snap()
    check("JOINT: couple with the joint account on → Came in / Spent card, no payments or balances", HBTogether.isJoint(kind: s?.nest.kind, joint: s?.nest.joint, memberCount: s?.members.count ?? 0))
}

let done = DispatchSemaphore(value: 0)
Task { await run(); done.signal() }
if done.wait(timeout: .now() + 60) == .timedOut { print("FAIL timed out"); exit(1) }
print(failures == 0 ? "ALL TOGETHER FLOW CHECKS PASSED" : "\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
