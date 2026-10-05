import SwiftUI

// Home: "Heads up from Bun" (budget warnings, price changes, forecast, quiet-day nudge), the "confirm your email" reminder, and the offline /
// waiting-to-sync notices. The rules live in HBHeadsUp.swift; this is only how they look.

@available(iOS 15.0, *)
struct HBHeadsUpSection: View {
    @ObservedObject var store: HBAppStore
    @State private var seen = HBHeadsUpRules.seen()

    private var data: HBHeadsUp? {
        guard let s = store.snapshot else { return nil }
        let forecast = HBPlan.forecast(s, month: store.month, myID: store.myID, lastMonthSpent: store.prevSpent)
        return HBHeadsUpRules.compute(s, month: store.month, me: store.member(store.myID), seen: seen, forecast: forecast)
    }

    var body: some View {
        if let d = data, !d.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                if let days = d.sleepyDays { sleepy(days) }
                if !d.rows.isEmpty {
                    HBSectionHeader(title: "Heads up from Bun")
                    VStack(spacing: 0) {
                        ForEach(Array(d.rows.enumerated()), id: \.element.id) { i, row in
                            if i > 0 { Divider().background(HB.line).padding(.leading, 62) }
                            rowView(row)
                        }
                    }
                    .hbCard()
                    .accessibilityElement(children: .contain).accessibilityIdentifier("hb-heads-up")
                }
            }
        }
    }

    private func sleepy(_ days: Int) -> some View {
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

    @ViewBuilder private func icon(_ r: HBHeadsUpRow) -> some View {
        switch r.kind {
        case let .budget(category, _): HBCatIcon(style: HBCatStyle.of(category), size: 40)
        case .priceUp: HBCircleIcon(symbol: "chart.line.uptrend.xyaxis", tint: HB.red, size: 40)
        case .priceDown: HBCircleIcon(symbol: "arrow.down.right", tint: HB.green, size: 40)
        case let .forecast(short): HBCircleIcon(symbol: short ? "exclamationmark.triangle.fill" : "sparkles", tint: short ? HB.red : HB.orange, size: 40)
        }
    }

    private func rowView(_ r: HBHeadsUpRow) -> some View {
        HStack(spacing: 12) {
            Button { if r.dismissKey == nil { store.sheet = .plan } } label: {
                HStack(spacing: 12) {
                    icon(r)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(r.title).font(.system(size: 16, weight: .semibold)).foregroundColor(.white).fixedSize(horizontal: false, vertical: true)
                        if case let .budget(_, ratio) = r.kind {
                            GeometryReader { g in ZStack(alignment: .leading) {
                                Capsule().fill(Color.black.opacity(0.28))
                                Capsule().fill(ratio > 1 ? HB.red : HB.orange).frame(width: max(6, g.size.width * CGFloat(min(1, ratio))))
                            } }.frame(height: 6)
                        }
                        Text(r.note).font(.system(size: 13)).foregroundColor(r.kind == .forecast(short: true) ? HB.red : HB.soft).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    if r.dismissKey == nil { Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundColor(HB.soft) }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if let key = r.dismissKey {
                Button { HBHeadsUpRules.dismiss(key); seen = HBHeadsUpRules.seen() } label: {
                    Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundColor(HB.soft).frame(width: 32, height: 32)
                }
                .accessibilityLabel("Dismiss").accessibilityIdentifier("hb-headsup-dismiss")
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
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
