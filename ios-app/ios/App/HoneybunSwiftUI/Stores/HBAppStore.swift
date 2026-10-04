import Foundation
import SwiftUI

enum HBSheet: Identifiable {
    case newEntry(String), editEntry(HBEntry), editRecurring(HBRecurring), newRecurring, upcoming, allTransactions, goalDetail(String), goalForm(String?)
    case settle(String, String), fairShare, household(Bool), shopping, search, editMe, carry
    var id: String {
        switch self {
        case let .newEntry(t): return "new-" + t
        case let .editEntry(e): return "entry-" + e.id
        case let .editRecurring(r): return "rec-" + r.id
        case .newRecurring: return "new-rec"
        case .upcoming: return "upcoming"
        case .allTransactions: return "all-transactions"
        case let .goalDetail(id): return "goal-" + id
        case let .goalForm(id): return "goal-form-" + (id ?? "new")
        case let .settle(f, t): return "settle-" + f + "-" + t
        case .fairShare: return "fair-share"
        case let .household(invite): return invite ? "household-invite" : "household"
        case .shopping: return "shopping"
        case .search: return "search"
        case .editMe: return "edit-me"
        case .carry: return "carry"
        }
    }
}

struct HBCategoryTotal: Identifiable { let category: HBCategory; let total: Double; var id: String { category.rawValue } }
struct HBDayGroup: Identifiable { let date: String; let items: [HBEntry]; var id: String { date } }

enum HBTab: String, CaseIterable { case home = "Home", money = "Money", goals = "Goals", together = "Together", inbox = "Inbox" }

// One source of truth for every native screen. Everything on screen is computed from `snapshot` (the /api/nest response); every change
// goes through the backend and then reloads the snapshot, so Home, Money and Coming Up can never disagree with each other.
@available(iOS 15.0, *)
@MainActor final class HBAppStore: ObservableObject {
    enum Phase: Equatable { case checking, signedOut, ready, failed(String) }

    @Published var phase: Phase = .checking
    @Published var snapshot: HBNestSnapshot?
    @Published var month: String = HBDay.monthKey()
    @Published var selectedTab: HBTab = .home
    @Published var busy = false
    @Published var notice: String?
    var previewScrollToEnd = false   // debug screenshots: open scrolled all the way down
    @Published var sheet: HBSheet?
    @Published var inboxMessages: [HBInboxMessage] = []
    enum InboxState: Equatable { case idle, loading, loaded, failed(String) }
    @Published var inboxState: InboxState = .idle
    @Published var shopping: [HBShopItem] = []
    enum ShopState: Equatable { case idle, loading, loaded, failed(String) }
    @Published var shopState: ShopState = .idle
    @Published var prevSpent: Double?   // last month's spending, for the Money insight card
    @Published var prevDaily: [Int: Double] = [:]   // last month's spending by day of month, for the chart

    init() {}

    /// Debug-only screenshots: a ready store with a fixed snapshot and no network (see HBPreview).
    init(previewSnapshot: HBNestSnapshot, month: String, prevSpent: Double?, prevDaily: [Int: Double]) {
        self.snapshot = previewSnapshot; self.month = month; self.prevSpent = prevSpent; self.prevDaily = prevDaily; self.phase = .ready
        self.isPreview = true; self.previewMonth = month
    }
    private(set) var isPreview = false
    #if DEBUG
    /// debug screenshots only: a sample inbox ("mixed", "long" or "empty")
    func seedPreviewInbox(_ kind: String) {
        guard let snap = snapshot else { return }
        let list = HBPreviewVariants.inboxMessages(kind, recurring: snap.recurring.map { ($0.id, $0.label, $0.amount_cents) })
        guard let data = try? JSONSerialization.data(withJSONObject: ["messages": list]), let env = try? JSONDecoder().decode(HBInboxEnvelope.self, from: data) else { return }
        inboxMessages = env.messages; inboxState = .loaded
    }
    /// debug screenshots only: a sample shopping list, since previews have no network
    func seedPreviewShopping() {
        guard let data = try? JSONSerialization.data(withJSONObject: ["items": HBPreviewVariants.shopping]),
              let env = try? JSONDecoder().decode(HBShopEnvelope.self, from: data) else { return }
        shopping = env.items; shopState = .loaded
    }
    #endif
    /// debug screenshots only: keep showing the loading splash
    var forceLoading = false { didSet { if forceLoading { phase = .checking } } }
    private var previewMonth: String?

