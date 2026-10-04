import SwiftUI

private let hbPrettyDate: DateFormatter = {
    let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"; return f
}()

@available(iOS 15.0, *)
struct HBUpcomingRow: View {
    @ObservedObject var store: HBAppStore
    let item: HBUpcoming
    @State private var working = false
    var body: some View {
        let cat = HBCategory.of(item.recurring.category)
        HStack(spacing: 6) {
            Button { store.sheet = .editRecurring(item.recurring) } label: {
                HStack(spacing: 12) {
                    if item.recurring.isIncome { HBCircleIcon(symbol: "arrow.down", tint: HB.green, size: 40) } else { HBCircleIcon(symbol: cat.symbol, tint: Color(rgb: cat.rgb), size: 40) }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.recurring.label).font(.system(size: 17, weight: .semibold)).foregroundColor(.white).lineLimit(1)
                        Text((item.late ? "Late · " : "") + hbPrettyDate.string(from: item.date)).font(.system(size: 14)).foregroundColor(item.late ? HB.red : HB.soft)
                    }
                    Spacer(minLength: 8)
                    Text(HBFormat.money(item.recurring.amount)).font(.system(size: 17, weight: .semibold).monospacedDigit())
                        .foregroundColor(item.recurring.isIncome ? HB.green : .white)
                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundColor(HB.soft)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(item.recurring.label), edit")
            Button {
                guard !working else { return }
                working = true
                Task { do { try await store.markPaid(item) } catch { store.notice = error.localizedDescription }; working = false }
            } label: {
                Image(systemName: working ? "hourglass" : "checkmark").font(.system(size: 13, weight: .bold)).foregroundColor(HB.orange)
                    .frame(width: 32, height: 32).overlay(Circle().stroke(HB.orange.opacity(0.5), lineWidth: 1))
            }
            .accessibilityLabel(item.recurring.isIncome ? "Mark received" : "Mark paid")
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
    }
}

@available(iOS 15.0, *)
struct HBHomeView: View {
    @ObservedObject var store: HBAppStore
    @ObservedObject private var metrics = HBLayoutMetrics.shared
    let onClose: () -> Void

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let hero = min(max(w * 0.40, 128), 190)       // witch width follows the screen
            let heroH = hero * 0.907
            let overlap: CGFloat = 36                      // how far the hero's honey dips into the card
            ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 11) {
                    classicLink
                    header(heroH: heroH, overlap: overlap)
                    summaryCard(hero: hero, heroH: heroH, overlap: overlap)
                    actions
                    comingUp
                    streakCard
                    latest
                    if let n = store.notice { Text(n).font(.footnote).foregroundColor(HB.red).onTapGesture { store.notice = nil } }
                }
                .frame(maxWidth: 560)
                .padding(.horizontal, HB.gutter).padding(.top, 4)
                .frame(maxWidth: .infinity)
                // real, measured room under the last card so it can be dragged completely clear of the tab bar (see HBLayoutMetrics)
                Color.clear.frame(height: max(1, metrics.trailing)).id("hb-end").background(HBProbe(kind: .scrollEnd))
                }
            }
            .refreshable { await store.refresh() }
            #if DEBUG
            .onAppear { if store.previewScrollToEnd { DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { proxy.scrollTo("hb-end", anchor: .bottom) } } }
            #endif
            }
        }
    }

    // Beta only: the way back to the classic app. Removed when native becomes the default.
    private var classicLink: some View {
        Button(action: onClose) {
            HStack(spacing: 4) { Image(systemName: "chevron.left").font(.system(size: 11, weight: .bold)); Text("Classic") }
                .font(.system(size: 13, weight: .semibold)).foregroundColor(HB.orange.opacity(0.9))
        }
        .accessibilityLabel("Open classic Honeybun")
    }

    private func header(heroH: CGFloat, overlap: CGFloat) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HBWordmark(size: 34)
                Text("A happier way to manage\nmoney together.").font(.system(size: 15, weight: .medium)).foregroundColor(Color(red: 0.74, green: 0.69, blue: 0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button { store.selectedTab = .inbox } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell").font(.system(size: 18, weight: .medium)).foregroundColor(.white)
                        .frame(width: 44, height: 44).background(Circle().fill(Color.white.opacity(0.08))).overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                    if store.unread > 0 { Circle().fill(Color(red: 1, green: 0.37, blue: 0.53)).frame(width: 10, height: 10).offset(x: -3, y: 3) }
                }
            }
            .accessibilityLabel("Messages from Bun")
            .zIndex(2)
        }
        // room above the card so the hero's hat rises beside the wordmark instead of off the screen
        .padding(.bottom, max(0, heroH - overlap - 82))
    }

    private func summaryCard(hero: CGFloat, heroH: CGFloat, overlap: CGFloat) -> some View {
        let total = store.income + store.carry
        let ratio = total > 0 ? min(1, store.spent / total) : (store.spent > 0 ? 1 : 0)
        return VStack(alignment: .leading, spacing: 6) {
            Text(store.isJoint ? "Safe to spend · Joint" : "Safe to spend").font(.system(size: 20, weight: .semibold)).foregroundColor(Color(red: 1, green: 0.96, blue: 0.9))
                .padding(.trailing, hero * 0.55)
            HStack(alignment: .center) {
                Text(HBFormat.money(store.left)).font(.system(size: 42, weight: .heavy).monospacedDigit())
                    .minimumScaleFactor(0.5).lineLimit(1).foregroundColor(store.left < 0 ? HB.red : .white)
                    .shadow(color: .black.opacity(0.35), radius: 8, y: 2)
                Spacer(minLength: 6)
                HBMonthMenu(store: store)
            }
            .padding(.top, max(0, 6))
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.28))
                    Capsule().fill(LinearGradient(colors: [store.spent > total ? HB.red : Color(red: 1, green: 0.74, blue: 0.33), Color(red: 1, green: 0.83, blue: 0.5)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(10, g.size.width * CGFloat(ratio)))
                }
            }
            .frame(height: 14).padding(.top, 6)
            HStack {
                Text("\(HBFormat.money(store.spent, cents: false)) of \(HBFormat.money(total, cents: false))").font(.system(size: 16)).foregroundColor(Color(red: 0.98, green: 0.92, blue: 0.84))
                Spacer()
                Text("\(Int((ratio * 100).rounded()))%").font(.system(size: 16, weight: .semibold)).foregroundColor(Color(red: 0.98, green: 0.92, blue: 0.84))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous).fill(
                LinearGradient(colors: [Color(red: 0.43, green: 0.25, blue: 0.12), Color(red: 0.24, green: 0.14, blue: 0.09)], startPoint: .topTrailing, endPoint: .bottomLeading))
        )
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(HB.orange.opacity(0.55), lineWidth: 1.5))
        .shadow(color: HB.orange.opacity(0.18), radius: 16, y: 4)
        .overlay(alignment: .topTrailing) {
            Image("HBHero").resizable().scaledToFit().frame(width: hero)
                .offset(x: -8, y: -(heroH - overlap))
                .allowsHitTesting(false).accessibilityHidden(true)
        }
    }

    private var actions: some View {
        HStack(spacing: 12) {
            actionButton("Add expense", tint: HB.orange) { store.sheet = .newEntry("expense") }
            actionButton("Add income", tint: HB.green) { store.sheet = .newEntry("income") }
        }
    }
    private func actionButton(_ title: String, tint: Color, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "plus").font(.system(size: 15, weight: .heavy)).foregroundColor(Color.black.opacity(0.78))
                    .frame(width: 32, height: 32).background(Circle().fill(tint))
                    .shadow(color: tint.opacity(0.5), radius: 8)
                Text(title).font(.system(size: 16, weight: .semibold)).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(tint.opacity(0.10)))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(tint.opacity(0.4), lineWidth: 1))
        }
    }

    private var comingUp: some View {
        let items = store.upcoming
        return VStack(alignment: .leading, spacing: 8) {
            HBSectionHeader(title: "Coming up", action: "See all") { store.sheet = .upcoming }
            VStack(spacing: 0) {
                if items.isEmpty {
                    HStack {
                        Text("Add rent, bills and paydays once.").font(.subheadline).foregroundColor(HB.soft)
                        Spacer()
                        Button("Add") { store.sheet = .newRecurring }.font(.subheadline.weight(.bold)).foregroundColor(HB.orange)
                    }.padding(16)
                } else {
                    ForEach(Array(items.prefix(3).enumerated()), id: \.element.id) { i, item in
                        if i > 0 { Divider().background(HB.line).padding(.leading, 66) }
                        HBUpcomingRow(store: store, item: item)
                    }
                }
            }
            .hbCard()
        }
    }

    // The illustrated streak card. The count is the real streak from your account.
    private var streakCard: some View {
        let n = store.streak
        return HStack(spacing: 10) {
            Image("HBStreak").resizable().scaledToFit().frame(width: 70, height: 70).accessibilityHidden(true)
            Image(systemName: "flame.fill").font(.system(size: 34)).foregroundStyle(LinearGradient(colors: [Color(red: 1, green: 0.78, blue: 0.3), Color(red: 1, green: 0.38, blue: 0.2)], startPoint: .top, endPoint: .bottom))
                .shadow(color: Color(red: 1, green: 0.4, blue: 0.1).opacity(0.5), radius: 8)
            VStack(alignment: .leading, spacing: 3) {
                Text(n > 0 ? "\(n) day streak" : "Start a streak").font(.system(size: 21, weight: .bold)).foregroundColor(Color(red: 1, green: 0.83, blue: 0.48)).minimumScaleFactor(0.7).lineLimit(1)
                Text(n > 0 ? "Keep it going!" : "Log something today").font(.system(size: 15)).foregroundColor(Color(red: 0.74, green: 0.69, blue: 0.9))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(LinearGradient(colors: [Color(red: 0.24, green: 0.15, blue: 0.14), Color(red: 0.13, green: 0.09, blue: 0.14)], startPoint: .leading, endPoint: .trailing)))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(HB.orange.opacity(0.30), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var latest: some View {
        let recent = Array(store.entries.prefix(4))
        return VStack(alignment: .leading, spacing: 8) {
            HBSectionHeader(title: "Latest", action: "See all") { store.sheet = .allTransactions }
            VStack(spacing: 0) {
                if recent.isEmpty {
                    Text("Nothing yet this month. Add your first expense or income.").font(.subheadline).foregroundColor(HB.soft).padding(16)
                } else {
                    ForEach(Array(recent.enumerated()), id: \.element.id) { i, e in
                        if i > 0 { Divider().background(HB.line).padding(.leading, 66) }
                        Button { store.sheet = .editEntry(e) } label: { HBEntryRow(entry: e, who: store.members.count > 1 ? store.memberName(e.member_id) : nil) }
                            .buttonStyle(.plain)
                    }
                }
            }
            .hbCard()
        }
    }
}
