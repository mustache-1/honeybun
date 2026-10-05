import Foundation
import SwiftUI

enum HBSheet: Identifiable {
    case newEntry(String), editEntry(HBEntry), editRecurring(HBRecurring), newRecurring, upcoming, allTransactions, goalDetail(String), goalForm(String?)
    case carryChange, settle(String, String), fairShare, household(Bool), shopping, search, editMe, carry, account, plan, stats, referrals
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
        case .carryChange: return "carry-change"
        case .account: return "account"
        case .plan: return "plan"
        case .stats: return "stats"
        case .referrals: return "referrals"
        }
    }
}

struct HBCategoryTotal: Identifiable { let category: HBCatStyle; let total: Double; var id: String { category.id } }
struct HBDayGroup: Identifiable { let date: String; let items: [HBEntry]; var id: String { date } }

enum HBTab: String, CaseIterable { case home = "Home", money = "Money", goals = "Goals", together = "Together", inbox = "Inbox" }

// One source of truth for every native screen. Everything on screen is computed from `snapshot` (the /api/nest response); every change
// goes through the backend and then reloads the snapshot, so Home, Money and Coming Up can never disagree with each other.
@available(iOS 15.0, *)
@MainActor final class HBAppStore: ObservableObject {
    /// checking → (signedOut → native Welcome/Login) | needsBudget (new account: start or join one) | onboarding (first-run setup) | ready
    enum Phase: Equatable { case checking, signedOut, needsBudget, onboarding, ready, failed(String) }

    @Published var phase: Phase = .checking
    /// a verify / reset / invite link that opened the app; consumed by the sign-in screens or, once signed in, by processPendingLink()
    @Published var pendingLink: HBDeepLink? { didSet { if pendingLink != nil { Task { await processPendingLink() } } } }
    @Published var joinPrefill: String?
    @Published var account: HBUser?          // who is signed in (from /api/me): name, email, how they sign in
    private var onboardingDone = false       // set once the first-run setup was finished or skipped in this session
    #if DEBUG
    var previewAuthScreen: String?           // debug screenshots of the sign-in screens
    #endif
    @Published var snapshot: HBNestSnapshot? { didSet { HBCatStyle.custom = snapshot?.categories ?? [] } }   // the account's own categories are looked up everywhere
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

    // MARK: offline (entries made with no connection wait on this iPhone, see HBPendingQueue)
    @Published var pending: [HBPendingEntry] = []     // waiting for THIS account in THIS budget
    @Published var heldElsewhere = 0                  // this account's entries waiting for a different budget
    @Published var online = true                      // the phone has a connection
    @Published var usingCache = false                 // what's on screen is the last answer saved on the phone
    @Published var syncing = false
    @Published var levelUp: Int?                      // a carrot reward just raised your level
    @Published var toast: HBToast?                    // the small message at the bottom ("Added Coffee · $4  +5 🥕", with Undo)
    @Published var verifyTick = 0                     // bumps when the "confirm your email" reminder is hidden
    var queue = HBPendingQueue.shared
    private let reach = HBReachability()
    private var watching = false
    var isOffline: Bool { !online || usingCache }
    /// everything of this account that has not reached the server (this budget's and any other budget's)
    var unsyncedTotal: Int { pending.count + heldElsewhere }
    func discardHeldElsewhere() async {
        guard let uid = account?.id ?? snapshot?.me?.id, let nid = snapshot?.nest.id else { return }
        for item in await queue.all() where item.userID == uid && item.nestID != nid { await queue.remove(item.clientID) }
        await reloadPending()
    }

    init() {}

    /// Debug-only screenshots: a ready store with a fixed snapshot and no network (see HBPreview).
    init(previewSnapshot: HBNestSnapshot, month: String, prevSpent: Double?, prevDaily: [Int: Double]) {
        self.snapshot = previewSnapshot; self.month = month; self.prevSpent = prevSpent; self.prevDaily = prevDaily; self.phase = .ready
        self.isPreview = true; self.previewMonth = month
    }
    private(set) var isPreview = false
    #if DEBUG
    var previewInboxTab: String?
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

