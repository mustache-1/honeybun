import SwiftUI
import UIKit

// The screens that open from Together: settle up, fair share, household (members, invite, budget type), the shared shopping list, and search.
// Every action calls the same endpoints the website uses (see HBAPI) and the screen redraws from the refreshed snapshot.

@available(iOS 15.0, *)
struct HBSheetScaffold<Content: View>: View {
    let title: String
    let onBack: () -> Void
    @ViewBuilder var content: Content
    var body: some View {
        NavigationView {
            ZStack {
                HBBackground(glow: false, scene: false)
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HBSheetTitle(title: title, onBack: onBack)
                        content
                    }
                    .frame(maxWidth: 560).padding(.horizontal, HB.gutter).padding(.top, 6).padding(.bottom, 28)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationBarHidden(true)
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { hbHideKeyboard() } } }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.dark)
    }
}

@available(iOS 15.0, *)
private func hbField(_ placeholder: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
    TextField("", text: text).keyboardType(keyboard).font(.system(size: 18)).foregroundColor(.white)
        .padding(.horizontal, 16).frame(minHeight: 52)
        .overlay(alignment: .leading) { if text.wrappedValue.isEmpty { Text(placeholder).font(.system(size: 18)).foregroundColor(Color.white.opacity(0.45)).padding(.leading, 16).allowsHitTesting(false) } }
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
}

// MARK: - Settle up

@available(iOS 15.0, *)
struct HBSettleSheet: View {
    @ObservedObject var store: HBAppStore
    let fromID: String
    let toID: String
    @Environment(\.dismiss) private var dismiss
    @State private var amountText: String
    @State private var error: String?
    @State private var saving = false

    init(store: HBAppStore, fromID: String, toID: String) {
        self.store = store; self.fromID = fromID; self.toID = toID
        let p = store.pairs.first { $0.from.id == fromID && $0.to.id == toID }
        _amountText = State(initialValue: p.map { String(format: "%.2f", $0.amount) } ?? "")
    }

    var body: some View {
        HBSheetScaffold(title: "Settle up", onBack: { dismiss() }) {
            if let f = store.member(fromID), let t = store.member(toID) {
                VStack(spacing: 14) {
                    HStack(spacing: 14) {
                        HBMemberAvatar(member: f, size: 56)
                        Image(systemName: "arrow.right").font(.system(size: 18, weight: .bold)).foregroundColor(HB.orange)
                        HBMemberAvatar(member: t, size: 56)
                    }
                    Text("\(f.id == store.myID ? "You" : f.name) paid \(t.id == store.myID ? "you" : t.name) back.")
                        .font(.system(size: 20, weight: .bold)).foregroundColor(.white).multilineTextAlignment(.center)
                    Text("Enter what was paid. The balance goes down by that much.").font(.subheadline).foregroundColor(HB.soft).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(18).hbCard()
                HBField(title: "Amount") {
                    HStack {
                        Text("$").font(.title2.weight(.bold)).foregroundColor(HB.soft)
                        TextField("0.00", text: $amountText).keyboardType(.decimalPad).font(.system(size: 30, weight: .heavy).monospacedDigit()).foregroundColor(.white)
                            .accessibilityIdentifier("hb-settle-amount")
                    }
                    .padding(14).hbCard()
                }
                if let error = error { Text(error).font(.footnote.weight(.semibold)).foregroundColor(HB.red) }
                Button(action: save) {
                    Text(saving ? "Saving…" : "Mark as paid").font(.system(size: 19, weight: .bold)).foregroundColor(Color.black.opacity(0.85))
                        .frame(maxWidth: .infinity, minHeight: 56).background(Capsule().fill(HB.orange)).shadow(color: HB.orange.opacity(0.4), radius: 12, y: 4)
                }
                .disabled(saving).accessibilityIdentifier("hb-settle-save")
            } else {
                HBMessageView(title: "That payment is gone", message: "The balance changed. Nothing else did.", primary: ("Back", { dismiss() }))
            }
        }
    }

    private func save() {
        hbHideKeyboard(); error = nil
        guard let amount = hbParseAmount(amountText) else { error = "Enter the amount that was paid."; return }
        saving = true
        Task {
            do { try await store.settle(from: fromID, to: toID, amount: amount); dismiss() } catch { self.error = error.localizedDescription }
            saving = false
        }
    }
}

// MARK: - Fair share

@available(iOS 15.0, *)
private struct HBShareBar: View {
    let parts: [(Color, Double)]
    var body: some View {
        GeometryReader { g in
            let total = max(parts.reduce(0) { $0 + $1.1 }, 0.0001)
            HStack(spacing: 2) {
                ForEach(0..<parts.count, id: \.self) { i in
                    Capsule().fill(parts[i].0).frame(width: max(0, (g.size.width - CGFloat(parts.count - 1) * 2) * CGFloat(parts[i].1 / total)))
                }
            }
        }
        .frame(height: 10)
        .background(Capsule().fill(Color.white.opacity(0.08)))
        .clipShape(Capsule())
    }
}

@available(iOS 15.0, *)
struct HBFairShareSheet: View {
    @ObservedObject var store: HBAppStore
    @Environment(\.dismiss) private var dismiss

