import SwiftUI

// MARK: - small pieces shared by the Together screens

/// A member's picture: the buddy they picked (same artwork as the website) on their own colour.
@available(iOS 15.0, *)
struct HBMemberAvatar: View {
    let member: HBMember
    var size: CGFloat = 44
    var body: some View {
        ZStack {
            Circle().fill(Color(hex: member.color) ?? HB.orange)
            if let name = HBTogether.buddyAsset(member.emoji) {
                Image(name).resizable().scaledToFit().padding(size * 0.06)
            } else {
                Text(String(member.name.first ?? "?").uppercased()).font(.system(size: size * 0.45, weight: .bold)).foregroundColor(Color.black.opacity(0.7))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
        .accessibilityHidden(true)
    }
}

/// The back-arrow + centred title used at the top of every Together sheet (same as the Goals sheets).
@available(iOS 15.0, *)
struct HBSheetTitle: View {
    let title: String
    let onBack: () -> Void
    var body: some View {
        ZStack {
            HStack {
                Button(action: onBack) { Image(systemName: "arrow.left").font(.system(size: 20, weight: .medium)).foregroundColor(.white).frame(width: 44, height: 44) }
                    .accessibilityLabel("Back")
                Spacer()
            }
            Text(title).font(.system(size: 22, weight: .bold)).foregroundColor(.white)
        }
    }
}

@available(iOS 15.0, *)
struct HBPillButton: View {
    let title: String
    var symbol: String? = nil
    var filled = true
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let s = symbol { Image(systemName: s).font(.system(size: 15, weight: .semibold)) }
                Text(title).font(.system(size: 17, weight: .bold))
            }
            .foregroundColor(filled ? Color.black.opacity(0.85) : HB.orange)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Capsule().fill(filled ? HB.orange : Color.clear))
            .overlay(Capsule().stroke(HB.orange.opacity(filled ? 0 : 0.55), lineWidth: 1))
            .shadow(color: filled ? HB.orange.opacity(0.35) : .clear, radius: 10, y: 3)
        }
    }
}

// MARK: - Together tab

@available(iOS 15.0, *)
struct HBTogetherView: View {
    @ObservedObject var store: HBAppStore
    @ObservedObject private var metrics = HBLayoutMetrics.shared
    @State private var newItem = ""
    @State private var adding = false
    @State private var removing: HBSettlement?
    @FocusState private var addFocused: Bool

