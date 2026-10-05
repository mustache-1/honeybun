import Foundation

// Phase 5.4: the offline entry queue, the last-known cache, search filters, "Heads up from Bun", the email reminder rules and the level bunny's
// outfit rules — through the app's REAL code (HBAPI -> URLSession -> the in-process stand-in backend -> decoder), compiled and run by CI on macOS.
var failures = 0
func check(_ name: String, _ ok: Bool) { print((ok ? "PASS " : "FAIL ") + name); if !ok { failures += 1 } }

func tmp(_ name: String) -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("hb-\(UUID().uuidString)-\(name)") }

func snapshot(_ edit: (inout [String: Any]) -> Void) -> HBNestSnapshot? {
    guard var d = (try? JSONSerialization.jsonObject(with: Data(HBPreviewData.json.utf8))) as? [String: Any] else { return nil }
    edit(&d)
    guard let data = try? JSONSerialization.data(withJSONObject: d) else { return nil }
    return try? JSONDecoder().decode(HBNestSnapshot.self, from: data)
}
func user(_ json: String) -> HBUser? { try? JSONDecoder().decode(HBUser.self, from: Data(json.utf8)) }

func run() async {
    HBMockServer.install(seed: "default")
    HBOfflineCache.shared.clear()
    let api = HBAPI.shared
    let me = "e13d46b3-b063-4599-afc3-c5d9b5feb2b2"
    func serverEntries() async -> [HBEntry] { (try? await api.nest(month: "2026-09").entries) ?? [] }
    let baseline = await serverEntries().count

    // ---- the queue: durable, ordered, every field kept
    let file = tmp("pending.json")
    var q = HBPendingQueue(fileURL: file)
    var d = HBEntryDraft(type: "expense", amount: 12.34, label: "Offline coffee", category: "food", shared: true, date: "2026-09-21", memberID: me)
    d.splitMode = "owed"; d.splitValue = 5.5; d.isPrivate = true
    let item = try? await q.add(d, user: "userA", nest: "nestN")
    check("QUEUE: an entry made offline is written to disk immediately", item != nil && FileManager.default.fileExists(atPath: file.path))
    q = HBPendingQueue(fileURL: file)         // "force-close and reopen the app": a brand-new queue object reading the same file
    let reopened = await q.items(user: "userA", nest: "nestN")
    check("QUEUE: after a restart it is still waiting, with every field intact (amount, label, category, date, member, shared, split, private)",
          reopened.count == 1 && reopened[0].draft == d && reopened[0].clientID == item?.clientID && reopened[0].failure == nil)
    check("QUEUE: the entry shows in lists as waiting (pending flag, same amount/label/date/category)",
          reopened[0].asEntry.pending && reopened[0].asEntry.amount_cents == 1234 && reopened[0].asEntry.label == "Offline coffee" && reopened[0].asEntry.category == "food" && reopened[0].asEntry.date == "2026-09-21" && reopened[0].asEntry.shared == 1 && reopened[0].asEntry.isPrivate == 1 && reopened[0].asEntry.split_value == 550)

    // ---- offline: the real request really fails the way a phone with no connection does, and that counts as "save it for later"
    HBMockServer.offline = true
    var offlineError: Error? = nil
    do { _ = try await api.addEntry(d, clientID: reopened[0].clientID) } catch { offlineError = error }
    check("OFFLINE: saving with no connection fails with a connection error, which the app treats as queue-it", offlineError is URLError && HBPendingRules.shouldQueue(offlineError!))
    var sentWhileOffline = 0
    let offlineRun = await q.flush(user: "userA", nest: "nestN") { i in sentWhileOffline += 1; _ = try await api.addEntry(i.draft, clientID: i.clientID) }
    let _aw0 = await q.items(user: "userA", nest: "nestN")
    check("OFFLINE: a sync attempt with no connection stops cleanly and keeps the entry waiting (nothing lost)", offlineRun.stoppedOffline && offlineRun.sent == 0 && sentWhileOffline == 1 && _aw0.count == 1)
    var cachedWhileOffline = false
    HBMockServer.offline = false
    // ---- the last-known cache: online answers are kept; with no connection the same numbers come back (marked as cached)
    if let online = try? await api.nestOrCached(month: "2026-09") {
        check("CACHE: an online answer is not marked as cached", !online.cached && online.snapshot.entries.count == baseline)
        HBMockServer.offline = true
        if let off = try? await api.nestOrCached(month: "2026-09") { cachedWhileOffline = off.cached && off.snapshot.entries.count == baseline && off.snapshot.me?.id == me }
        HBMockServer.offline = false
    }
    check("CACHE: with no connection the last good numbers load from the phone (so the app can open offline)", cachedWhileOffline)
    HBMockServer.offline = true
    let uncachedMonth = try? await api.nestOrCached(month: "2020-01")
    HBMockServer.offline = false
    check("CACHE: a month that was never loaded is not invented offline (it fails with a connection error)", uncachedMonth == nil)
    check("CACHE: it belongs to the account that saved it, and is wiped on logout", HBOfflineCache.shared.owner == me && { HBOfflineCache.shared.clear(); return HBOfflineCache.shared.load("/api/nest?month=2026-09") == nil && HBOfflineCache.shared.owner == nil }())
    let cacheFile = tmp("cache.json"); let c2 = HBOfflineCache(fileURL: cacheFile)
    c2.save("/api/me", Data("A".utf8), owner: "userA"); c2.save("/api/me", Data("B".utf8), owner: "userB")
    check("CACHE: another account's save replaces the first account's answers (never mixed)", c2.owner == "userB" && c2.load("/api/me") == Data("B".utf8))

    // ---- reconnect: sends exactly once, with every field
    HBMockServer.entryBodies = []
    let online = await q.flush(user: "userA", nest: "nestN") { i in _ = try await api.addEntry(i.draft, clientID: i.clientID) }
    let after = await serverEntries()
    let landed = after.filter { $0.id == reopened[0].clientID }
    let _aw1 = await q.items(user: "userA", nest: "nestN")
    check("SYNC: back online, the waiting entry is sent and removed from the queue", online.sent == 1 && _aw1.isEmpty)
    check("SYNC: it reaches the server exactly once, under its client id", landed.count == 1 && after.count == baseline + 1)
    let body = HBMockServer.entryBodies.last ?? [:]
    check("SYNC: nothing was dropped on the way (type, amount, label, category, date, member, shared, split, private, client_id)",
          body["type"] as? String == "expense" && body["amount"] as? Double == 12.34 && body["label"] as? String == "Offline coffee" && body["category"] as? String == "food" && body["date"] as? String == "2026-09-21"
          && body["member_id"] as? String == me && body["shared"] as? Bool == true && body["split_mode"] as? String == "owed" && body["split_value"] as? Double == 5.5 && body["private"] as? Bool == true && body["client_id"] as? String == reopened[0].clientID)

    // ---- duplicates: a retry after a lost answer adds nothing
    HBMockServer.entryBodies = []
    _ = try? await api.addEntry(d, clientID: reopened[0].clientID)
    _ = try? await api.addEntry(d, clientID: reopened[0].clientID)
    let _aw2 = await serverEntries()
    let _aw3 = await serverEntries()
    check("DUPLICATES: sending the same entry again (answer lost, app restarted) does not add it twice", _aw2.filter { $0.id == reopened[0].clientID }.count == 1 && _aw3.count == baseline + 1)
    _ = try? await q.add(d, user: "userA", nest: "nestN", clientID: reopened[0].clientID)
    let dup = await q.flush(user: "userA", nest: "nestN") { i in _ = try await api.addEntry(i.draft, clientID: i.clientID) }
    let _aw4 = await serverEntries()
    let _aw5 = await q.all()
    check("DUPLICATES: a queued copy of an entry the server already has is recognised and cleared, not added again", dup.sent == 1 && _aw4.count == baseline + 1 && _aw5.isEmpty)
    let again = try? await q.add(d, user: "userA", nest: "nestN", clientID: "fixed-id"); let again2 = try? await q.add(d, user: "userA", nest: "nestN", clientID: "fixed-id")
    let _aw6 = await q.items(user: "userA", nest: "nestN")
    check("DUPLICATES: queueing the same client id twice keeps one copy", again?.clientID == again2?.clientID && _aw6.count == 1)
    await q.remove("fixed-id")

    // ---- a failed server request stays retryable
    var d2 = HBEntryDraft(type: "income", amount: 20, label: "Gift", date: "2026-09-22", memberID: me)
    d2.category = "other"
    _ = try? await q.add(d2, user: "userA", nest: "nestN", clientID: "retry-1")
    HBMockServer.failEntryPosts = (1, 503)
    let r1 = await q.flush(user: "userA", nest: "nestN") { i in _ = try await api.addEntry(i.draft, clientID: i.clientID) }
    let kept = (await q.all()).first
    check("RETRY: a server error (503) stops the run, keeps the entry, and counts the attempt", r1.stoppedOffline && r1.sent == 0 && kept?.attempts == 1 && kept?.failure == nil)
    let r2 = await q.flush(user: "userA", nest: "nestN") { i in _ = try await api.addEntry(i.draft, clientID: i.clientID) }
    let _aw7 = await q.all()
    let _aw8 = await serverEntries()
    check("RETRY: the next try sends it", r2.sent == 1 && _aw7.isEmpty && _aw8.filter { $0.id == "retry-1" }.count == 1)
    _ = try? await q.add(d2, user: "userA", nest: "nestN", clientID: "refused-1")
    HBMockServer.failEntryPosts = (1, 422)
    let r3 = await q.flush(user: "userA", nest: "nestN") { i in _ = try await api.addEntry(i.draft, clientID: i.clientID) }
    let refused = (await q.all()).first
    check("REFUSED: when the server refuses an entry (a 4xx) it is KEPT with the reason, not silently dropped (the website drops these)", r3.rejected == 1 && refused?.failure != nil && refused?.clientID == "refused-1")
    let sentBefore = HBMockServer.entryPostsReceived
    let r4 = await q.flush(user: "userA", nest: "nestN") { i in _ = try await api.addEntry(i.draft, clientID: i.clientID) }
    check("REFUSED: it is not retried automatically over and over", r4.sent == 0 && HBMockServer.entryPostsReceived == sentBefore)
    await q.clearFailure("refused-1")
    let r5 = await q.flush(user: "userA", nest: "nestN") { i in _ = try await api.addEntry(i.draft, clientID: i.clientID) }
    let _aw9 = await q.all()
    check("REFUSED: after \"Try again\" it is sent", r5.sent == 1 && _aw9.isEmpty)
    check("CLASSIFY: connection problems, timeouts, 408/429/5xx and an expired sign-in are retried later; other 4xx are refusals",
          HBPendingRules.classify(URLError(.notConnectedToInternet)) == .retryLater && HBPendingRules.classify(URLError(.timedOut)) == .retryLater
          && HBPendingRules.classify(HBAPIError.http(503, "x")) == .retryLater && HBPendingRules.classify(HBAPIError.http(429, "x")) == .retryLater && HBPendingRules.classify(HBAPIError.http(408, "x")) == .retryLater
          && HBPendingRules.classify(HBAPIError.notSignedIn) == .retryLater && HBPendingRules.classify(HBAPIError.http(400, "no")) == .rejected("no") && HBPendingRules.classify(HBAPIError.http(409, "dup")) == .rejected("dup"))

    // ---- accounts and budgets never mix
    _ = try? await q.add(d2, user: "userA", nest: "nestN", clientID: "iso-1")
    var leaked = 0
    let asB = await q.flush(user: "userB", nest: "nestN") { _ in leaked += 1 }
    let otherNest = await q.flush(user: "userA", nest: "nestOther") { _ in leaked += 1 }
    let _aw10 = await q.items(user: "userB", nest: "nestN")
    let _aw11 = await q.count(user: "userB")
    check("ISOLATION: another account signing in on this phone sends nothing of the first account's, and never sees it", asB.sent == 0 && leaked == 0 && _aw10.isEmpty && _aw11 == 0)
    check("ISOLATION: the same account in a different budget does not send it either", otherNest.sent == 0 && leaked == 0)
    let _aw12 = await q.items(user: "userA", nest: "nestN")
    let _aw13 = await q.count(user: "userA")
    check("ISOLATION: logging out keeps it (nothing destroyed), and it is still there for the owner", _aw12.count == 1 && _aw13 == 1)
    let ownFile = HBPendingQueue(fileURL: file)
    let _aw14 = await ownFile.items(user: "userA", nest: "nestN")
    check("ISOLATION: it survives a restart for the owner", _aw14.first?.clientID == "iso-1")
    await q.removeAll(user: "userB")
    let _aw15 = await q.count(user: "userA")
    check("DELETE ACCOUNT: removing one account's entries leaves other accounts' alone", _aw15 == 1)
    await q.removeAll(user: "userA")
    let _aw16 = await q.all()
    check("DELETE ACCOUNT: removing the account's own entries empties them", _aw16.isEmpty)
    let corrupt = tmp("bad.json"); try? Data("not json".utf8).write(to: corrupt)
    let cq = HBPendingQueue(fileURL: corrupt)
    let _aw17 = await cq.all()
    check("QUEUE: an unreadable file is set aside (not deleted) and the queue starts empty", _aw17.isEmpty && !FileManager.default.fileExists(atPath: corrupt.path))
    let unwritable = HBPendingQueue(fileURL: URL(fileURLWithPath: "/nonexistent-dir-hb/x/pending.json"))
    var writeFailed = false
    do { _ = try await unwritable.add(d, user: "u", nest: "n") } catch { writeFailed = true }
    let _aw18 = await unwritable.all()
    check("QUEUE: if the phone cannot write the entry to disk, adding FAILS (the app never claims it is safe when it is not)", writeFailed && _aw18.isEmpty)

    // ---- search filters against the backend's own rules (on a fresh copy of the sample data, without the test entries added above)
    HBMockServer.install(seed: "default")
    func found(_ f: HBSearchFilter) async -> [HBEntry] { (try? await api.search(f)) ?? [] }
    var f = HBSearchFilter(); f.category = "food"
    let foodN = (await found(f)).count
    let _aw19 = await found(f)
    check("FILTERS: category alone (Eating out) finds only that category (10 of them)", foodN == 10 && _aw19.allSatisfy { $0.category == "food" })
    f.minAmount = 50; f.maxAmount = 90
    let ranged = await found(f)
    check("FILTERS: category + $50–$90 finds Bakery, Farmers market, Sushi night, Dinner out", Set(ranged.map { $0.label }) == ["Bakery", "Farmers market", "Sushi night", "Dinner out"])
    f.from = "2026-09-10"; f.to = "2026-09-27"
    let _aw20 = await found(f)
    check("FILTERS: category + amount range + date range (Sep 10–27) narrows to Bakery, Farmers market, Sushi night", Set(_aw20.map { $0.label }) == ["Bakery", "Farmers market", "Sushi night"])
    f.q = "sushi"
    let _aw21 = await found(f)
    check("FILTERS: text + category + amount + dates all apply together (Sushi night only)", _aw21.map { $0.label } == ["Sushi night"])
    var onlyDates = HBSearchFilter(); onlyDates.from = "2026-09-28"; onlyDates.to = "2026-09-29"
    let _aw22 = await found(onlyDates)
    check("FILTERS: a date range alone works (Sep 28–29 has Repairs and Insurance)", Set(_aw22.map { $0.label }) == ["Repairs", "Insurance"])
    var onlyMin = HBSearchFilter(); onlyMin.minAmount = 120
    let _aw23 = await found(onlyMin)
    check("FILTERS: a minimum alone works (≥ $120: Misc, Concert, Target, Paycheck)", Set(_aw23.map { $0.label }) == ["Misc", "Concert", "Target", "Paycheck"])
    var onlyMax = HBSearchFilter(); onlyMax.maxAmount = 20
    let _aw24 = await found(onlyMax)
    check("FILTERS: a maximum alone works (≤ $20: Chipotle)", _aw24.map { $0.label } == ["Chipotle"])
    var typed = HBSearchFilter(); typed.type = "income"
    let _aw25 = await found(typed)
    check("FILTERS: the existing type filter still works", _aw25.map { $0.label } == ["Paycheck"])
    var who = HBSearchFilter(); who.member = me; who.q = "pizza"
    let _aw26 = await found(who)
    check("FILTERS: the existing person + text filters still work", _aw26.map { $0.label } == ["Pizza"])
    check("FILTERS: Clear filters puts everything back to the defaults (nothing active)", { var x = f; x = HBSearchFilter(); return x.isDefault && x.activeCount == 0 && !x.hasCriteria && !f.isDefault && f.activeCount == 6 }())
    var bad = HBSearchFilter(); bad.minAmount = -5; bad.maxAmount = 0; bad.from = "not-a-date"; bad.category = "food"
    let names = bad.queryItems.map { $0.name }
    check("FILTERS: an invalid amount or date is never sent (the server would ignore it)", !names.contains("min") && !names.contains("max") && !names.contains("from") && names.contains("cat"))
    var back = HBSearchFilter(); back.from = "2026-09-20"; back.to = "2026-09-10"
    check("FILTERS: a backwards date range is noticed before asking", back.rangeBackwards && !HBSearchFilter().rangeBackwards)
    check("FILTERS: the query uses the backend's own parameter names", Set(f.queryItems.map { $0.name }) == ["q", "cat", "min", "max", "from", "to"] && f.queryItems.first { $0.name == "min" }?.value == "50")

    // ---- Heads up from Bun
    let today = HBDay.parse("2026-09-20")!
    func headsUp(_ s: HBNestSnapshot, seen: [String] = [], month: String = "2026-09", t: Date = today) -> HBHeadsUp {
        HBCatStyle.custom = s.categories ?? []
        let fc = HBPlan.forecast(s, month: month, today: t, myID: me)
        return HBHeadsUpRules.compute(s, month: month, me: s.members.first, today: t, seen: seen, forecast: fc)
    }
    let budgets: [[String: Any]] = [["category": "groc", "limit_cents": 50000], ["category": "food", "limit_cents": 53000], ["category": "fun", "limit_cents": 30000], ["category": "bills", "limit_cents": 40000]]
    if let s = snapshot({ $0["budgets"] = budgets }) {
        let h = headsUp(s)
        let budgetRows = h.rows.filter { if case .budget = $0.kind { return true }; return false }
        check("HEADS UP: budgets at 80% or more show, most-used first, top two only (Eating out over, then Bills)", budgetRows.count == 2 && budgetRows[0].id == "budget-food" && budgetRows[1].id == "budget-bills")
        check("HEADS UP: over budget reads \"Eating out: over budget\" with the overspend", budgetRows[0].title == "Eating out: over budget" && budgetRows[0].note == "$1 over · $531 of $530")
        check("HEADS UP: 85% reads \"85% of your budget used\" with dollars left per day (11 days left)", budgetRows[1].title == "85% of your budget used" && budgetRows[1].note.hasPrefix("$341 of $400") && budgetRows[1].note.hasSuffix("$5.35 a day left"))
        check("HEADS UP: a budget under 80% (Fun at 76%) is not shown", !h.rows.contains { $0.id == "budget-fun" })
        check("HEADS UP: the forecast line shows for this month (\"On pace to…\")", h.rows.contains { $0.id == "forecast" && $0.title.hasPrefix("On pace to") })
        let other = headsUp(s, month: "2026-08", t: HBDay.parse("2026-09-20")!)
        check("HEADS UP: no forecast line for another month", !other.rows.contains { $0.id == "forecast" })
    } else { check("HEADS UP: test data builds", false) }
    if let s = snapshot({ $0["budgets"] = [["category": "groc", "limit_cents": 52138]] }) {   // 41711 / 52138 = 80.0%
        let exactly = headsUp(s).rows.filter { if case .budget = $0.kind { return true }; return false }
        check("HEADS UP: exactly 80% counts", exactly.count == 1)
    }
    if let s = snapshot({ $0["budgets"] = [["category": "groc", "limit_cents": 52200]] }) {  // 79.9%
        check("HEADS UP: just under 80% does not", !headsUp(s).rows.contains { $0.id == "budget-groc" })
    }
    let discordKey = "af117dc2-532a-4615-b2d7-25e550c9b66b|999"
    func withPrices(_ edit: @escaping (inout [[String: Any]]) -> Void) -> HBNestSnapshot? {
        snapshot { d in var r = d["recurring"] as? [[String: Any]] ?? []; edit(&r); d["recurring"] = r }
    }
    if let s = withPrices({ r in
        r[0]["prev_amount_cents"] = 1299; r[0]["price_changed_at"] = "2026-09-10"            // Discord: dropped 10 days ago
        r[1]["prev_amount_cents"] = 1299; r[1]["price_changed_at"] = "2026-07-01"            // Netflix: went up, but long ago
    }) {
        let h = headsUp(s)
        let prices = h.rows.filter { $0.dismissKey != nil }
        check("PRICE ALERTS: a price drop in the last 30 days shows (\"dropped to\", \"It was\")", prices.count == 1 && prices[0].title == "Discord Nitro dropped to $9.99" && prices[0].note == "It was $12.99" && prices[0].kind == .priceDown)
        check("PRICE ALERTS: a change older than 30 days does not show", !prices.contains { $0.title.hasPrefix("Netflix") })
        check("PRICE ALERTS: dismissing remembers \"id|amount\" and hides it", headsUp(s, seen: [discordKey]).rows.filter { $0.dismissKey != nil }.isEmpty && prices[0].dismissKey == discordKey)
        let suite = UserDefaults(suiteName: "hb-test-\(UUID().uuidString)")!
        for i in 0..<45 { HBHeadsUpRules.dismiss("k\(i)|1", suite) }
        HBHeadsUpRules.dismiss(discordKey, suite)
        let kept = HBHeadsUpRules.seen(suite)
        check("PRICE ALERTS: dismissals persist and only the latest 40 are kept (like the website)", kept.count == 40 && kept.last == discordKey && HBHeadsUpRules.seen(UserDefaults(suiteName: "hb-test-other-\(UUID().uuidString)")!).isEmpty)
        check("PRICE ALERTS: a new price on the same bill alerts again (the key includes the amount)", headsUp(s, seen: ["af117dc2-532a-4615-b2d7-25e550c9b66b|1099"]).rows.contains { $0.dismissKey == discordKey })
    }
    if let s = withPrices({ r in
        r[0]["prev_amount_cents"] = 500; r[0]["price_changed_at"] = "2026-09-19"
        r[1]["prev_amount_cents"] = 1200; r[1]["price_changed_at"] = "2026-09-19"
    }) {
        let up = headsUp(s).rows.first { $0.id.hasPrefix("price-6c662d78") }
        check("PRICE ALERTS: a price rise reads \"is now\" and counts as an increase", up?.title == "Netflix is now $15.99" && up?.kind == .priceUp && up?.note == "It was $12.00")
    }
    for (last, expect, label) in [("2026-09-17", true, "3 quiet days"), ("2026-09-18", false, "2 days"), ("2026-09-01", true, "19 days")] {
        if let s = snapshot({ d in var m = d["members"] as? [[String: Any]] ?? []; m[0]["last_day"] = last; d["members"] = m }) {
            let h = headsUp(s)
            check("QUIET DAYS: last logged \(last) (\(label)) → Bun is sleepy: \(expect)", (h.sleepyDays != nil) == expect)
        }
    }
    if let s = snapshot({ d in var m = d["members"] as? [[String: Any]] ?? []; m[0]["last_day"] = "2026-09-17"; d["members"] = m }) {
        check("QUIET DAYS: the message counts the days (3)", headsUp(s).sleepyDays == 3)
        check("QUIET DAYS: not shown when looking at another month", headsUp(s, month: "2026-08").sleepyDays == nil)
    }
    check("HEADS UP: nothing to say shows nothing", { if let s = snapshot({ d in var m = d["members"] as? [[String: Any]] ?? []; m[0]["last_day"] = "2026-09-20"; d["members"] = m; d["entries"] = [] }) { return headsUp(s).isEmpty }; return false }())

    // ---- the email reminder on Home
    let suite = UserDefaults(suiteName: "hb-verify-\(UUID().uuidString)")!
    let t0 = Date(timeIntervalSince1970: 1_790_000_000)
    let unverified = user(#"{"id":"u","name":"A","verified":false,"has_email":true}"#), verified = user(#"{"id":"u","name":"A","verified":true,"has_email":true}"#)
    let noEmail = user(#"{"id":"u","name":"A","verified":false,"has_email":false}"#), unknown = user(#"{"id":"u","name":"A"}"#)
    check("EMAIL BANNER: shows for an account with an unconfirmed email", HBVerifyRules.shouldShow(unverified, defaults: suite, now: t0))
    check("EMAIL BANNER: never for a confirmed account", !HBVerifyRules.shouldShow(verified, defaults: suite, now: t0))
    check("EMAIL BANNER: never for a username account with no email", !HBVerifyRules.shouldShow(noEmail, defaults: suite, now: t0))
    check("EMAIL BANNER: never when the state is unknown, or nobody is signed in", !HBVerifyRules.shouldShow(unknown, defaults: suite, now: t0) && !HBVerifyRules.shouldShow(nil, defaults: suite, now: t0))
    HBVerifyRules.hide(defaults: suite, now: t0)
    check("EMAIL BANNER: ✕ hides it for three days, then it comes back", !HBVerifyRules.shouldShow(unverified, defaults: suite, now: t0.addingTimeInterval(2 * 86400)) && HBVerifyRules.shouldShow(unverified, defaults: suite, now: t0.addingTimeInterval(3 * 86400 + 5)))

    // ---- the level bunny's outfit (same thresholds as the website)
    func g(_ l: Int) -> HBBunnyGear { HBBunnyGear.forLevel(l) }
    check("BUNNY: level 1 wears nothing", g(1) == HBBunnyGear(sprout: false, bow: false, scarf: false, flowerCrown: false, goldenCrown: false))
    check("BUNNY: level 2 gets a sprout", g(2) == HBBunnyGear(sprout: true, bow: false, scarf: false, flowerCrown: false, goldenCrown: false))
    check("BUNNY: level 3 adds a pink bow, level 4 is the same", g(3) == HBBunnyGear(sprout: true, bow: true, scarf: false, flowerCrown: false, goldenCrown: false) && g(4) == g(3))
    check("BUNNY: level 5 adds a cozy scarf, level 6 is the same", g(5) == HBBunnyGear(sprout: true, bow: true, scarf: true, flowerCrown: false, goldenCrown: false) && g(6) == g(5))
    check("BUNNY: level 7 swaps the sprout for a flower crown (through 9)", g(7) == HBBunnyGear(sprout: false, bow: true, scarf: true, flowerCrown: true, goldenCrown: false) && g(9) == g(7))
    check("BUNNY: level 10 and up wears the tiny golden crown instead", g(10) == HBBunnyGear(sprout: false, bow: true, scarf: true, flowerCrown: false, goldenCrown: true) && g(12) == g(10))
    check("BUNNY: the unlock messages match the website", HBBunnyGear.unlock(2) == "a little sprout" && HBBunnyGear.unlock(3) == "a pink bow" && HBBunnyGear.unlock(5) == "a cozy scarf" && HBBunnyGear.unlock(7) == "a flower crown" && HBBunnyGear.unlock(10) == "a tiny golden crown" && HBBunnyGear.unlock(4) == nil)
    check("BUNNY: the level comes from the same XP rules (200 carrots = level 3)", HBProgress.levelFor(200) == 3 && HBProgress.levelInfo(200).title == "Hoppy Saver")
    check("LEVEL-UP: a reward that levels you up carries the new level", HBCarrotReward.leveledUp(in: Data(#"{"ok":true,"reward":{"gained":5,"leveled":true,"level":4}}"#.utf8)) == 4)
    check("LEVEL-UP: no dialog without a level-up, a reward, or valid data", HBCarrotReward.leveledUp(in: Data(#"{"ok":true,"reward":{"gained":5,"leveled":false,"level":4}}"#.utf8)) == nil && HBCarrotReward.leveledUp(in: Data(#"{"ok":true,"reward":null}"#.utf8)) == nil && HBCarrotReward.leveledUp(in: Data("nope".utf8)) == nil)

    HBOfflineCache.shared.clear()
}

let done = DispatchSemaphore(value: 0)
Task { await run(); done.signal() }
if done.wait(timeout: .now() + 90) == .timedOut { print("FAIL timed out"); exit(1) }
print("\(failures == 0 ? "ALL PASSED" : "\(failures) FAILED")")
exit(failures == 0 ? 0 : 1)