    private func who(_ m: HBMember) -> String { m.id == store.myID ? "You" : m.name }

    var body: some View {
        HBSheetScaffold(title: store.jointActive ? "Joint account" : "Fair share", onBack: { dismiss() }) {
            if store.members.count < 2 {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Invite someone to see who brings in and spends what.").font(.system(size: 16)).foregroundColor(HB.soft)
                    HBPillButton(title: "Invite someone", symbol: "person.badge.plus") { store.sheet = .household(true) }
                }
                .padding(18).frame(maxWidth: .infinity, alignment: .leading).hbCard()
            } else {
                let totals = HBTogether.totals(members: store.members, entries: store.entries)
                let inc = totals.reduce(0) { $0 + $1.income }, out = totals.reduce(0) { $0 + $1.spent }
                section("Brought in · \(HBDay.monthName(store.month))") {
                    ForEach(totals) { t in personRow(t.member, value: t.income, sub: "\(HBTogether.percent(t.income, of: inc))%") }
                    HBShareBar(parts: totals.map { (Color(hex: $0.member.color) ?? HB.orange, $0.income) })
                    totalRow(inc)
                }
                section("Spent so far") {
                    ForEach(totals) { t in
                        personRow(t.member, value: t.spent,
                                  sub: store.jointActive ? "\(HBTogether.percent(t.spent, of: out))%" : "shared \(HBFormat.money(t.shared)) · own \(HBFormat.money(t.own))")
                    }
                    totalRow(out)
                    Text("Private entries only count for the person who made them.").font(.footnote).foregroundColor(HB.soft)
                }
                if store.jointActive {
                    section("Joint account") {
                        Text("One shared pot, so the numbers add up together.").font(.footnote).foregroundColor(HB.soft)
                        HStack { Text("Came in").foregroundColor(.white); Spacer(); Text(HBFormat.money(inc)).foregroundColor(HB.green).monospacedDigit() }
                        HStack { Text("Spent").foregroundColor(.white); Spacer(); Text(HBFormat.money(out)).foregroundColor(HB.red).monospacedDigit() }
                        Divider().background(HB.line)
                        HStack { Text("Left").font(.system(size: 17, weight: .bold)).foregroundColor(.white); Spacer(); Text(HBFormat.money(inc - out)).font(.system(size: 17, weight: .bold)).foregroundColor(.white).monospacedDigit() }
                    }
                } else {
                    section("Balance") {
                        if store.pairs.isEmpty {
                            Text("You're all even ♡").font(.system(size: 16, weight: .semibold)).foregroundColor(HB.green)
                        }
                        ForEach(store.pairs) { p in
                            HStack(spacing: 10) {
                                HBMemberAvatar(member: p.from, size: 36)
                                Text("\(p.from.id == store.myID ? "You owe" : p.from.name + " owes") \(p.to.id == store.myID ? "you" : p.to.name)")
                                    .font(.system(size: 16, weight: .semibold)).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.8)
                                Spacer(minLength: 6)
                                Text(HBFormat.money(p.amount)).font(.system(size: 16, weight: .bold).monospacedDigit()).foregroundColor(.white)
                                Button { store.sheet = .settle(p.from.id, p.to.id) } label: {
                                    Text("Mark paid").font(.system(size: 13, weight: .semibold)).foregroundColor(HB.orange)
                                        .padding(.horizontal, 10).frame(height: 30).overlay(Capsule().stroke(HB.orange.opacity(0.55), lineWidth: 1))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.system(size: 18, weight: .bold)).foregroundColor(.white)
            content()
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).hbCard()
    }

    private func personRow(_ m: HBMember, value: Double, sub: String) -> some View {
        HStack(spacing: 12) {
            HBMemberAvatar(member: m, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(who(m)).font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                Text(sub).font(.system(size: 13)).foregroundColor(HB.soft).lineLimit(1).minimumScaleFactor(0.8)
            }
            Spacer(minLength: 6)
            Text(HBFormat.money(value)).font(.system(size: 17, weight: .bold).monospacedDigit()).foregroundColor(.white)
        }
    }

    private func totalRow(_ v: Double) -> some View {
        HStack { Text("Together").font(.system(size: 15)).foregroundColor(HB.soft); Spacer(); Text(HBFormat.money(v)).font(.system(size: 16, weight: .bold).monospacedDigit()).foregroundColor(.white) }
    }
}

// MARK: - Household

struct HBActivityView: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

@available(iOS 15.0, *)
struct HBHouseholdSheet: View {
    @ObservedObject var store: HBAppStore
    let focusInvite: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var nestName = ""
    @State private var nameLoaded = false
    @State private var editingMe = false
    @State private var sharing = false
    @State private var confirmNewCode = false
    @State private var copied = false
    @State private var error: String?

    private var me: HBMember? { store.member(store.myID) }
    private var myEmail: String? {
        guard let e = store.snapshot?.me?.email, !e.hasSuffix("invalid") else { return nil }
        return e
    }
    private var link: String { HBTogether.inviteLink(store.inviteCode) }

    var body: some View {
        ScrollViewReader { proxy in
        HBSheetScaffold(title: "Household", onBack: { dismiss() }) {
            membersCard
            inviteCard.id("invite")
            budgetCard
            Button { store.sheet = .account } label: {
                HStack(spacing: 12) {
                    Image(systemName: "lock.shield").font(.system(size: 18, weight: .semibold)).foregroundColor(HB.orange).frame(width: 40, height: 40).background(Circle().fill(HB.orange.opacity(0.14)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Account & security").font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                        Text("Passkeys, password, your data, log out").font(.system(size: 13)).foregroundColor(HB.soft)
                    }
                    Spacer(); Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundColor(HB.soft)
                }
                .padding(14).frame(maxWidth: .infinity).hbCard()
            }
            .buttonStyle(.plain).accessibilityIdentifier("hb-household-account")
            if let error = error { Text(error).font(.footnote.weight(.semibold)).foregroundColor(HB.red) }
            Image("HBHouseholdScene").resizable().scaledToFit().frame(maxWidth: .infinity)
                .mask(LinearGradient(colors: [.clear, .black, .black], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.3)))
                .accessibilityHidden(true)
        }
        .onAppear {
            if !nameLoaded { nestName = store.nest?.name ?? ""; nameLoaded = true }
            if focusInvite { DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { withAnimation { proxy.scrollTo("invite", anchor: .center) } } }
        }
        }
        .sheet(isPresented: $editingMe) { HBEditMeSheet(store: store) }
        .sheet(isPresented: $sharing) { HBActivityView(items: [link]) }
        .confirmationDialog("Make a new invite code?", isPresented: $confirmNewCode, titleVisibility: .visible) {
            Button("New code", role: .destructive) { Task { do { try await store.newInviteCode() } catch { self.error = error.localizedDescription } } }
            Button("Keep this one", role: .cancel) {}
        } message: { Text("The old code and link stop working. People already in the household stay.") }
    }

    private var membersCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(store.members.enumerated()), id: \.element.id) { i, m in
                if i > 0 { Divider().background(HB.line).padding(.leading, 66) }
                HStack(spacing: 12) {
                    HBMemberAvatar(member: m, size: 46)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(m.id == store.myID ? "You" : m.name).font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
                        if m.id == store.myID, let e = myEmail { Text(e).font(.system(size: 13)).foregroundColor(HB.soft).lineLimit(1) }
                        else if m.id == store.myID { Text(m.name).font(.system(size: 13)).foregroundColor(HB.soft) }
                    }
                    Spacer(minLength: 6)
                    Text(i == 0 ? "Owner" : "Member").font(.system(size: 13)).foregroundColor(HB.soft)
                    if m.id == store.myID {
                        Button { editingMe = true } label: {
                            Text("Edit").font(.system(size: 14, weight: .semibold)).foregroundColor(HB.orange)
                                .padding(.horizontal, 12).frame(height: 32).overlay(Capsule().stroke(HB.orange.opacity(0.55), lineWidth: 1))
                        }
                        .accessibilityIdentifier("hb-edit-me")
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
            }
        }
        .hbCard()
    }

    private var inviteCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(store.kind == "family" ? "Invite your family" : (store.kind == "couple" ? "Invite your partner" : "Invite someone (optional)"))
                .font(.system(size: 18, weight: .bold)).foregroundColor(.white)
            Text("Invite code").font(.footnote).foregroundColor(HB.soft)
            Text(HBTogether.prettyCode(store.inviteCode)).font(.system(size: 34, weight: .heavy, design: .rounded)).foregroundColor(HB.orange).tracking(2)
                .accessibilityIdentifier("hb-invite-code")
            Text("They sign up with this code (or open the link) and join your budget. You share one budget from then on.").font(.footnote).foregroundColor(HB.soft)
                .fixedSize(horizontal: false, vertical: true)
            HBPillButton(title: copied ? "Link copied" : "Copy invite link", symbol: copied ? "checkmark" : "doc.on.doc") {
                UIPasteboard.general.string = link; copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
            }
            .accessibilityIdentifier("hb-copy-link")
            HStack(spacing: 10) {
                HBPillButton(title: "Share", symbol: "square.and.arrow.up", filled: false) { sharing = true }
                HBPillButton(title: "New code", symbol: "arrow.triangle.2.circlepath", filled: false) { confirmNewCode = true }.accessibilityIdentifier("hb-new-code")
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).hbCard()
    }