    private var inviteWord: String { store.kind == "family" ? "your family" : (store.kind == "couple" ? "your partner" : "someone") }

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    balanceCard
                    householdCard
                    shoppingCard
                    if store.situation != .solo && !store.jointActive { paymentsCard }
                    if let n = store.notice { Text(n).font(.footnote).foregroundColor(HB.red).onTapGesture { store.notice = nil } }
                    searchRow
                }
                .frame(maxWidth: 560)
                .padding(.horizontal, HB.gutter).padding(.top, 8)
                .frame(maxWidth: .infinity)
                Color.clear.frame(height: max(1, metrics.trailing)).id("hb-end").background(HBProbe(kind: .scrollEnd))
            }
        }
        .refreshable { await store.refresh(); await store.loadShopping() }
        .task { await store.loadShopping() }
        #if DEBUG
        .onAppear { if store.previewScrollToEnd { DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { proxy.scrollTo("hb-end", anchor: .bottom) } } }
        #endif
        .confirmationDialog("Remove this payment?", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }), titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                if let r = removing { Task { do { try await store.deleteSettlement(id: r.id) } catch { store.notice = error.localizedDescription } } }
                removing = nil
            }
            Button("Keep it", role: .cancel) { removing = nil }
        } message: { Text("The balance will go back to what it was before.") }
        }
    }

    // MARK: header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Together").font(.system(size: 34, weight: .bold)).foregroundColor(.white)
                Text("Same goals. Happier habits.").font(.system(size: 16)).foregroundColor(Color(red: 0.74, green: 0.69, blue: 0.9))
            }
            Spacer(minLength: 8)
            Button { store.sheet = .newEntry("expense") } label: {
                Image(systemName: "plus").font(.system(size: 20, weight: .medium)).foregroundColor(.white)
                    .frame(width: 44, height: 44).background(Circle().fill(Color.white.opacity(0.08))).overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
            }
            .accessibilityLabel("Add a shared expense").accessibilityIdentifier("hb-together-add")
        }
    }

    // MARK: balance / joint / solo

    private var balanceCard: some View {
        Group {
            if store.situation == .solo { soloCard }
            else if store.jointActive { jointCard }
            else { fairShareCard }
        }
        .overlay(alignment: .bottomTrailing) { HBTogetherPeek() }
    }

    private var soloCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Fair share balance", systemImage: "scalemass").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
            Text("Just you for now").font(.system(size: 26, weight: .heavy)).foregroundColor(.white)
            Text("Invite \(inviteWord) and Honeybun keeps track of who paid for what, so nobody has to do the maths.")
                .font(.system(size: 16)).foregroundColor(HB.soft).fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 10) {
                HBPillButton(title: "Invite \(inviteWord)", symbol: "person.badge.plus") { store.sheet = .household(true) }
                    .accessibilityIdentifier("hb-together-solo-invite")
                Text("You can still use the shared list below on your own.").font(.footnote).foregroundColor(HB.soft)
            }
            .padding(.trailing, 108)
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading).hbCard()
    }

    private var jointCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Joint account", systemImage: "circle.grid.2x2.fill").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                Spacer(minLength: 8)
                HBMonthMenu(store: store)
            }
            HStack(alignment: .top) {
                amountColumn("Came in", store.income, HB.green)
                Spacer()
                amountColumn("Spent", store.spent, HB.red)
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("One shared pot, so the numbers add up together and nobody owes anybody.").font(.footnote).foregroundColor(HB.soft)
                HBPillButton(title: "Details", filled: false) { store.sheet = .fairShare }.accessibilityIdentifier("hb-together-details")
            }
            .padding(.trailing, 108)
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading).hbCard()
    }

    private var fairShareCard: some View {
        let pairs = store.pairs
        let other = store.partner?.name ?? "They"
        return VStack(alignment: .leading, spacing: 14) {
            Label("Fair share balance", systemImage: "scalemass").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
            HStack(alignment: .top) {
                amountColumn("You owe", store.iOwe, HB.red)
                Spacer()
                amountColumn(store.situation == .partner ? "\(other) owes" : "You're owed", store.owedToMe, HB.green, alignment: .trailing)
            }
            if pairs.isEmpty {
                Text("You're all even ♡").font(.system(size: 16, weight: .semibold)).foregroundColor(HB.green)
            } else if store.situation == .family || pairs.count > 1 {
                VStack(spacing: 0) {
                    ForEach(Array(pairs.enumerated()), id: \.element.id) { i, p in
                        if i > 0 { Divider().background(HB.line) }
                        HStack(spacing: 10) {
                            HBMemberAvatar(member: p.from, size: 34)
                            Text("\(name(p.from)) owes \(name(p.to))").font(.system(size: 15, weight: .semibold)).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.8)
                            Spacer(minLength: 6)
                            Text(HBFormat.money(p.amount)).font(.system(size: 15, weight: .bold).monospacedDigit()).foregroundColor(.white)
                            Button { store.sheet = .settle(p.from.id, p.to.id) } label: {
                                Text("Mark paid").font(.system(size: 13, weight: .semibold)).foregroundColor(HB.orange)
                                    .padding(.horizontal, 10).frame(height: 30).overlay(Capsule().stroke(HB.orange.opacity(0.55), lineWidth: 1))
                            }
                            .accessibilityIdentifier("hb-pay-\(i)")
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                if let first = pairs.first(where: { $0.from.id == store.myID || $0.to.id == store.myID }) ?? pairs.first {
                    HBPillButton(title: "Settle Up", symbol: "creditcard") { store.sheet = .settle(first.from.id, first.to.id) }.accessibilityIdentifier("hb-together-settle")
                    Button { store.sheet = .fairShare } label: {
                        Text("Fair share details").font(.system(size: 15, weight: .semibold)).foregroundColor(Color(red: 0.72, green: 0.68, blue: 0.9)).frame(maxWidth: .infinity)
                    }
                    .accessibilityIdentifier("hb-together-details")
                } else {
                    HBPillButton(title: "Fair share", filled: false) { store.sheet = .fairShare }.accessibilityIdentifier("hb-together-details")
                }
            }
            .padding(.trailing, 108)
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading).hbCard()
    }

    private func name(_ m: HBMember) -> String { m.id == store.myID ? "You" : m.name }

    private func amountColumn(_ title: String, _ value: Double, _ tint: Color, alignment: HorizontalAlignment = .leading) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(title).font(.system(size: 15)).foregroundColor(HB.soft).lineLimit(1)
            Text(HBFormat.money(value)).font(.system(size: 28, weight: .heavy).monospacedDigit()).foregroundColor(tint).minimumScaleFactor(0.7).lineLimit(1)
        }
    }

    // MARK: household

    private var householdCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Button { store.sheet = .household(false) } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.2.fill").font(.system(size: 17, weight: .semibold)).foregroundColor(HB.orange)
                            .frame(width: 40, height: 40).background(Circle().fill(HB.orange.opacity(0.14))).overlay(Circle().stroke(HB.orange.opacity(0.35), lineWidth: 1))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Household").font(.system(size: 19, weight: .bold)).foregroundColor(.white)
                            Text("\(store.members.count) member\(store.members.count == 1 ? "" : "s") · \(HBTogether.kindName(store.kind))").font(.system(size: 14)).foregroundColor(HB.soft)
                        }
                    }
                }
                .buttonStyle(.plain).accessibilityIdentifier("hb-household")
                Spacer(minLength: 8)
                Button { store.sheet = .household(true) } label: {
                    HStack(spacing: 6) { Image(systemName: "person.badge.plus").font(.system(size: 14, weight: .semibold)); Text("Invite").font(.system(size: 15, weight: .semibold)) }
                        .foregroundColor(.white).padding(.horizontal, 14).frame(height: 38)
                        .background(Capsule().fill(Color.white.opacity(0.07))).overlay(Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1))
                }
                .accessibilityIdentifier("hb-invite")
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(store.members) { m in
                        VStack(spacing: 6) {
                            HBMemberAvatar(member: m, size: 56).overlay(Circle().stroke(m.id == store.myID ? HB.orange : Color.clear, lineWidth: 2))
                            Text(m.id == store.myID ? "You" : m.name).font(.system(size: 14)).foregroundColor(.white).lineLimit(1).frame(maxWidth: 72)
                        }
                    }
                    Button { store.sheet = .household(true) } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "plus").font(.system(size: 20, weight: .medium)).foregroundColor(HB.soft)
                                .frame(width: 56, height: 56).overlay(Circle().strokeBorder(Color.white.opacity(0.28), style: StrokeStyle(lineWidth: 1.2, dash: [4, 4])))
                            Text("Invite").font(.system(size: 14)).foregroundColor(HB.soft)
                        }
                    }
                }
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).hbCard()
    }

    // MARK: shopping

    private var openItems: [HBShopItem] { store.shopping.filter { !$0.done } }

    private var shoppingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Shared Shopping List", systemImage: "cart").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                Spacer(minLength: 8)
                Button { store.sheet = .shopping } label: {
                    HStack(spacing: 3) { Text("See all"); Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)) }
                        .font(.subheadline.weight(.semibold)).foregroundColor(Color(red: 0.72, green: 0.68, blue: 0.9))
                }
                .accessibilityIdentifier("hb-shop-seeall")
            }
            switch store.shopState {
            case .idle, .loading:
                HStack(spacing: 10) { ProgressView().tint(HB.orange); Text("Loading the list…").font(.subheadline).foregroundColor(HB.soft) }.padding(.vertical, 6)
            case let .failed(msg):
                VStack(alignment: .leading, spacing: 8) {
                    Text("Couldn't load the list. \(msg)").font(.subheadline).foregroundColor(HB.red).fixedSize(horizontal: false, vertical: true)
                    Button("Try again") { Task { await store.loadShopping() } }.font(.subheadline.weight(.semibold)).foregroundColor(HB.orange)
                }
            case .loaded:
                if openItems.isEmpty {
                    Text(store.shopping.isEmpty ? "Nothing on the list yet." : "Everything is ticked off.").font(.subheadline).foregroundColor(HB.soft).padding(.vertical, 4)
                }
                ForEach(openItems.prefix(4)) { item in
                    Button { Task { do { try await store.setShopDone(item, done: true) } catch { store.notice = error.localizedDescription } } } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "circle").font(.system(size: 22)).foregroundColor(Color.white.opacity(0.45))
                            Text(item.label).font(.system(size: 17)).foregroundColor(.white).lineLimit(1)
                            Spacer()
                        }
                        .frame(minHeight: 34).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).accessibilityLabel("Tick off \(item.label)").accessibilityIdentifier("hb-shop-item")
                }
            }
            HStack(spacing: 10) {
                TextField("Add an item…", text: $newItem)
                    .focused($addFocused).submitLabel(.done).onSubmit(addItem)
                    .font(.system(size: 17)).foregroundColor(.white).padding(.horizontal, 16).frame(minHeight: 46)
                    .background(RoundedRectangle(cornerRadius: 23, style: .continuous).fill(Color.white.opacity(0.05)))
                    .overlay(RoundedRectangle(cornerRadius: 23, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
                    .accessibilityIdentifier("hb-shop-input")
                Button(action: addItem) {
                    Image(systemName: "plus").font(.system(size: 18, weight: .bold)).foregroundColor(Color.black.opacity(0.85))
                        .frame(width: 46, height: 46).background(Circle().fill(HB.orange))
                }
                .disabled(adding).accessibilityLabel("Add to the shopping list").accessibilityIdentifier("hb-shop-add")
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).hbCard()
    }

    private func addItem() {
        let v = newItem.trimmingCharacters(in: .whitespaces)
        guard !v.isEmpty else { return }
        adding = true
        Task {
            do { try await store.addShopItem(v); newItem = "" } catch { store.notice = error.localizedDescription }
            adding = false
        }
    }

    // MARK: payments

    private var paymentsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Payment history").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
            let list = Array(store.settlements.prefix(4))
            if list.isEmpty {
                Text("No payments yet.").font(.subheadline).foregroundColor(HB.soft)
            }
            ForEach(Array(list.enumerated()), id: \.element.id) { i, s in
                if i > 0 { Divider().background(HB.line) }
                HStack(spacing: 12) {
                    if let f = store.member(s.from_id) { HBMemberAvatar(member: f, size: 38) }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(store.memberName(s.from_id)) paid \(store.memberName(s.to_id))").font(.system(size: 16, weight: .semibold)).foregroundColor(.white).lineLimit(1)
                        Text(HBDay.short(s.date)).font(.system(size: 13)).foregroundColor(HB.soft)
                    }
                    Spacer(minLength: 6)
                    Text(HBFormat.money(s.amount)).font(.system(size: 16, weight: .semibold).monospacedDigit()).foregroundColor(.white)
                    Button { removing = s } label: { Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundColor(HB.soft).frame(width: 30, height: 30) }
                        .accessibilityLabel("Remove this payment").accessibilityIdentifier("hb-payment-remove")
                }
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).hbCard()
    }

    // MARK: search

    private var searchRow: some View {
        Button { store.sheet = .search } label: {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass").font(.system(size: 17, weight: .semibold)).foregroundColor(HB.orange)
                Text("Search everything").font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
                Spacer()
                Text("\(store.entries.count) this month").font(.system(size: 14)).foregroundColor(HB.soft)
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundColor(HB.soft)
            }
            .padding(.horizontal, 16).frame(minHeight: 60).frame(maxWidth: .infinity).hbCard()
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine).accessibilityIdentifier("hb-last-card")
    }
}

// The supplied together-peek.png (the witch bunny on its honey) sitting on the bottom-right corner of the balance card, as in the mockup.
@available(iOS 15.0, *)
struct HBTogetherPeek: View {
    var body: some View {
        Image("HBTogetherPeek").resizable().scaledToFit().frame(width: 96)
            .offset(x: -10, y: 16).allowsHitTesting(false).accessibilityHidden(true)
    }
}