    /// App launch (and after every sign-in): is there a valid native session? yes → the app; no → native Welcome.
    func start() async {
        if isPreview { return }
        phase = .checking
        HBSession.restore()                       // the Keychain copy, if the cookie store was emptied
        watchConnection()
        do {
            let got = try await HBAPI.shared.meOrCached()
            let me = got.me
            account = me.user
            usingCache = got.cached
            if !got.cached {
                await HBSession.mirrorToWebView()     // keeps the Classic fallback signed in too
                Task { await HoneybunDevice.ensureAppToken() }   // the widget and Siri need this phone's token
            }
            if me.nest_id == nil { phase = .needsBudget; return }
            await refresh()
        } catch HBAPIError.notSignedIn {
            phase = .signedOut
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func refresh(syncAfter: Bool = true) async {
        if isPreview { return }
        do {
            let got = try await HBAPI.shared.nestOrCached(month: month)
            let snap = got.snapshot
            snapshot = snap
            usingCache = got.cached
            if phase == .onboarding || (snap.setup_done == false && !onboardingDone) { phase = .onboarding } else { phase = .ready; askPushOnce() }
            await reloadPending()
            if !got.cached {
                await loadPrevious()
                if syncAfter { await syncPending() }
            }
        } catch HBAPIError.notSignedIn {
            // the session expired or was ended elsewhere: back to native sign-in
            resetAfterSignOut()
        } catch {
            if snapshot == nil { phase = .failed(error.localizedDescription) } else { notice = error.localizedDescription }
        }
    }

    // MARK: changing household (join another budget with a code / leave this one)

    /// Everything from the old household is dropped before the new state loads, so none of it can show up on screen (you stay signed in).
    private func householdChanged() async {
        sheet = nil; selectedTab = .home; month = HBDay.monthKey()
        snapshot = nil; inboxMessages = []; inboxState = .idle; shopping = []; shopState = .idle; prevSpent = nil; prevDaily = [:]
        pending = []; heldElsewhere = 0
        HBOfflineCache.shared.clear()
        onboardingDone = false
        await start()
    }
    /// Join another budget by its invite code. Classic's rule: only when you are alone in yours, and it REPLACES yours.
    func joinAnotherBudget(code: String) async throws {
        try await HBAPI.shared.switchBudget(code: code)
        await householdChanged()
    }
    func leaveBudget() async throws {
        try await HBAPI.shared.leaveBudget()
        await householdChanged()
    }

    // MARK: links and the Classic fallback

    /// Signed-in handling of a link (the signed-out screens handle their own, see HBAuthModel.consume).
    func processPendingLink() async {
        guard let link = pendingLink else { return }
        switch phase { case .checking, .signedOut, .failed: return; default: break }
        pendingLink = nil
        switch link {
        case let .verify(t):
            do { try await HBAPI.shared.verifyEmail(token: t); if let me = try? await HBAPI.shared.me() { account = me.user } }
            catch { notice = error.localizedDescription }
        case .referral: break                                // already signed in: nothing to sign up for
        case .reset: notice = "You're signed in. To reset a password, log out first."
        case let .join(c):
            if phase == .needsBudget { joinPrefill = c } else { notice = "You're already in a budget." }
        }
    }

    /// Back from Classic: if it's another account now, start over cleanly; otherwise just reload (Classic may have changed things).
    func returnedFromClassic() async {
        if isPreview { return }
        do {
            let me = try await HBAPI.shared.me()
            if let mine = account?.id, let now = me.user?.id, mine != now { resetAfterSignOut(); await start(); return }
            account = me.user
            if me.nest_id == nil { phase = .needsBudget; return }
            await refresh()
            if inboxState != .idle { await loadInbox() }
        } catch HBAPIError.notSignedIn {
            await HBSession.clearEverywhere()
            resetAfterSignOut()
        } catch {}
    }

    // MARK: signing in and out

    /// Called by the sign-in screens once the backend has set the session cookie.
    func didAuthenticate() async {
        await HBSession.didSignIn()
        await start()
        HBAppLock.shared.signedIn()           // you just proved who you are
        HoneybunPush.refreshIfAllowed()       // this phone now belongs to the account that signed in
    }
    /// Log out: the screen goes to the splash straight away (no account data stays visible), this phone stops getting the account's
    /// notifications, the server ends the session, every local copy of the session is cleared, then native Welcome. Server data is untouched.
    func logout() async {
        sheet = nil
        phase = .checking
        await HoneybunPush.removeTokenFromBackend()
        await HoneybunDevice.revokeAppToken()
        try? await HBAPI.shared.logout()
        await HBSession.clearEverywhere()
        resetAfterSignOut()
    }
    /// The account was deleted: the server already ended the session.
    func accountDeleted() async {
        sheet = nil
        if let id = account?.id { await queue.removeAll(user: id) }       // the account no longer exists, so nothing waiting for it can ever be delivered
        await HBSession.clearEverywhere()
        resetAfterSignOut()
    }
    func resetAfterSignOut() {
        HBOfflineCache.shared.clear()          // the last-known numbers belong to the account that just left
        pending = []; heldElsewhere = 0; usingCache = false; levelUp = nil
        HBAppLock.shared.reset()
        HoneybunDevice.clearLocal()
        snapshot = nil; account = nil; sheet = nil; selectedTab = .home; month = HBDay.monthKey()
        inboxMessages = []; inboxState = .idle; shopping = []; shopState = .idle; prevSpent = nil; prevDaily = [:]
        onboardingDone = false
        phase = .signedOut
    }
    /// first-run setup finished (or skipped)
    func finishOnboarding() async {
        onboardingDone = true
        let data = try? await HBAPI.shared.finishSetup()
        phase = .ready
        await refresh()
        if let d = data { celebrate(d, "Setup complete") }
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

    /// the month's entries, with anything saved on this phone but not yet synced (it counts in the totals, like the website's queue does)
    var entries: [HBEntry] {
        let real = snapshot?.entries ?? []
        guard !pending.isEmpty else { return real }
        let have = Set(real.map { $0.id })
        let waiting = pending.filter { $0.draft.date.hasPrefix(month) && !have.contains($0.clientID) }.sorted { $0.createdAt > $1.createdAt }.map { $0.asEntry }
        return waiting + real
    }
    func pendingItem(_ entryID: String) -> HBPendingEntry? { pending.first { $0.clientID == entryID } }
    var waitingCount: Int { pending.count }
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
        var by: [String: Double] = [:]
        for e in entries where !e.isIncome { by[HBCatStyle.of(e.category).id, default: 0] += e.amount }
        return by.map { HBCategoryTotal(category: HBCatStyle.of($0.key), total: $0.value) }.sorted { $0.total > $1.total }
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
        return HBCatStyle.of(id).label
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
    /// like run, for changes where the server answers with carrots earned (a level-up shows the celebration, like the website's rewardToast)
    private func runRewarded(_ message: String, _ work: () async throws -> Data) async throws {
        busy = true; defer { busy = false }
        let data = try await work()
        HBHaptics.success()
        await refresh()
        celebrate(data, message)
    }
    /// A level-up shows the dialog (after a beat, like the website); otherwise the toast carries the carrots and, rarely, a streak line.
    private func celebrate(_ data: Data?, _ base: String, undoTitle: String? = nil, undo: (() -> Void)? = nil) {
        let ev = data.flatMap { HBRewardEvent.parse($0) }
        showToast(ev?.toastText(base) ?? base, detail: ev?.streakLine, actionTitle: undo == nil ? nil : (undoTitle ?? "Undo"), action: undo)
        if let ev = ev, ev.leveled { Task { try? await Task.sleep(nanoseconds: 700_000_000); HBHaptics.success(); self.levelUp = ev.level } }
    }
    func showToast(_ text: String, detail: String? = nil, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        let t = HBToast(text: text, detail: detail, actionTitle: actionTitle, action: action)
        toast = t
        let secs: Double = action != nil ? 6 : (detail != nil ? 3.4 : 2.4)
        Task { try? await Task.sleep(nanoseconds: UInt64(secs * 1_000_000_000)); if self.toast?.id == t.id { self.toast = nil } }
    }
    func dismissToast() { toast = nil }

    // MARK: offline queue

    private var pushAsked = false
    /// The first time Home is ready, ask iOS about notifications once (never in previews / UI tests). If iOS says no, Settings offers "Open iPhone Settings".
    private func askPushOnce() {
        guard !pushAsked, !isPreview else { return }
        #if DEBUG
        if HBMockServer.requestedSeed != nil || HBPreview.requestedScreen != nil { return }
        #endif
        pushAsked = true
        Task { try? await Task.sleep(nanoseconds: 2_500_000_000); HoneybunPush.askOnceIfNeeded() }
    }
    private func watchConnection() {
        guard !watching, !isPreview else { return }
        watching = true
        reach.onChange = { [weak self] up in
            guard let self = self else { return }
            Task { @MainActor in
                let was = self.online
                self.online = up
                if up && !was { await self.connectionBack() }
            }
        }
        reach.start()
    }
    /// The phone is online again (or the app came back to the front): load fresh numbers, which also sends whatever is waiting.
    func connectionBack() async {
        guard !isPreview, phase == .ready else { return }
        if usingCache { await refresh() } else { await syncPending() }
    }
    func reloadPending() async {
        if isPreview { return }
        guard let uid = account?.id ?? snapshot?.me?.id, let nid = snapshot?.nest.id else { pending = []; heldElsewhere = 0; return }
        pending = await queue.items(user: uid, nest: nid)
        heldElsewhere = await queue.count(user: uid) - pending.count
    }
    /// Send what is waiting for this account and budget (never anyone else's). Quiet when there is nothing to do.
    func syncPending() async {
        if isPreview || syncing { return }
        guard let uid = account?.id ?? snapshot?.me?.id, let nid = snapshot?.nest.id else { return }
        if let a = account?.id, let b = snapshot?.me?.id, a != b { return }       // never mix accounts
        let waiting = await queue.items(user: uid, nest: nid).filter { $0.failure == nil }
        guard !waiting.isEmpty else { return }
        syncing = true
        let result = await queue.flush(user: uid, nest: nid) { item in
            _ = try await HBAPI.shared.addEntry(item.draft, clientID: item.clientID)
        }
        syncing = false
        await reloadPending()
        if result.sent > 0 {
            notice = result.sent == 1 ? "Your saved entry synced." : "\(result.sent) saved entries synced."
            await refresh(syncAfter: false)
        }
        if result.rejected > 0 { notice = "Honeybun couldn't accept \(result.rejected) saved \(result.rejected == 1 ? "entry" : "entries"). Open it to fix or discard it." }
    }
    /// "Try again" on an entry the server refused
    func retryPending(_ item: HBPendingEntry) async {
        await queue.clearFailure(item.clientID)
        await reloadPending()
        await syncPending()
    }
    /// the person's own choice to throw a saved entry away
    func discardPending(_ item: HBPendingEntry) async {
        await queue.remove(item.clientID)
        await reloadPending()
    }
    /// how many entries of this account have not reached the server (for the warnings before log out / leave / delete)
    func unsyncedCount() async -> Int {
        guard let uid = account?.id ?? snapshot?.me?.id else { return 0 }
        return await queue.count(user: uid)
    }
    /// Save online when possible; when there is no connection (or the server can't be reached) the entry is written to this iPhone and synced later,
    /// exactly once (it carries a client_id the server uses to ignore a retry). A real refusal from the server (a 4xx) is shown, never queued.
    func addEntry(_ d: HBEntryDraft) async throws {
        busy = true; defer { busy = false }
        let cid = UUID().uuidString.lowercased()
        let data: Data
        do {
            data = try await HBAPI.shared.addEntry(d, clientID: cid)
        } catch {
            guard HBPendingRules.shouldQueue(error), let uid = account?.id ?? snapshot?.me?.id, let nid = snapshot?.nest.id else { throw error }
            do { try await queue.add(d, user: uid, nest: nid, clientID: cid) }
            catch { throw HBAPIError.http(0, "Couldn't save this on your iPhone, so it was not added. Please try again.") }
            await reloadPending()
            if d.type == "expense" { HBAddDefaults.remember(d.category) }
            HBHaptics.light()
            showToast("Saved on this iPhone. It will sync when you're back online.", actionTitle: "Undo") { Task { await self.queue.remove(cid); await self.reloadPending() } }
            return
        }
        if d.type == "expense" { HBAddDefaults.remember(d.category) }
        HBHaptics.success()
        await refresh()
        let id = ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any])?["id"] as? String ?? cid
        let name = d.label.isEmpty ? HBCatStyle.of(d.category).label : d.label
        celebrate(data, "\(name) · \(HBFormat.money(d.amount))", undo: { Task { await self.undoAdd(id) } })
    }
    /// "Undo" on the toast after an add
    func undoAdd(_ id: String) async {
        do { try await HBAPI.shared.deleteEntry(id: id); HBHaptics.light(); await refresh(); showToast("Undone") } catch { notice = error.localizedDescription }
    }
    /// One tap on a "your usual" expense: logs it again with the same amount, category and split, dated today.
    func logRepeat(_ r: HBRepeat) async throws {
        var d = HBEntryDraft(type: "expense", amount: r.amount, label: r.label, category: r.category ?? "other", shared: false, date: HBDay.todayString, memberID: myID)
        d.shared = r.shared == 1 && members.count > 1 && !isJoint
        if d.shared, let m = r.split_mode {
            d.splitMode = m
            if let v = r.split_value { d.splitValue = m == "owed" ? Double(v) / 100.0 : Double(v) }
        }
        d.isPrivate = r.isPrivate == 1
        try await addEntry(d)
    }
    /// Delete with the website's safety net: it happens at once and an Undo button puts the same entry back. A saved-offline entry is simply removed from the phone.
    func deleteWithUndo(_ e: HBEntry) async {
        if e.pending {
            guard let item = pendingItem(e.id) else { return }
            await queue.remove(item.clientID); await reloadPending()
            HBHaptics.warning()
            showToast("Removed", actionTitle: "Undo") { Task { _ = try? await self.queue.add(item.draft, user: item.userID, nest: item.nestID, clientID: item.clientID); await self.reloadPending() } }
            return
        }
        do {
            try await HBAPI.shared.deleteEntry(id: e.id)
            HBHaptics.warning()
            await refresh()
            showToast("Deleted \(e.label)", actionTitle: "Undo") { Task { await self.undoDelete(e) } }
        } catch { notice = error.localizedDescription }
    }
    func undoDelete(_ e: HBEntry) async {
        do { try await HBAPI.shared.restoreEntry(e); HBHaptics.light(); await refresh(); showToast("Restored") } catch { notice = error.localizedDescription }
    }
    func updateEntry(id: String, _ d: HBEntryDraft) async throws { try await run { try await HBAPI.shared.updateEntry(id: id, d) } }
    func deleteEntry(id: String) async throws { try await run { try await HBAPI.shared.deleteEntry(id: id) } }
    func markPaid(_ u: HBUpcoming) async throws {
        try await runRewarded(u.recurring.isIncome ? "Payday logged" : u.recurring.label + " marked paid") { try await HBAPI.shared.logOccurrence(recurringID: u.recurring.id, date: u.dateString) }
    }
    func addGoal(_ d: HBGoalDraft) async throws { try await run { try await HBAPI.shared.addGoal(d) } }
    func updateGoal(id: String, _ d: HBGoalDraft) async throws { try await run { try await HBAPI.shared.updateGoal(id: id, d) } }
    func deleteGoal(id: String) async throws { try await run { try await HBAPI.shared.deleteGoal(id: id) } }
    func moveJar(goalID: String, amount: Double, out: Bool) async throws {
        let name = goal(goalID)?.name ?? "your goal"
        try await runRewarded(out ? "Taken out" : "Added to " + name) { try await HBAPI.shared.moveJar(goalID: goalID, amount: amount, out: out) }
    }
    func deleteJarMove(id: String) async throws { try await run { try await HBAPI.shared.deleteJarMove(id: id) } }
    func addRecurring(_ d: HBRecurringDraft) async throws { try await runRewarded(d.type == "income" ? "Payday added" : "Bill added") { try await HBAPI.shared.addRecurring(d) } }
    func updateRecurring(id: String, _ d: HBRecurringDraft) async throws { try await run { try await HBAPI.shared.updateRecurring(id: id, d) } }
    func deleteRecurring(id: String) async throws { try await run { try await HBAPI.shared.deleteRecurring(id: id) } }

    // MARK: Plan actions (backend first, then reload)
    func saveBudgets(_ limits: [String: Double], rollover: Bool) async throws { try await run { try await HBAPI.shared.saveBudgets(limits, rollover: rollover) } }
    func addDebt(_ d: HBDebtDraft) async throws { try await run { try await HBAPI.shared.addDebt(d) } }
    func updateDebt(id: String, _ d: HBDebtDraft) async throws { try await run { try await HBAPI.shared.updateDebt(id: id, d) } }
    func deleteDebt(id: String) async throws { try await run { try await HBAPI.shared.deleteDebt(id: id) } }
    func payDebt(_ debt: HBDebt, amount: Double, memberID: String) async throws {
        try await runRewarded("Payment logged") { try await HBAPI.shared.payDebt(id: debt.id, amount: amount, memberID: memberID, date: HBDay.todayString) }
    }
    func deleteDebtPayment(id: String) async throws { try await run { try await HBAPI.shared.deleteDebtPayment(id: id) } }
    func createCategory(name: String, emoji: String) async throws { try await run { try await HBAPI.shared.createCategory(name: name, emoji: emoji) } }
    func updateCategory(id: String, name: String, emoji: String) async throws { try await run { try await HBAPI.shared.updateCategory(id: id, name: name, emoji: emoji) } }
    func deleteCategory(id: String) async throws { try await run { try await HBAPI.shared.deleteCategory(id: id) } }

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
    func settle(from: String, to: String, amount: Double) async throws { try await runRewarded("Marked as paid ♡") { try await HBAPI.shared.settle(from: from, to: to, amount: amount, date: HBDay.todayString) } }
    func deleteSettlement(id: String) async throws { try await run { try await HBAPI.shared.deleteSettlement(id: id) } }
    /// Monthly carry-over (Ask me / Always carry / Start fresh): the same setting the Inbox "remember" choice writes (nests.carry_mode)
    var carryMode: String { snapshot?.nest.carry_mode ?? "ask" }
    func setCarryMode(_ mode: String) async throws { try await run { try await HBAPI.shared.patchNest(["carry_mode": mode]) } }
    /// Reconsider THIS month's carry-over decision (the website's "Change"). Future months follow the Settings choice instead.
    var carryCard: HBCarryCard? { snapshot.flatMap { HBPlan.carryCard($0, month: month) } }
    var carryChangePrompt: HBCarryPrompt? { snapshot?.carry_prev }
    func changeCarry(accept: Bool, remember: Bool) async throws {
        try await run { try await HBAPI.shared.decideCarry(month: HBDay.monthKey(), accept: accept, remember: remember, change: true) }
        showToast(accept ? "Carried over" : "Starting fresh")
    }
    func setJoint(_ on: Bool) async throws { try await run { try await HBAPI.shared.patchNest(["joint": on]) } }
    func setKind(_ kind: String) async throws { try await run { try await HBAPI.shared.patchNest(["kind": kind]) } }
    func renameNest(_ name: String) async throws { try await run { try await HBAPI.shared.patchNest(["name": name]) } }
    func newInviteCode() async throws { try await run { _ = try await HBAPI.shared.newInviteCode() } }
    func updateMe(name: String, emoji: String, color: String) async throws { try await run { try await HBAPI.shared.updateMe(name: name, emoji: emoji, color: color) } }
    func search(_ f: HBSearchFilter) async throws -> [HBEntry] { try await HBAPI.shared.search(f) }

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
    func markOccurrencePaid(recurringID: String, date: String) async throws {
        let r = snapshot?.recurring.first { $0.id == recurringID }
        try await runRewarded((r?.isIncome ?? false) ? "Payday logged" : (r?.label ?? "Bill") + " marked paid") { try await HBAPI.shared.logOccurrence(recurringID: recurringID, date: date) }
    }
    func decideCarry(accept: Bool, remember: Bool) async throws {
        try await run { try await HBAPI.shared.decideCarry(month: HBDay.monthKey(), accept: accept, remember: remember) }
        await loadInbox()
    }
}
