import SwiftUI

// Home: "From Bun" (the ranked insights: budget warnings, price changes, forecast, pace, bills, debts, goals, together; plus the quiet-day nudge),
// the "confirm your email" reminder, and the offline / waiting-to-sync notices. The rules live in HBInsights.swift (and HBHeadsUp.swift for the
// original Heads-up rules it reuses); this is only how they look.

@available(iOS 15.0, *)
extension HBAppStore {
    /// everything Bun's insight engine reads (the month's entries as Home counts them, last month's facts, Debt Center+'s settings)
    var insightContext: HBInsightContext? {
        guard let s = snapshot else { return nil }
        return HBInsightContext(snapshot: s, entries: entries, month: month, today: HBDay.startOfToday(), myID: myID, me: member(myID), prev: prevMonth,
                                strategy: HBDebtPrefs.strategy(), extra: HBDebtPrefs.extra())
    }
    /// the one line under Home's Safe to Spend number
    var safeLine: String? { insightContext.flatMap { HBInsights.safeLine($0) } }
}

/// "From Bun" on Home: the few insights that matter right now (ranked by HBInsights), plus the quiet-day nudge. "Why am I seeing this?" shows the
/// numbers behind each one. The rules and ranking live in HBInsights.swift; this is only how they look.
@available(iOS 15.0, *)
struct HBHeadsUpSection: View {
    @ObservedObject var store: HBAppStore
    @State private var memory = HBInsightMemory.load()        // the ranking is worked out against what was known when Home opened
    @State private var priceSeen = HBHeadsUpRules.seen()
    @State private var why: Set<String> = []

    private var plan: HBInsightPlan? {
        guard var c = store.insightContext else { return nil }
        c.memory = memory; c.priceSeen = priceSeen
        return HBInsights.home(c)
    }
    private var shownIDs: [String] { plan?.shown.map { $0.id } ?? [] }
    private var sleepyDays: Int? {
        guard let s = store.snapshot else { return nil }
        return HBHeadsUpRules.compute(s, month: store.month, me: store.member(store.myID), seen: priceSeen, forecast: .notThisMonth).sleepyDays
    }

    var body: some View {
        let p = plan
        let sleepy = sleepyDays
        if sleepy != nil || !(p?.shown.isEmpty ?? true) {
            VStack(alignment: .leading, spacing: 10) {
                if let days = sleepy { sleepyCard(days) }
                if let p = p, !p.shown.isEmpty {
                    HBSectionHeader(title: "From Bun")
                    VStack(spacing: 0) {
                        ForEach(Array(p.shown.enumerated()), id: \.element.id) { i, ins in
                            if i > 0 { Divider().background(HB.line).padding(.leading, 62) }
                            row(ins)
                        }
                        if !p.more.isEmpty {
                            Divider().background(HB.line).padding(.leading, 14)
                            moreRow(p.more.count)
                        }
                    }
                    .hbCard()
                    .accessibilityElement(children: .contain).accessibilityIdentifier("hb-heads-up")
                }
            }
            .onAppear { record(p) }
            .onChange(of: shownIDs) { _ in record(plan) }
        }
    }

    /// counts today as a day each of these was on Home (the ranking above isn't touched until Home opens again)
    private func record(_ p: HBInsightPlan?) {
        guard let p = p else { return }
        var m = HBInsightMemory.load()
        m.markShown(p.shown.map { $0.id }, day: HBDay.todayString)
        m.save()
    }

    private func dismiss(_ i: HBInsight) {
        var m = HBInsightMemory.load()
        m.dismiss(i.id); m.save()
        memory = m
        if let key = i.dismissKey { HBHeadsUpRules.dismiss(key); priceSeen = HBHeadsUpRules.seen() }
    }

    private func open(_ i: HBInsight) {
        switch i.kind {
        case .forecast, .budget, .pace, .debt: store.sheet = .plan
        case .comparison: store.sheet = .stats
        case .safeToSpend: store.sheet = .allTransactions
        case .bills, .recurring: store.sheet = .upcoming
        case .goal: store.selectedTab = .goals
        case .together: store.selectedTab = .together
        case .onboarding: store.sheet = .newEntry("expense")
        }
    }

