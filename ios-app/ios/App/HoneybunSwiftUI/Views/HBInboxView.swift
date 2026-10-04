import SwiftUI

// MARK: - Inbox tab: Bun's messages (bills, paydays, streaks, budgets, shared activity, carry-over, gift cards), from GET /api/inbox

@available(iOS 15.0, *)
struct HBInboxView: View {
    @ObservedObject var store: HBAppStore
    let onClose: () -> Void
    @ObservedObject private var metrics = HBLayoutMetrics.shared
    @State private var tab: HBInboxTab = .bills
    @State private var tipHidden = false
    @State private var working: Set<String> = []

    private var visible: [HBInboxMessage] { store.inboxMessages.filter { HBInbox.tab(for: $0.kind) == tab } }
    private func unreadCount(_ t: HBInboxTab) -> Int { store.inboxMessages.filter { HBInbox.tab(for: $0.kind) == t && $0.isUnread }.count }

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    tabBar
                    content.accessibilityElement(children: .contain).accessibilityIdentifier("hb-last-card")
                }
                .frame(maxWidth: 560)
                .padding(.horizontal, HB.gutter).padding(.top, 8)
                .frame(maxWidth: .infinity)
                Color.clear.frame(height: max(1, metrics.trailing)).id("hb-end").background(HBProbe(kind: .scrollEnd))
            }
        }
        .refreshable { await store.refresh(); await store.loadInbox() }
        .task {
            await store.loadInbox()
            try? await Task.sleep(nanoseconds: 1_200_000_000)   // let the new ones show as new, then mark them read on the server
            await store.markInboxRead()
        }
        #if DEBUG
        .onAppear { if store.previewScrollToEnd { DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { proxy.scrollTo("hb-end", anchor: .bottom) } } }
        #endif
        }
    }

    // MARK: header + tabs

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Bun Inbox").font(.system(size: 34, weight: .bold)).foregroundColor(.white)
            Text("Bills, updates, and helpful tips.").font(.system(size: 16)).foregroundColor(Color(red: 0.74, green: 0.69, blue: 0.9))
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(HBInboxTab.allCases, id: \.self) { t in
                Button { tab = t } label: {
                    HStack(spacing: 6) {
                        Text(t.rawValue).font(.system(size: 16, weight: .semibold))
                        if unreadCount(t) > 0 {
                            Text("\(unreadCount(t))").font(.system(size: 12, weight: .bold)).foregroundColor(tab == t ? HB.orange : Color.black.opacity(0.8))
                                .frame(minWidth: 20, minHeight: 20).background(Circle().fill(tab == t ? Color.black.opacity(0.78) : HB.orange))
                        }
                    }
                    .foregroundColor(tab == t ? Color.black.opacity(0.82) : Color(red: 0.74, green: 0.69, blue: 0.9))
                    .frame(maxWidth: .infinity, minHeight: 42)
                    .background(Capsule().fill(tab == t ? HB.orange : Color.clear).shadow(color: tab == t ? HB.orange.opacity(0.45) : .clear, radius: 8))
                }
                .accessibilityAddTraits(tab == t ? .isSelected : [])
                .accessibilityIdentifier("hb-inbox-tab-\(t.rawValue.lowercased())")
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
    }

    // MARK: content states

    @ViewBuilder private var content: some View {
        switch store.inboxState {
        case .idle, .loading:
            loadingCard
        case let .failed(msg):
            errorCard(msg)
        case .loaded:
            if store.inboxMessages.isEmpty { emptyAll } else { loadedContent }
        }
    }

    private var loadingCard: some View {
        VStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { _ in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.08)).frame(width: 40, height: 40)
                    VStack(alignment: .leading, spacing: 8) {
                        RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.10)).frame(width: 120, height: 12)
                        RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.06)).frame(height: 12)
                        RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.06)).frame(width: 180, height: 12)
                    }
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading).hbCard()
            }
            HStack(spacing: 10) { ProgressView().tint(HB.orange); Text("Bun is checking your messages…").font(.subheadline).foregroundColor(HB.soft) }.padding(.top, 4)
        }
        .accessibilityIdentifier("hb-inbox-loading")
    }

    private func errorCard(_ msg: String) -> some View {
        VStack(spacing: 12) {
            Image("HBBuddy_sleepy").resizable().scaledToFit().frame(width: 72, height: 72).clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
            Text("Couldn't load your messages").font(.system(size: 19, weight: .bold)).foregroundColor(.white)
            Text(msg).font(.subheadline).foregroundColor(HB.soft).multilineTextAlignment(.center)
            HBPillButton(title: "Try again", symbol: "arrow.clockwise") { Task { await store.loadInbox() } }.padding(.horizontal, 40)
        }
        .padding(20).frame(maxWidth: .infinity).hbCard()
        .accessibilityIdentifier("hb-inbox-error")
    }

    private var emptyAll: some View {
        VStack(spacing: 10) {
            Image("HBInboxTip").resizable().scaledToFit().frame(width: 150).accessibilityHidden(true)
            Text("No messages yet").font(.system(size: 20, weight: .bold)).foregroundColor(.white)
            Text("I'll hop in when something's coming up 🐰").font(.system(size: 16)).foregroundColor(HB.soft).multilineTextAlignment(.center)
            Text("Bill reminders, paydays, streak check-ins and news from your household show up here.").font(.footnote).foregroundColor(HB.soft).multilineTextAlignment(.center)
        }
        .padding(22).frame(maxWidth: .infinity).hbCard()
        .accessibilityIdentifier("hb-inbox-empty")
    }

    private var loadedContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            if tab == .updates && !tipHidden { tipCard }
            if visible.isEmpty {
                emptyTab
            } else {
                ForEach(Array(HBInbox.groups(visible).enumerated()), id: \.offset) { _, g in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(g.title).font(.footnote.weight(.semibold)).foregroundColor(HB.soft).padding(.leading, 4)
                        ForEach(g.items) { m in card(m) }
                    }
                }
            }
            if tab == .updates { statusCard }
        }
    }

    private var emptyTab: some View {
        let text: String = {
            switch tab {
            case .bills: return "Nothing due soon ♡"
            case .shared: return "Household activity will appear here when someone adds something shared."
            case .updates: return "No updates yet. I'll cheer you on when there's news 🐰"
            }
        }()
        return Text(text).font(.subheadline).foregroundColor(HB.soft).padding(18).frame(maxWidth: .infinity, alignment: .leading).hbCard()
            .accessibilityIdentifier("hb-inbox-empty-tab")
    }

    // MARK: Smart Tip + status

    private var tips: [String] {
        var out: [String] = []
        let subs = store.snapshot?.recurring.filter { !$0.isIncome && $0.category == "subs" } ?? []
        if !subs.isEmpty {
            let per: [String: Double] = ["weekly": 52.0 / 12, "biweekly": 26.0 / 12, "monthly": 1]
            let total = subs.reduce(0.0) { $0 + $1.amount * (per[$1.freq] ?? 1) }
            out.append("You pay about \(HBFormat.money(total.rounded(), cents: false)) a month for \(subs.count) subscription\(subs.count > 1 ? "s" : ""). Any you've stopped using? 📺")
        }
        return out + HBInbox.generalTips
    }

    private var tipCard: some View {
        let all = tips
        let day = Int(Date().timeIntervalSince1970 / 86400)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Smart Tip", systemImage: "lightbulb.fill").font(.system(size: 17, weight: .bold)).foregroundColor(HB.orange)
                Spacer()
                Button { tipHidden = true } label: { Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundColor(HB.soft).frame(width: 30, height: 30) }
                    .accessibilityLabel("Hide tip")
            }
            Text(all[day % all.count]).font(.system(size: 16)).foregroundColor(Color(red: 0.92, green: 0.88, blue: 0.97)).fixedSize(horizontal: false, vertical: true).padding(.trailing, 100)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).frame(minHeight: 112).hbCard()
        .overlay(alignment: .bottomTrailing) { Image("HBInboxTip").resizable().scaledToFit().frame(width: 104).offset(x: -6, y: 6).allowsHitTesting(false).accessibilityHidden(true) }
        .accessibilityIdentifier("hb-inbox-tip")
    }

    private var statusCard: some View {
        let me = store.member(store.myID)
        let streak = me?.streak ?? 0
        return Button { store.selectedTab = .home } label: {
            HStack(spacing: 12) {
                Image(systemName: "flame.fill").font(.system(size: 20, weight: .semibold)).foregroundColor(HB.orange)
                    .frame(width: 42, height: 42).background(Circle().fill(HB.orange.opacity(0.14))).overlay(Circle().stroke(HB.orange.opacity(0.35), lineWidth: 1))
                VStack(alignment: .leading, spacing: 2) {
                    Text(streak == 1 ? "1 day" : "\(streak) days").font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                    Text("hop streak. Here's where you are 🐰").font(.system(size: 14)).foregroundColor(HB.soft)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundColor(HB.soft)
            }
            .padding(14).frame(maxWidth: .infinity).hbCard()
        }
        .buttonStyle(.plain).accessibilityIdentifier("hb-inbox-status")
    }

    // MARK: one message

    private func avatar(_ m: HBInboxMessage) -> some View {
        Group {
            if let member = store.members.first(where: { !m.str("name").isEmpty && $0.name == m.str("name") }) {
                HBMemberAvatar(member: member, size: 42)
            } else {
                Image("HBBuddy_default").resizable().scaledToFit().frame(width: 42, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(HB.orange.opacity(0.5), lineWidth: 2))
            }
        }
    }

    private func card(_ m: HBInboxMessage) -> some View {
        let urgent = HBInbox.isUrgent(m.kind)
        let text = HBInbox.text(m, today: store.inboxTodayString, categoryName: { store.categoryName($0) })
        let action = HBInbox.action(for: m, recurringExists: { store.recurringExists($0) }, carryPending: store.carryPrompt != nil)
        return HStack(alignment: .top, spacing: 12) {
            avatar(m)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(HBInbox.heading(for: m.kind)).font(.system(size: 15, weight: .bold)).foregroundColor(urgent ? HB.orange : Color(red: 0.86, green: 0.82, blue: 0.95))
                    if m.isUnread { Text("NEW").font(.system(size: 10, weight: .heavy)).foregroundColor(Color.black.opacity(0.8)).padding(.horizontal, 6).padding(.vertical, 2).background(Capsule().fill(HB.orange)) }
                    Spacer(minLength: 4)
                    Text(HBInbox.timeText(m.date)).font(.system(size: 12)).foregroundColor(HB.soft)
                }
                Text(text).font(.system(size: 16)).foregroundColor(.white).fixedSize(horizontal: false, vertical: true)
                if let action = action { actionView(action, m) }
            }
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading).hbCard()
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(urgent ? HB.orange.opacity(0.55) : (m.isUnread ? HB.orange.opacity(0.28) : Color.clear), lineWidth: 1.2))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("hb-inbox-msg-\(m.kind)")
    }

    @ViewBuilder private func actionView(_ a: HBInboxAction, _ m: HBInboxMessage) -> some View {
        switch a {
        case let .markPaid(rid, occ, label):
            if store.isLogged(rid: rid, occ: occ) {
                Label("\(label == "Got it" ? "Got it" : "Paid") ✓", systemImage: "checkmark.circle.fill").font(.system(size: 15, weight: .semibold)).foregroundColor(HB.green).padding(.top, 2)
                    .accessibilityIdentifier("hb-inbox-done")
            } else {
                Button { markPaid(rid: rid, occ: occ, key: m.id) } label: {
                    HStack(spacing: 6) {
                        if working.contains(m.id) { ProgressView().tint(Color.black.opacity(0.8)) }
                        Text(working.contains(m.id) ? "Saving…" : label).font(.system(size: 15, weight: .bold))
                    }
                    .foregroundColor(Color.black.opacity(0.85)).padding(.horizontal, 20).frame(height: 38).background(Capsule().fill(label == "Got it" ? HB.green : HB.orange))
                }
                .disabled(working.contains(m.id)).accessibilityIdentifier("hb-inbox-paid")
            }
        case .decideCarry:
            actionButton("Decide", filled: true) { store.sheet = .carry }.accessibilityIdentifier("hb-inbox-decide")
        case .logSomething:
            actionButton("Log something", filled: true) { store.sheet = .newEntry("expense") }
        case let .openHome(l): actionButton(l, filled: false) { store.selectedTab = .home }
        case let .openMoney(l): actionButton(l, filled: false) { store.selectedTab = .money }
        case let .openGoals(l): actionButton(l, filled: false) { store.selectedTab = .goals }
        case let .openTogether(l): actionButton(l, filled: false) { store.selectedTab = .together }
        case let .classic(l): actionButton(l, filled: false) { onClose() }
        }
    }

    private func actionButton(_ title: String, filled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 15, weight: .bold)).foregroundColor(filled ? Color.black.opacity(0.85) : HB.orange)
                .padding(.horizontal, 18).frame(height: 38)
                .background(Capsule().fill(filled ? HB.orange : Color.clear))
                .overlay(Capsule().stroke(HB.orange.opacity(filled ? 0 : 0.55), lineWidth: 1))
        }
    }

    private func markPaid(rid: String, occ: String, key: String) {
        working.insert(key)
        Task {
            do { try await store.markOccurrencePaid(recurringID: rid, date: occ) } catch { store.notice = error.localizedDescription }
            working.remove(key)
        }
    }
}

