import Foundation
import SwiftUI

enum HBSheet: Identifiable {
    case newEntry(String), editEntry(HBEntry), editRecurring(HBRecurring), newRecurring, upcoming
    var id: String {
        switch self {
        case let .newEntry(t): return "new-" + t
        case let .editEntry(e): return "entry-" + e.id
        case let .editRecurring(r): return "rec-" + r.id
        case .newRecurring: return "new-rec"
        case .upcoming: return "upcoming"
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
    @Published var sheet: HBSheet?
    @Published var prevSpent: Double?   // last month's spending, for the Money insight card
    @Published var prevDaily: [Int: Double] = [:]   // last month's spending by day of month, for the chart

    init() {}

    /// Debug-only screenshots: a ready store with a fixed snapshot and no network (see HBPreview).
    init(previewSnapshot: HBNestSnapshot, month: String, prevSpent: Double?, prevDaily: [Int: Double]) {
        self.snapshot = previewSnapshot; self.month = month; self.prevSpent = prevSpent; self.prevDaily = prevDaily; self.phase = .ready
        self.isPreview = true; self.previewMonth = month
    }
    private(set) var isPreview = false
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
            var by: [Int: Double] = [:]
            for e in out { if let d = Int(e.date.suffix(2)) { by[d, default: 0] += e.amount } }
            prevDaily = by
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
    func addRecurring(_ d: HBRecurringDraft) async throws { try await run { try await HBAPI.shared.addRecurring(d) } }
    func updateRecurring(id: String, _ d: HBRecurringDraft) async throws { try await run { try await HBAPI.shared.updateRecurring(id: id, d) } }
    func deleteRecurring(id: String) async throws { try await run { try await HBAPI.shared.deleteRecurring(id: id) } }
}