    /// the quiet footer of the From Bun card: it belongs to the card, not to the next section
    private func moreRow(_ n: Int) -> some View {
        Button { store.sheet = .insights } label: {
            HStack(spacing: 6) {
                Text("More from Bun").font(.system(size: 14, weight: .semibold)).foregroundColor(Color(red: 0.72, green: 0.68, blue: 0.9))
                Text(n == 1 ? "1 more" : "\(n) more").font(.system(size: 13)).foregroundColor(HB.soft)
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundColor(HB.soft)
            }
            .padding(.horizontal, 14).frame(maxWidth: .infinity, minHeight: 40, alignment: .leading).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(n == 1 ? "More from Bun, 1 more note" : "More from Bun, \(n) more notes")
        .accessibilityIdentifier("hb-insights-more")
    }

    private func sleepyCard(_ days: Int) -> some View {
        HStack(spacing: 12) {
            HBCircleIcon(symbol: "moon.zzz.fill", tint: Color(red: 0.62, green: 0.58, blue: 1), size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text("Bun is a little sleepy").font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                Text("No spending logged in \(days) days. Add what you spent and Bun perks right up.").font(.system(size: 14)).foregroundColor(HB.soft).fixedSize(horizontal: false, vertical: true)
                Button { store.sheet = .newEntry("expense") } label: { Text("Log something").font(.system(size: 15, weight: .bold)).foregroundColor(HB.orange) }
                    .padding(.top, 2).accessibilityIdentifier("hb-sleepy-log")
            }
            Spacer(minLength: 0)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).hbCard()
        .accessibilityElement(children: .contain).accessibilityIdentifier("hb-sleepy")
    }

    private func row(_ i: HBInsight) -> some View {
        HBInsightRow(insight: i, showWhy: why.contains(i.id), onOpen: { open(i) }, onDismiss: { dismiss(i) },
                     onToggleWhy: { if why.contains(i.id) { why.remove(i.id) } else { why.insert(i.id) } })
    }
}

/// "Why am I seeing this?": the numbers behind the note, in plain words (never the ranking internals, which stay in the insight's trace)
@available(iOS 15.0, *)
struct HBInsightWhy: View {
    let detail: HBInsightDetail
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(detail.lines.enumerated()), id: \.offset) { _, line in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(line.label).font(.system(size: 13)).foregroundColor(HB.soft).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 6)
                    Text(line.value).font(.system(size: 13, weight: .semibold)).foregroundColor(.white).multilineTextAlignment(.trailing).fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
            if let note = detail.footnote {
                Text(note).font(.system(size: 12)).foregroundColor(HB.soft.opacity(0.85)).fixedSize(horizontal: false, vertical: true).padding(.top, 2)
            }
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.05)))
        .accessibilityIdentifier("hb-insight-why-panel")
    }
}

/// one insight: icon, what Bun says, a "why" you can open, and a dismiss
@available(iOS 15.0, *)
struct HBInsightRow: View {
    let insight: HBInsight
    let showWhy: Bool
    var onOpen: () -> Void = {}
    var onDismiss: (() -> Void)? = nil
    var onToggleWhy: (() -> Void)? = nil