    private var budgetCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Our budget").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
            HBField(title: "Name") {
                HStack(spacing: 10) {
                    hbField("Our Hive", text: $nestName).accessibilityIdentifier("hb-nest-name")
                    Button(action: saveName) {
                        Text("Save").font(.system(size: 16, weight: .bold)).foregroundColor(Color.black.opacity(0.85)).padding(.horizontal, 16).frame(height: 52)
                            .background(Capsule().fill(HB.orange))
                    }
                    .disabled(nestName.trimmingCharacters(in: .whitespaces).isEmpty || nestName == (store.nest?.name ?? "")).accessibilityIdentifier("hb-nest-save")
                }
            }
            HBField(title: "Type") {
                HStack(spacing: 8) {
                    ForEach([("solo", "Just me"), ("couple", "Couple"), ("family", "Family")], id: \.0) { k, title in
                        Button { setKind(k) } label: {
                            Text(title).font(.system(size: 15, weight: .semibold))
                                .foregroundColor(store.kind == k ? Color.black.opacity(0.85) : Color(red: 0.74, green: 0.69, blue: 0.9))
                                .frame(maxWidth: .infinity, minHeight: 42)
                                .background(Capsule().fill(store.kind == k ? HB.orange : Color.white.opacity(0.06)))
                        }
                        .accessibilityAddTraits(store.kind == k ? .isSelected : []).accessibilityIdentifier("hb-kind-\(k)")
                    }
                }
            }
            if store.kind == "couple" && store.members.count > 1 {
                Toggle(isOn: Binding(get: { store.jointActive }, set: { setJoint($0) })) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Joint account").font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
                        Text("We keep our money in one pot, so everything adds up together.").font(.footnote).foregroundColor(HB.soft)
                    }
                }
                .tint(HB.orange).accessibilityIdentifier("hb-joint")
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).hbCard()
    }

    private func saveName() {
        hbHideKeyboard(); error = nil
        let n = nestName.trimmingCharacters(in: .whitespaces)
        Task { do { try await store.renameNest(n) } catch { self.error = error.localizedDescription } }
    }
    private func setKind(_ k: String) {
        guard k != store.kind else { return }
        error = nil
        Task { do { try await store.setKind(k) } catch { self.error = error.localizedDescription } }
    }
    private func setJoint(_ on: Bool) {
        error = nil
        Task { do { try await store.setJoint(on) } catch { self.error = error.localizedDescription } }
    }
}