// MARK: - Carry over last month's balance (POST /api/carry)

@available(iOS 15.0, *)
struct HBCarrySheet: View {
    @ObservedObject var store: HBAppStore
    @Environment(\.dismiss) private var dismiss
    @State private var remember = false
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        HBSheetScaffold(title: "New month!", onBack: { dismiss() }) {
            if let p = store.carryPrompt {
                let v = Double(p.amount_cents) / 100, neg = v < 0
                let from = HBDay.monthName(p.from), to = HBDay.monthName(HBDay.monthKey())
                VStack(spacing: 10) {
                    Image("HBInboxTip").resizable().scaledToFit().frame(width: 120).accessibilityHidden(true)
                    Text("\(from) ended at").font(.system(size: 16)).foregroundColor(HB.soft)
                    Text((v > 0 ? "+" : "") + HBFormat.money(v)).font(.system(size: 40, weight: .heavy).monospacedDigit()).foregroundColor(neg ? HB.red : HB.green)
                        .accessibilityIdentifier("hb-carry-amount")
                    Text(neg ? "Carry the shortfall into \(to)?" : "Carry it over to \(to) so it counts toward your balance?")
                        .font(.system(size: 17, weight: .semibold)).foregroundColor(.white).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(18).hbCard()
                Toggle(isOn: $remember) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Do this every month").font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
                        Text("You can change it any time in Settings.").font(.footnote).foregroundColor(HB.soft)
                    }
                }
                .tint(HB.orange).accessibilityIdentifier("hb-carry-remember")
                if let error = error { Text(error).font(.footnote.weight(.semibold)).foregroundColor(HB.red) }
                HBPillButton(title: busy ? "Saving…" : (neg ? "Carry the shortfall" : "Carry it over")) { decide(true) }.disabled(busy).accessibilityIdentifier("hb-carry-yes")
                HBPillButton(title: "Start fresh", filled: false) { decide(false) }.disabled(busy).accessibilityIdentifier("hb-carry-no")
                Button { dismiss() } label: { Text("Decide later").font(.system(size: 16, weight: .semibold)).foregroundColor(Color(red: 0.72, green: 0.68, blue: 0.9)).frame(maxWidth: .infinity, minHeight: 44) }
                    .accessibilityIdentifier("hb-carry-later")
            } else {
                HBMessageView(title: "Already decided", message: "This month's carry-over is settled. Nothing else changed.", primary: ("Back", { dismiss() }))
            }
        }
    }

    private func decide(_ accept: Bool) {
        error = nil; busy = true
        Task {
            do { try await store.decideCarry(accept: accept, remember: remember); dismiss() } catch { self.error = error.localizedDescription }
            busy = false
        }
    }
}