    private var tint: Color {
        switch insight.tone {
        case .positive: return HB.green
        case .neutral: return HB.orange
        case .watch: return Color(red: 1, green: 0.78, blue: 0.4)
        case .warning: return HB.red
        }
    }
    private var symbol: String {
        switch insight.kind {
        case .forecast: return insight.tone == .warning ? "exclamationmark.triangle.fill" : "sparkles"
        case .safeToSpend: return "dollarsign.circle.fill"
        case .budget, .pace: return "clock.fill"
        case .comparison: return insight.tone == .positive ? "arrow.down.right" : "arrow.up.right"
        case .bills: return "calendar"
        case .recurring: return "chart.line.uptrend.xyaxis"
        case .debt: return "creditcard.fill"
        case .goal: return "flag.fill"
        case .together: return "person.2.fill"
        case .onboarding: return "sparkles"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                Button(action: onOpen) {
                    HStack(alignment: .top, spacing: 12) {
                        if let cat = insight.category { HBCatIcon(style: HBCatStyle.of(cat), size: 40) }
                        else { HBCircleIcon(symbol: symbol, tint: tint, size: 40) }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(insight.title).font(.system(size: 16, weight: .semibold)).foregroundColor(.white).fixedSize(horizontal: false, vertical: true)
                            if let ratio = insight.ratio {
                                GeometryReader { g in ZStack(alignment: .leading) {
                                    Capsule().fill(Color.black.opacity(0.28))
                                    Capsule().fill(ratio > 1 ? HB.red : HB.orange).frame(width: max(6, g.size.width * CGFloat(min(1, ratio))))
                                } }.frame(height: 6)
                            }
                            Text(insight.note).font(.system(size: 13)).foregroundColor(insight.tone == .warning ? HB.red.opacity(0.95) : HB.soft).fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if let onDismiss = onDismiss {
                    Button(action: onDismiss) { Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundColor(HB.soft).frame(width: 32, height: 32) }
                        .accessibilityLabel("Dismiss").accessibilityIdentifier("hb-insight-dismiss")
                }
            }
            if let toggle = onToggleWhy, !insight.detail.lines.isEmpty {
                Button(action: toggle) {
                    Text(showWhy ? "Hide" : "Why am I seeing this?").font(.system(size: 12, weight: .semibold)).foregroundColor(Color(red: 0.72, green: 0.68, blue: 0.9))
                }
                .padding(.leading, 52).accessibilityIdentifier("hb-insight-why")
            }
            if showWhy && !insight.detail.lines.isEmpty {
                HBInsightWhy(detail: insight.detail).padding(.leading, 52).padding(.top, 2)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .accessibilityIdentifier("hb-insight-" + insight.id)
    }
}

/// everything Bun noticed, with the numbers behind each note
@available(iOS 15.0, *)
struct HBInsightsSheet: View {
    @ObservedObject var store: HBAppStore
    @Environment(\.dismiss) private var dismiss

    private var all: [HBInsight] {
        guard var c = store.insightContext else { return [] }
        c.memory = HBInsightMemory.load()
        let p = HBInsights.home(c)
        return p.shown + p.more
    }

    var body: some View {
        HBSheetScaffold(title: "From Bun", onBack: { dismiss() }) {
            let items = all
            if items.isEmpty {
                Text("Nothing to flag right now. Bun will say something when your numbers give it a reason to.").font(.system(size: 15)).foregroundColor(HB.soft)
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading).hbCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { i, ins in
                        if i > 0 { Divider().background(HB.line).padding(.leading, 62) }
                        HBInsightRow(insight: ins, showWhy: true, onOpen: {})
                    }
                }
                .hbCard()
            }
            Text("Bun's notes are worked out from the numbers you've entered in Honeybun, using the same rules every time. They're for budgeting and planning, not financial advice, and projections are estimates.")
                .font(.footnote).foregroundColor(HB.soft).fixedSize(horizontal: false, vertical: true)
        }
    }
}

@available(iOS 15.0, *)
struct HBVerifyBanner: View {
    @ObservedObject var store: HBAppStore
    @State private var sending = false
    @State private var sent = false
    @State private var error: String?

    var body: some View {
        if HBVerifyRules.shouldShow(store.account) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Button { store.sheet = .account } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "envelope.badge").font(.system(size: 18, weight: .semibold)).foregroundColor(HB.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Please confirm your email").font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                                Text(sent ? "Sent. Check your inbox (and spam)." : "So Bun can send your reminders.").font(.system(size: 13)).foregroundColor(HB.soft)
                            }
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Button { resend() } label: {
                        Text(sending ? "Sending…" : "Resend").font(.system(size: 14, weight: .bold)).foregroundColor(HB.orange)
                            .padding(.horizontal, 12).frame(height: 34).overlay(Capsule().stroke(HB.orange.opacity(0.5), lineWidth: 1))
                    }
                    .disabled(sending).accessibilityIdentifier("hb-verify-resend")
                    Button { HBVerifyRules.hide(); store.verifyTick += 1 } label: {
                        Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundColor(HB.soft).frame(width: 30, height: 34)
                    }
                    .accessibilityLabel("Hide for now").accessibilityIdentifier("hb-verify-hide")
                }
                if let e = error { Text(e).font(.footnote).foregroundColor(HB.red) }
            }
            .padding(12).hbCard()
            .accessibilityElement(children: .contain).accessibilityIdentifier("hb-verify-banner")
        }
    }
    private func resend() {
        sending = true; error = nil
        Task {
            do { try await HBAPI.shared.resendVerification(); sent = true } catch { self.error = error.localizedDescription }
            sending = false
        }
    }
}

/// "You're offline" and the entries waiting to sync
@available(iOS 15.0, *)
struct HBOfflineBanner: View {
    @ObservedObject var store: HBAppStore
    private var failed: [HBPendingEntry] { store.pending.filter { $0.failure != nil } }
    private var waiting: [HBPendingEntry] { store.pending.filter { $0.failure == nil } }