// Pick your own name, buddy and colour (PATCH /api/me, the same call as the website's "Edit yourself").
@available(iOS 15.0, *)
struct HBEditMeSheet: View {
    @ObservedObject var store: HBAppStore
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var emoji: String
    @State private var color: String
    @State private var error: String?
    @State private var saving = false

    init(store: HBAppStore) {
        self.store = store
        let m = store.member(store.myID)
        _name = State(initialValue: m?.name ?? "")
        _emoji = State(initialValue: HBTogether.emojis.contains(m?.emoji ?? "") ? (m?.emoji ?? "🐰") : "🐰")
        _color = State(initialValue: HBTogether.colors.contains(m?.color ?? "") ? (m?.color ?? HBTogether.colors[0]) : HBTogether.colors[0])
    }

    var body: some View {
        HBSheetScaffold(title: "Edit yourself", onBack: { dismiss() }) {
            HBField(title: "Name") { hbField("Your name", text: $name).accessibilityIdentifier("hb-me-name") }
            HBField(title: "Buddy") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                    ForEach(HBTogether.emojis, id: \.self) { e in
                        Button { emoji = e } label: {
                            Group {
                                if let a = HBTogether.buddyAsset(e) { Image(a).resizable().scaledToFit() } else { Color(hex: color) ?? HB.orange }
                            }
                            .frame(width: 72, height: 72).clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 19, style: .continuous).stroke(emoji == e ? HB.orange : (Color(hex: color) ?? Color.white.opacity(0.18)), lineWidth: emoji == e ? 4 : 2))
                        }
                        .accessibilityLabel("Buddy").accessibilityAddTraits(emoji == e ? .isSelected : [])
                    }
                }
            }
            HBField(title: "Colour") {
                HStack(spacing: 12) {
                    ForEach(HBTogether.colors, id: \.self) { c in
                        Button { color = c } label: {
                            Circle().fill(Color(hex: c) ?? HB.orange).frame(width: 40, height: 40)
                                .overlay(Circle().stroke(color == c ? HB.orange : Color.white.opacity(0.18), lineWidth: color == c ? 3 : 1))
                        }
                        .accessibilityLabel("Colour").accessibilityAddTraits(color == c ? .isSelected : [])
                    }
                }
            }
            if let error = error { Text(error).font(.footnote.weight(.semibold)).foregroundColor(HB.red) }
            Button(action: save) {
                Text(saving ? "Saving…" : "Save").font(.system(size: 19, weight: .bold)).foregroundColor(Color.black.opacity(0.85))
                    .frame(maxWidth: .infinity, minHeight: 56).background(Capsule().fill(HB.orange)).shadow(color: HB.orange.opacity(0.4), radius: 12, y: 4)
            }
            .disabled(saving).accessibilityIdentifier("hb-me-save")
        }
    }

    private func save() {
        hbHideKeyboard(); error = nil
        let n = name.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { error = "Enter a name."; return }
        saving = true
        Task {
            do { try await store.updateMe(name: n, emoji: emoji, color: color); dismiss() } catch { self.error = error.localizedDescription }
            saving = false
        }
    }
}