    // MARK: loading

    func start() async {
        if isPreview { return }
        phase = .checking
        await HBSession.syncFromWebView()
        await refresh()
    }

    func refresh() async {
        if isPreview { return }
        do {
            snapshot = try await HBAPI.shared.nest(month: month)
            phase = .ready
            await loadPrevious()
        } catch HBAPIError.notSignedIn {
            // the web view may have refreshed its cookie since we copied it: try once more before calling it signed out
            let copied = await HBSession.syncFromWebView()
            if copied > 0, let again = try? await HBAPI.shared.nest(month: month) { snapshot = again; phase = .ready } else { phase = .signedOut }
        } catch {
            if snapshot == nil { phase = .failed(error.localizedDescription) } else { notice = error.localizedDescription }
        }
    }

    func shiftMonth(_ n: Int) { setMonth(HBDay.shiftMonth(month, by: n)) }
    func setMonth(_ key: String) { guard key != month else { return }; month = key; Task { await refresh() } }

    // the month before the one on screen, only to say "spending is N% lower than last month"; if it can't load, the card just says something else
    private func loadPrevious() async {
        let prev = HBDay.shiftMonth(month, by: -1)
        if let p = try? await HBAPI.shared.nest(month: prev) {
            let out = p.entries.filter { !$0.isIncome }
            prevSpent = out.reduce(0) { $0 + $1.amount }
            prevDaily = HBChartMath.dailyExpenses(out)
        } else { prevSpent = nil; prevDaily = [:] }
    }

    /// the last 12 months, newest first, for the month menu
    var recentMonths: [String] { (0..<12).map { HBDay.shiftMonth(currentKey, by: -$0) } }
    private var currentKey: String { isPreview ? (previewMonth ?? HBDay.monthKey()) : HBDay.monthKey() }
    func monthTitle(_ key: String) -> String { key == currentKey ? "This Month" : HBDay.monthName(key) }
    var streak: Int { snapshot?.members.first { $0.id == myID }?.streak ?? 0 }
    var unread: Int { snapshot?.inbox?.unread ?? 0 }

    // MARK: derived (all from the snapshot)