    var body: some View {
        VStack(spacing: 8) {
            if store.isOffline {
                line(symbol: "wifi.slash", tint: HB.orange, text: store.pending.isEmpty ? "You're offline. Showing your last saved numbers." : "You're offline. New entries are saved on this iPhone and will sync when you're back.")
            }
            if store.syncing {
                line(symbol: "arrow.triangle.2.circlepath", tint: HB.orange, text: "Syncing your saved entries…")
            } else if !waiting.isEmpty && !store.isOffline {
                HStack {
                    Label("\(waiting.count) saved \(waiting.count == 1 ? "entry" : "entries") waiting to sync", systemImage: "clock.arrow.circlepath").font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                    Spacer()
                    Button("Sync now") { Task { await store.syncPending() } }.font(.system(size: 14, weight: .bold)).foregroundColor(HB.orange).accessibilityIdentifier("hb-sync-now")
                }
                .padding(12).hbCard()
            } else if !waiting.isEmpty {
                line(symbol: "clock.arrow.circlepath", tint: HB.orange, text: "\(waiting.count) saved \(waiting.count == 1 ? "entry" : "entries") waiting to sync")
            }
            if !failed.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("\(failed.count) saved \(failed.count == 1 ? "entry needs" : "entries need") your attention", systemImage: "exclamationmark.triangle.fill").font(.system(size: 14, weight: .semibold)).foregroundColor(HB.red)
                    ForEach(failed) { item in
                        Button { store.sheet = .editEntry(item.asEntry) } label: {
                            HStack { Text("\(item.draft.label) · \(HBFormat.money(item.draft.amount))").font(.system(size: 14)).foregroundColor(.white).lineLimit(1); Spacer(); Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)).foregroundColor(HB.soft) }
                        }
                    }
                }
                .padding(12).hbCard()
            }
        }
        .accessibilityElement(children: .contain).accessibilityIdentifier("hb-offline-banner")
    }
    private func line(symbol: String, tint: Color, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).foregroundColor(tint)
            Text(text).font(.system(size: 14, weight: .medium)).foregroundColor(.white).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12).hbCard()
    }
}

/// An entry that is saved on this iPhone but not synced yet (tapping its row opens this instead of the normal editor)
@available(iOS 15.0, *)
struct HBPendingEntrySheet: View {
    @ObservedObject var store: HBAppStore
    let entryID: String
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDiscard = false

    var body: some View {
        HBSheetScaffold(title: "Saved on this iPhone", onBack: { dismiss() }) {
            if let item = store.pendingItem(entryID) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.draft.label.isEmpty ? (item.draft.type == "income" ? "Income" : "Expense") : item.draft.label).font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                    Text("\(item.draft.type == "income" ? "+" : "")\(HBFormat.money(item.draft.amount)) · \(HBDay.short(item.draft.date))" + (item.draft.type == "expense" ? " · \(HBCatStyle.of(item.draft.category).label)" : ""))
                        .font(.system(size: 15)).foregroundColor(HB.soft)
                    if let f = item.failure {
                        Text("Honeybun couldn't accept this: \(f)").font(.system(size: 14)).foregroundColor(HB.red)
                    } else {
                        Text(store.isOffline ? "It will sync as soon as you're back online." : "Waiting to sync.").font(.system(size: 14)).foregroundColor(HB.soft)
                    }
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading).hbCard()
                HBPillButton(title: item.failure == nil ? "Sync now" : "Try again") { Task { await store.retryPending(item); dismiss() } }
                    .accessibilityIdentifier("hb-pending-retry")
                Button { confirmDiscard = true } label: { Text("Discard this entry").font(.system(size: 16, weight: .semibold)).foregroundColor(HB.red).frame(maxWidth: .infinity, minHeight: 44) }
                    .accessibilityIdentifier("hb-pending-discard")
                    .confirmationDialog("Discard this saved entry? It has not reached Honeybun, so it will be gone for good.", isPresented: $confirmDiscard, titleVisibility: .visible) {
                        Button("Discard entry", role: .destructive) { Task { await store.discardPending(item); dismiss() } }
                        Button("Keep it", role: .cancel) {}
                    }
            } else {
                Text("This entry has synced.").foregroundColor(HB.soft).padding(16)
            }
        }
    }
}