// MARK: - Shared shopping list

@available(iOS 15.0, *)
struct HBShoppingSheet: View {
    @ObservedObject var store: HBAppStore
    @Environment(\.dismiss) private var dismiss
    @State private var newItem = ""
    @State private var editingID: String?
    @State private var editText = ""
    @State private var spend = ""
    @State private var error: String?
    @State private var working = false

    private var doneItems: [HBShopItem] { store.shopping.filter { $0.done } }

    var body: some View {
        HBSheetScaffold(title: "Shared Shopping List", onBack: { dismiss() }) {
            HStack(spacing: 10) {
                hbField("Add an item…", text: $newItem).submitLabel(.done).onSubmit(add).accessibilityIdentifier("hb-shop-input")
                Button(action: add) {
                    Image(systemName: "plus").font(.system(size: 20, weight: .bold)).foregroundColor(Color.black.opacity(0.85)).frame(width: 52, height: 52).background(Circle().fill(HB.orange))
                }
                .accessibilityLabel("Add to the shopping list").accessibilityIdentifier("hb-shop-add")
            }
            if let error = error { Text(error).font(.footnote.weight(.semibold)).foregroundColor(HB.red) }
            switch store.shopState {
            case .idle, .loading:
                HStack(spacing: 10) { ProgressView().tint(HB.orange); Text("Loading the list…").foregroundColor(HB.soft) }.frame(maxWidth: .infinity).padding(24).hbCard()
            case let .failed(msg):
                VStack(spacing: 10) {
                    Text("Couldn't load the list.").font(.headline).foregroundColor(.white)
                    Text(msg).font(.subheadline).foregroundColor(HB.soft).multilineTextAlignment(.center)
                    Button("Try again") { Task { await store.loadShopping() } }.foregroundColor(HB.orange)
                }
                .frame(maxWidth: .infinity).padding(20).hbCard()
            case .loaded:
                VStack(spacing: 0) {
                    if store.shopping.isEmpty {
                        Text("Nothing on the list yet. Add what you need above.").font(.subheadline).foregroundColor(HB.soft).padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(Array(store.shopping.enumerated()), id: \.element.id) { i, item in
                        if i > 0 { Divider().background(HB.line).padding(.leading, 52) }
                        row(item)
                    }
                }
                .hbCard()
                if !doneItems.isEmpty { checkoutCard }
            }
        }
        .task { await store.loadShopping() }
    }

    private func row(_ item: HBShopItem) -> some View {
        HStack(spacing: 12) {
            Button { toggle(item) } label: {
                Image(systemName: item.done ? "checkmark.circle.fill" : "circle").font(.system(size: 24)).foregroundColor(item.done ? HB.green : Color.white.opacity(0.45)).frame(width: 34, height: 34)
            }
            .accessibilityLabel(item.done ? "Untick \(item.label)" : "Tick off \(item.label)").accessibilityIdentifier("hb-shop-toggle")
            if editingID == item.id {
                TextField("Item", text: $editText).font(.system(size: 17)).foregroundColor(.white).submitLabel(.done).onSubmit { rename(item) }
                    .accessibilityIdentifier("hb-shop-rename")
            } else {
                Button { editingID = item.id; editText = item.label } label: {
                    Text(item.label).font(.system(size: 17)).foregroundColor(item.done ? HB.soft : .white).strikethrough(item.done)
                        .frame(maxWidth: .infinity, alignment: .leading).lineLimit(2)
                }
                .buttonStyle(.plain).accessibilityHint("Edit")
            }
            Button { remove(item) } label: { Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundColor(HB.soft).frame(width: 30, height: 30) }
                .accessibilityLabel("Delete \(item.label)").accessibilityIdentifier("hb-shop-delete")
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
    }

    private var checkoutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Done shopping?").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
            Text(store.members.count > 1 && !store.jointActive
                 ? "Log what you spent as groceries (split equally) and clear the \(doneItems.count) ticked item\(doneItems.count == 1 ? "" : "s")."
                 : "Log what you spent as groceries and clear the \(doneItems.count) ticked item\(doneItems.count == 1 ? "" : "s").")
                .font(.footnote).foregroundColor(HB.soft).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                hbField("Amount spent", text: $spend, keyboard: .decimalPad).accessibilityIdentifier("hb-checkout-amount")
                Button(action: checkout) {
                    Text(working ? "Saving…" : "Log it").font(.system(size: 16, weight: .bold)).foregroundColor(Color.black.opacity(0.85)).padding(.horizontal, 18).frame(height: 52)
                        .background(Capsule().fill(HB.orange))
                }
                .disabled(working).accessibilityIdentifier("hb-checkout")
            }
            Button { clear() } label: {
                Text("Just clear checked items").font(.system(size: 15, weight: .semibold)).foregroundColor(Color(red: 0.72, green: 0.68, blue: 0.9)).frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("hb-shop-clear")
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).hbCard()
    }