    var entries: [HBEntry] { snapshot?.entries ?? [] }
    var members: [HBMember] { snapshot?.members ?? [] }
    var myID: String { snapshot?.me?.id ?? "" }
    var isJoint: Bool { (snapshot?.nest.joint ?? 0) == 1 }
    var income: Double { entries.filter { $0.isIncome }.reduce(0) { $0 + $1.amount } }
    var spent: Double { entries.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount } }
    var carry: Double { Double(snapshot?.carry_in?.amount_cents ?? 0) / 100.0 }
    var left: Double { income - spent + carry }
    var goals: [HBGoal] { snapshot?.goals ?? [] }
    func goal(_ id: String) -> HBGoal? { goals.first { $0.id == id } }
    func jarMoves(for goalID: String) -> [HBJarMove] { (snapshot?.jar ?? []).filter { $0.goal_id == goalID }.sorted { $0.created_at > $1.created_at } }
    var upcoming: [HBUpcoming] { snapshot.map(HBRecur.upcoming) ?? [] }
    var categoryTotals: [HBCategoryTotal] {
        var by: [HBCategory: Double] = [:]
        for e in entries where !e.isIncome { by[HBCategory.of(e.category), default: 0] += e.amount }
        return by.map { HBCategoryTotal(category: $0.key, total: $0.value) }.sorted { $0.total > $1.total }
    }
    var dayGroups: [HBDayGroup] {
        let by = Dictionary(grouping: entries, by: { $0.date })
        return by.keys.sorted(by: >).map { HBDayGroup(date: $0, items: by[$0] ?? []) }
    }
    func memberName(_ id: String) -> String { members.first { $0.id == id }?.name ?? "" }

    // MARK: Together (derived from the same snapshot)

    var nest: HBNest? { snapshot?.nest }
    var kind: String { snapshot?.nest.kind ?? "couple" }
    var situation: HBSituation { HBTogether.situation(memberCount: members.count) }
    var jointActive: Bool { HBTogether.isJoint(kind: snapshot?.nest.kind, joint: snapshot?.nest.joint, memberCount: members.count) }
    var inviteCode: String { snapshot?.nest.invite_code ?? "" }
    var settlements: [HBSettlement] { snapshot?.settlements ?? [] }
    var pairs: [HBPair] { jointActive ? [] : HBTogether.pairs(members: members, balances: snapshot?.balances ?? [:]) }
    var iOwe: Double { pairs.filter { $0.from.id == myID }.reduce(0) { $0 + $1.amount } }
    var owedToMe: Double { pairs.filter { $0.to.id == myID }.reduce(0) { $0 + $1.amount } }
    var partner: HBMember? { members.first { $0.id != myID } }

    // MARK: Inbox (derived)

    var carryPrompt: HBCarryPrompt? { snapshot?.carry_pending }
    func recurringExists(_ id: String) -> Bool { snapshot?.recurring.contains { $0.id == id } ?? false }
    func isLogged(rid: String, occ: String) -> Bool { snapshot?.logged.contains { $0.recurring_id == rid && $0.occ_date == occ } ?? false }
    /// a category id from a message ("food", "c_ab12…") as the account names it
    func categoryName(_ id: String) -> String {
        if let c = snapshot?.categories?.first(where: { $0.id == id }) { return c.name }
        return HBCategory.of(id).label
    }
    var inboxTodayString: String { HBDay.todayString }
    func member(_ id: String) -> HBMember? { members.first { $0.id == id } }

    func newEntryDraft(type: String) -> HBEntryDraft {
        // a month other than this one gets that month's first day, so the new entry shows up where you are looking
        let date = month == HBDay.monthKey() ? HBDay.todayString : month + "-01"
        return HBEntryDraft(type: type, date: date, memberID: myID)
    }
    func draft(from e: HBEntry) -> HBEntryDraft {
        var d = HBEntryDraft(type: e.type, amount: e.amount, label: e.label, category: e.category ?? "other", shared: e.shared == 1, date: e.date, memberID: e.member_id)
        d.splitMode = e.split_mode
        if let v = e.split_value { d.splitValue = e.split_mode == "owed" ? Double(v) / 100.0 : Double(v) }
        d.isPrivate = e.isPrivate == 1
        return d
    }
    func draft(from r: HBRecurring) -> HBRecurringDraft {
        var d = HBRecurringDraft(type: r.type, amount: r.amount, label: r.label, category: r.category ?? "bills", freq: r.freq, date: r.anchor_date, memberID: r.member_id)
        d.shared = r.shared == 1
        d.splitMode = r.split_mode
        if let v = r.split_value { d.splitValue = r.split_mode == "owed" ? Double(v) / 100.0 : Double(v) }
        return d
    }

    // MARK: changes (backend first, then reload the one snapshot)

    private func run(_ work: () async throws -> Void) async throws {
        busy = true; defer { busy = false }
        try await work()
        await refresh()
    }
    func addEntry(_ d: HBEntryDraft) async throws { try await run { try await HBAPI.shared.addEntry(d) } }
    func updateEntry(id: String, _ d: HBEntryDraft) async throws { try await run { try await HBAPI.shared.updateEntry(id: id, d) } }
    func deleteEntry(id: String) async throws { try await run { try await HBAPI.shared.deleteEntry(id: id) } }
    func markPaid(_ u: HBUpcoming) async throws { try await run { try await HBAPI.shared.logOccurrence(recurringID: u.recurring.id, date: u.dateString) } }
    func addGoal(_ d: HBGoalDraft) async throws { try await run { try await HBAPI.shared.addGoal(d) } }
    func updateGoal(id: String, _ d: HBGoalDraft) async throws { try await run { try await HBAPI.shared.updateGoal(id: id, d) } }
    func deleteGoal(id: String) async throws { try await run { try await HBAPI.shared.deleteGoal(id: id) } }
    func moveJar(goalID: String, amount: Double, out: Bool) async throws { try await run { try await HBAPI.shared.moveJar(goalID: goalID, amount: amount, out: out) } }
    func deleteJarMove(id: String) async throws { try await run { try await HBAPI.shared.deleteJarMove(id: id) } }
    func addRecurring(_ d: HBRecurringDraft) async throws { try await run { try await HBAPI.shared.addRecurring(d) } }
    func updateRecurring(id: String, _ d: HBRecurringDraft) async throws { try await run { try await HBAPI.shared.updateRecurring(id: id, d) } }
    func deleteRecurring(id: String) async throws { try await run { try await HBAPI.shared.deleteRecurring(id: id) } }

    // MARK: Together actions (backend first, then reload)

    func loadShopping() async {
        if isPreview { return }
        if shopState == .idle { shopState = .loading }
        do { shopping = try await HBAPI.shared.shopping(); shopState = .loaded }
        catch { if shopState != .loaded { shopState = .failed(error.localizedDescription) } else { notice = error.localizedDescription } }
    }
    private func shopRun(_ work: () async throws -> Void) async throws {
        busy = true; defer { busy = false }
        try await work()
        await loadShopping()
    }
    func addShopItem(_ label: String) async throws { try await shopRun { try await HBAPI.shared.addShopItem(label) } }
    func setShopDone(_ item: HBShopItem, done: Bool) async throws {
        if let i = shopping.firstIndex(where: { $0.id == item.id }) { shopping[i].done = done }   // the tick shows at once, the backend confirms
        do { try await shopRun { try await HBAPI.shared.setShopDone(id: item.id, done: done) } } catch { await loadShopping(); throw error }
    }
    func renameShopItem(_ item: HBShopItem, to label: String) async throws { try await shopRun { try await HBAPI.shared.renameShopItem(id: item.id, label: label) } }
    func deleteShopItem(_ item: HBShopItem) async throws {
        shopping.removeAll { $0.id == item.id }
        do { try await shopRun { try await HBAPI.shared.deleteShopItem(id: item.id) } } catch { await loadShopping(); throw error }
    }
    func clearShopDone() async throws { try await shopRun { try await HBAPI.shared.clearShopDone() } }
    func shopCheckout(amount: Double) async throws {
        try await run { try await HBAPI.shared.shopCheckout(amount: amount, date: HBDay.todayString) }
        await loadShopping()
    }
    func settle(from: String, to: String, amount: Double) async throws { try await run { try await HBAPI.shared.settle(from: from, to: to, amount: amount, date: HBDay.todayString) } }
    func deleteSettlement(id: String) async throws { try await run { try await HBAPI.shared.deleteSettlement(id: id) } }
    func setJoint(_ on: Bool) async throws { try await run { try await HBAPI.shared.patchNest(["joint": on]) } }
    func setKind(_ kind: String) async throws { try await run { try await HBAPI.shared.patchNest(["kind": kind]) } }
    func renameNest(_ name: String) async throws { try await run { try await HBAPI.shared.patchNest(["name": name]) } }
    func newInviteCode() async throws { try await run { _ = try await HBAPI.shared.newInviteCode() } }
    func updateMe(name: String, emoji: String, color: String) async throws { try await run { try await HBAPI.shared.updateMe(name: name, emoji: emoji, color: color) } }
    func search(q: String, type: String, member: String) async throws -> [HBEntry] { try await HBAPI.shared.search(q: q, type: type, member: member) }

    // MARK: Inbox actions

    /// Bun's messages, newest first. Opening the inbox also generates anything new (bills due, streak check-ins) on the server.
    func loadInbox() async {
        if isPreview { return }
        if inboxState == .idle { inboxState = .loading }
        do { inboxMessages = try await HBAPI.shared.inbox(); inboxState = .loaded }
        catch { if inboxState != .loaded { inboxState = .failed(error.localizedDescription) } else { notice = error.localizedDescription } }
    }
    /// Mark everything read on the server and refresh the badge. The messages on screen keep their "new" look until you leave.
    func markInboxRead() async {
        if isPreview { return }
        guard inboxMessages.contains(where: { $0.isUnread }) || unread > 0 else { return }
        do { try await HBAPI.shared.markInboxRead(); await refresh() } catch { notice = error.localizedDescription }
    }
    /// "Paid" / "Got it" on a bill or payday message: logs that occurrence exactly like Home's Coming Up does
    func markOccurrencePaid(recurringID: String, date: String) async throws { try await run { try await HBAPI.shared.logOccurrence(recurringID: recurringID, date: date) } }
    func decideCarry(accept: Bool, remember: Bool) async throws {
        try await run { try await HBAPI.shared.decideCarry(month: HBDay.monthKey(), accept: accept, remember: remember) }
        await loadInbox()
    }
}