    private func add() {
        let v = newItem.trimmingCharacters(in: .whitespaces)
        guard !v.isEmpty else { return }
        error = nil
        Task { do { try await store.addShopItem(v); newItem = "" } catch { self.error = error.localizedDescription } }
    }
    private func toggle(_ item: HBShopItem) { error = nil; Task { do { try await store.setShopDone(item, done: !item.done) } catch { self.error = error.localizedDescription } } }
    private func remove(_ item: HBShopItem) { error = nil; Task { do { try await store.deleteShopItem(item) } catch { self.error = error.localizedDescription } } }
    private func rename(_ item: HBShopItem) {
        let v = editText.trimmingCharacters(in: .whitespaces)
        editingID = nil
        guard !v.isEmpty, v != item.label else { return }
        Task { do { try await store.renameShopItem(item, to: v) } catch { self.error = error.localizedDescription } }
    }
    private func clear() { error = nil; Task { do { try await store.clearShopDone() } catch { self.error = error.localizedDescription } } }
    private func checkout() {
        hbHideKeyboard(); error = nil
        guard let amount = hbParseAmount(spend) else { error = "Enter what you spent."; return }
        working = true
        Task {
            do { try await store.shopCheckout(amount: amount); spend = "" } catch { self.error = error.localizedDescription }
            working = false
        }
    }
}

// MARK: - Search everything

@available(iOS 15.0, *)
struct HBSearchSheet: View {
    @ObservedObject var store: HBAppStore
    @Environment(\.dismiss) private var dismiss
    @State private var q = ""
    @State private var type = ""
    @State private var who = ""
    @State private var results: [HBEntry]?
    @State private var failure: String?
    @State private var loading = false
    @State private var shown = 20

    private var active: Bool { !q.isEmpty || !type.isEmpty || !who.isEmpty }
    private var rows: [HBEntry] { active ? (results ?? []) : store.entries }

    var body: some View {
        HBSheetScaffold(title: "Everything", onBack: { dismiss() }) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundColor(HB.soft)
                TextField("Search everything", text: $q).font(.system(size: 18)).foregroundColor(.white).submitLabel(.search).autocorrectionDisabled()
                    .accessibilityIdentifier("hb-search-input")
                if !q.isEmpty { Button { q = "" } label: { Image(systemName: "xmark.circle.fill").foregroundColor(HB.soft) }.accessibilityLabel("Clear search") }
            }
            .padding(.horizontal, 16).frame(minHeight: 52)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
            HStack(spacing: 8) {
                ForEach([("", "All"), ("expense", "Spent"), ("income", "Got paid")], id: \.0) { key, title in
                    Button { type = key } label: {
                        Text(title).font(.system(size: 15, weight: .semibold)).foregroundColor(type == key ? Color.black.opacity(0.85) : Color(red: 0.74, green: 0.69, blue: 0.9))
                            .frame(maxWidth: .infinity, minHeight: 40).background(Capsule().fill(type == key ? HB.orange : Color.white.opacity(0.06)))
                    }
                    .accessibilityIdentifier("hb-search-type-\(key.isEmpty ? "all" : key)")
                }
                if store.members.count > 1 {
                    Menu {
                        Button("Anyone") { who = "" }
                        ForEach(store.members) { m in Button(m.id == store.myID ? "You" : m.name) { who = m.id } }
                    } label: {
                        HStack(spacing: 4) {
                            Text(who.isEmpty ? "Anyone" : (who == store.myID ? "You" : store.memberName(who))).lineLimit(1)
                            Image(systemName: "chevron.down").font(.system(size: 11, weight: .bold))
                        }
                        .font(.system(size: 15, weight: .semibold)).foregroundColor(Color(red: 1, green: 0.92, blue: 0.84)).padding(.horizontal, 12).frame(height: 40)
                        .background(Capsule().fill(Color.white.opacity(0.07))).overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
                    }
                }
            }
            HStack {
                Text(active ? "Search results" : "Everything this month").font(.system(size: 19, weight: .bold)).foregroundColor(.white)
                Spacer()
                if !rows.isEmpty {
                    let net = rows.reduce(0) { $0 + ($1.isIncome ? $1.amount : -$1.amount) }
                    Text("\(rows.count) · net \(HBFormat.money(net))").font(.system(size: 13)).foregroundColor(HB.soft)
                }
            }
            if loading && results == nil {
                HStack(spacing: 10) { ProgressView().tint(HB.orange); Text("Searching…").foregroundColor(HB.soft) }.frame(maxWidth: .infinity).padding(24).hbCard()
            } else if let f = failure, active {
                VStack(spacing: 8) { Text("Couldn't search.").font(.headline).foregroundColor(.white); Text(f).font(.subheadline).foregroundColor(HB.soft) }
                    .frame(maxWidth: .infinity).padding(20).hbCard()
            } else if rows.isEmpty {
                Text(active ? "Nothing matches that." : "Nothing logged yet this month.").font(.subheadline).foregroundColor(HB.soft)
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading).hbCard()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(rows.prefix(shown).enumerated()), id: \.element.id) { i, e in
                        if i > 0 { Divider().background(HB.line).padding(.leading, 62) }
                        Button { store.sheet = .editEntry(e) } label: { HBEntryRow(entry: e, who: store.members.count > 1 ? (e.member_id == store.myID ? "You" : store.memberName(e.member_id)) : nil) }
                            .buttonStyle(.plain).accessibilityIdentifier("hb-search-row")
                    }
                    if rows.count > shown {
                        Divider().background(HB.line)
                        Button { shown += 20 } label: { Text("Show more").font(.system(size: 16, weight: .semibold)).foregroundColor(HB.orange).frame(maxWidth: .infinity, minHeight: 48) }
                    }
                }
                .hbCard()
            }
        }
        .task(id: "\(q)|\(type)|\(who)") { await runSearch() }
    }

    private func runSearch() async {
        shown = 20
        guard active else { results = nil; failure = nil; return }
        try? await Task.sleep(nanoseconds: 300_000_000)
        if Task.isCancelled { return }
        loading = true; defer { loading = false }
        do { results = try await store.search(q: q.trimmingCharacters(in: .whitespaces), type: type, member: who); failure = nil }
        catch { if !Task.isCancelled { failure = error.localizedDescription } }
    }
}
