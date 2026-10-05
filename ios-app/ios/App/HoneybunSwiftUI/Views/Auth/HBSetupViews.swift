import SwiftUI

// MARK: - a new account has no budget yet: start one, or join one with an invite code

@available(iOS 15.0, *)
struct HBSetupView: View {
    @ObservedObject var store: HBAppStore
    @State private var kind = "couple"
    @State private var name = ""
    @State private var code = ""
    @State private var busy = false
    @State private var error: String?
    @State private var confirmLogout = false

    private let kinds: [(String, String, String)] = [("solo", "Just me", "A budget for one."), ("couple", "Couple", "Share bills and split costs fairly."), ("family", "Family", "Everyone in one household.")]

    var body: some View {
        HBAuthScaffold(title: "Hi, \(store.account?.name ?? "there")!", subtitle: "Join a budget someone shared with you, or start your own.") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Join with an invite code").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                HBAuthField(label: "Invite code", placeholder: "ABCD-EFGH", text: $code, id: "hb-setup-code")
                HBPillButton(title: busy ? "Joining…" : "Join", filled: false) { join() }.disabled(busy || HBAuthText.inviteCode(code).isEmpty).accessibilityIdentifier("hb-setup-join")
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading).hbCard()
            HStack { Rectangle().fill(Color.white.opacity(0.14)).frame(height: 1); Text("or").font(.footnote).foregroundColor(HB.soft); Rectangle().fill(Color.white.opacity(0.14)).frame(height: 1) }
            VStack(alignment: .leading, spacing: 12) {
                Text("Start a new budget").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                ForEach(kinds, id: \.0) { k in
                    Button { kind = k.0 } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(k.1).font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                                Text(k.2).font(.system(size: 14)).foregroundColor(HB.soft)
                            }
                            Spacer()
                            Image(systemName: kind == k.0 ? "checkmark.circle.fill" : "circle").font(.system(size: 22)).foregroundColor(kind == k.0 ? HB.orange : Color.white.opacity(0.35))
                        }
                        .padding(14).frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(kind == k.0 ? 0.09 : 0.04)))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(kind == k.0 ? HB.orange.opacity(0.8) : Color.white.opacity(0.12), lineWidth: 1))
                    }
                    .buttonStyle(.plain).accessibilityAddTraits(kind == k.0 ? .isSelected : []).accessibilityIdentifier("hb-setup-kind-\(k.0)")
                }
                HBAuthField(label: "Budget name (optional)", placeholder: "Our Hive", text: $name, capitalize: true, id: "hb-setup-name")
                HBPillButton(title: busy ? "Starting…" : "Start my budget") { create() }.disabled(busy).accessibilityIdentifier("hb-setup-create")
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading).hbCard()
            HBAuthNote(error: error ?? store.notice, info: nil)
            HBAuthLink(title: "Log out") { confirmLogout = true }
        }
        .confirmationDialog("Log out of Honeybun?", isPresented: $confirmLogout, titleVisibility: .visible) {
            Button("Log out", role: .destructive) { Task { await store.logout() } }
            Button("Stay", role: .cancel) {}
        }
        // an invite link (honeybun.me/join/CODE) opened in the app fills the code in
        .onReceive(store.$joinPrefill) { c in if let c = c { code = c; store.joinPrefill = nil } }
    }

    private func create() {
        hbHideKeyboard(); busy = true; error = nil
        Task { do { try await HBAPI.shared.createBudget(name: name, kind: kind); await store.start() } catch { self.error = error.localizedDescription }; busy = false }
    }
    private func join() {
        hbHideKeyboard(); busy = true; error = nil
        Task { do { try await HBAPI.shared.joinBudget(code: HBAuthText.inviteCode(code)); await store.start() } catch { self.error = error.localizedDescription }; busy = false }
    }
}

// MARK: - first-run onboarding: buddy, invite, paydays, bills (the same steps as the website, each skippable)

@available(iOS 15.0, *)
struct HBOnboardingView: View {
    @ObservedObject var store: HBAppStore
    /// "Run the quick setup again" (Settings / Plan): just paydays and bills, then close. It adds to what is there, it never replaces it.
    var rerun = false
    @Environment(\.dismiss) private var dismiss
    @State private var step = 0
    @State private var error: String?
    @State private var busy = false
    // payday form
    @State private var payAmount = ""
    @State private var payFreq = "biweekly"
    @State private var payDate = Date()
    // bill form
    @State private var billName = ""
    @State private var billAmount = ""
    @State private var billFreq = "monthly"
    @State private var billDate = Date()
    @State private var billCategory = HBCategory.bills
    @State private var sharing = false

    private var steps: [String] { rerun ? ["paydays", "bills", "done"] : ["buddy"] + ((store.kind != "solo" && store.members.count < 2) ? ["invite"] : []) + ["paydays", "bills", "done"] }
    private func finish() { if rerun { Task { await store.refresh(); dismiss() } } else { Task { await store.finishOnboarding() } } }
    private var current: String { steps[min(step, steps.count - 1)] }
    private var me: HBMember? { store.member(store.myID) }

    var body: some View {
        ZStack {
            HBBackground(glow: true, scene: false)
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Button { if step > 0 { step -= 1; error = nil } } label: { Image(systemName: "arrow.left").font(.system(size: 20, weight: .medium)).foregroundColor(.white).frame(width: 44, height: 44) }
                        .opacity(step == 0 ? 0 : 1).accessibilityLabel("Back")
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.1))
                            Capsule().fill(HB.orange).frame(width: g.size.width * CGFloat(step) / CGFloat(max(1, steps.count - 1)))
                        }
                    }.frame(height: 8)
                    Button(rerun ? "Close" : "Skip") { finish() }.foregroundColor(HB.soft).opacity(current == "done" ? 0 : 1).accessibilityIdentifier("hb-onboard-skip")
                }
                .padding(.horizontal, HB.gutter).padding(.top, 8)
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) { stepContent }
                        .frame(maxWidth: 560).padding(.horizontal, HB.gutter).padding(.top, 12).padding(.bottom, 24).frame(maxWidth: .infinity)
                }
                VStack(spacing: 8) {
                    HBAuthNote(error: error, info: nil)
                    HBPillButton(title: current == "done" ? "Go to my budget" : (current == "bills" ? "Finish" : "Next")) { next() }.disabled(busy).accessibilityIdentifier("hb-onboard-next")
                }
                .padding(.horizontal, HB.gutter).padding(.bottom, 16).frame(maxWidth: 560)
            }
        }
        .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { hbHideKeyboard() } } }
        #if DEBUG
        .onAppear { if let i = steps.firstIndex(of: store.previewAuthScreen ?? "") { step = i } }
        #endif
    }

    private func next() {
        hbHideKeyboard(); error = nil
        if current == "done" { finish(); return }
        step += 1
    }

    @ViewBuilder private var stepContent: some View {
        switch current {
        case "buddy": buddy
        case "invite": invite
        case "paydays": paydays
        case "bills": bills
        default: done
        }
    }

    private func title(_ t: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t).font(.system(size: 30, weight: .bold)).foregroundColor(.white)
            Text(sub).font(.system(size: 16)).foregroundColor(Color(red: 0.74, green: 0.69, blue: 0.9)).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var buddy: some View {
        VStack(alignment: .leading, spacing: 16) {
            title("Hi \(store.account?.name ?? "")!", "Let's set up your budget. First, pick the little buddy that shows next to everything you add.")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(HBTogether.emojis, id: \.self) { e in
                    Button { pick(e) } label: {
                        Group { if let a = HBTogether.buddyAsset(e) { Image(a).resizable().scaledToFit() } else { Color.clear } }
                            .frame(width: 72, height: 72).clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 19, style: .continuous).stroke(me?.emoji == e ? HB.orange : Color.white.opacity(0.18), lineWidth: me?.emoji == e ? 4 : 1.5))
                    }
                    .accessibilityLabel("Buddy").accessibilityAddTraits(me?.emoji == e ? .isSelected : [])
                }
            }
        }
    }
    private func pick(_ emoji: String) {
        guard let m = me else { return }
        Task { do { try await store.updateMe(name: m.name, emoji: emoji, color: m.color ?? HBTogether.colors[0]) } catch { self.error = error.localizedDescription } }
    }

    @State private var sharingInvite = false
    private var invite: some View {
        VStack(alignment: .leading, spacing: 16) {
            title(store.kind == "family" ? "Invite your family" : "Invite your partner", "Send them this link. When they join, you'll share one budget and see the same bills.")
            VStack(spacing: 12) {
                Text(HBTogether.prettyCode(store.inviteCode)).font(.system(size: 34, weight: .heavy, design: .rounded)).foregroundColor(HB.orange).tracking(2)
                HBPillButton(title: "Share invite link", symbol: "square.and.arrow.up") { sharingInvite = true }
            }
            .padding(18).frame(maxWidth: .infinity).hbCard()
            Text("You can always find this later in Together.").font(.footnote).foregroundColor(HB.soft)
        }
        .sheet(isPresented: $sharingInvite) { HBActivityView(items: [HBTogether.inviteLink(store.inviteCode)]) }
    }

    private var paydays: some View {
        VStack(alignment: .leading, spacing: 16) {
            title("When do you get paid?", "Add each paycheck once. Honeybun uses it to show what's due before payday.")
            HBAuthField(label: "Amount", placeholder: "1800", text: $payAmount, keyboard: .decimalPad, id: "hb-onboard-pay-amount")
            frequency($payFreq)
            DatePicker("Next payday", selection: $payDate, displayedComponents: .date).foregroundColor(.white).tint(HB.orange)
            HBPillButton(title: "Add payday", filled: false) { addPayday() }.disabled(busy).accessibilityIdentifier("hb-onboard-pay-add")
            recurringList(income: true)
        }
    }
    private var bills: some View {
        VStack(alignment: .leading, spacing: 16) {
            title("What bills do you have?", "Add rent, subscriptions and bills once. Bun reminds you before each one is due.")
            HBAuthField(label: "Bill", placeholder: "Rent", text: $billName, capitalize: true, id: "hb-onboard-bill-name")
            HBAuthField(label: "Amount", placeholder: "850", text: $billAmount, keyboard: .decimalPad, id: "hb-onboard-bill-amount")
            frequency($billFreq)
            DatePicker("Next due", selection: $billDate, displayedComponents: .date).foregroundColor(.white).tint(HB.orange)
            Menu {
                ForEach(HBCategory.allCases) { c in Button(c.label) { billCategory = c } }
            } label: {
                HStack { Text("Category").foregroundColor(HB.soft); Spacer(); Text(billCategory.label).foregroundColor(.white); Image(systemName: "chevron.up.chevron.down").font(.system(size: 12)).foregroundColor(HB.soft) }
                    .padding(.horizontal, 16).frame(minHeight: 50).background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.06)))
            }
            HBPillButton(title: "Add bill", filled: false) { addBill() }.disabled(busy).accessibilityIdentifier("hb-onboard-bill-add")
            recurringList(income: false)
        }
    }
    private var done: some View {
        VStack(spacing: 14) {
            Image("HBHero").resizable().scaledToFit().frame(width: 200).accessibilityHidden(true)
            Text("You're all set!").font(.system(size: 30, weight: .bold)).foregroundColor(.white)
            Text("Your budget is ready. Add expenses as you go and Bun will keep you on track.").font(.system(size: 16)).foregroundColor(HB.soft).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func frequency(_ sel: Binding<String>) -> some View {
        HStack(spacing: 6) {
            ForEach([("weekly", "Weekly"), ("biweekly", "Every 2 weeks"), ("monthly", "Monthly")], id: \.0) { f in
                Button { sel.wrappedValue = f.0 } label: {
                    Text(f.1).font(.system(size: 14, weight: .semibold)).foregroundColor(sel.wrappedValue == f.0 ? Color.black.opacity(0.85) : Color(red: 0.74, green: 0.69, blue: 0.9))
                        .frame(maxWidth: .infinity, minHeight: 40).background(Capsule().fill(sel.wrappedValue == f.0 ? HB.orange : Color.white.opacity(0.06)))
                }
            }
        }
    }

    private func recurringList(income: Bool) -> some View {
        let items = (store.snapshot?.recurring ?? []).filter { $0.isIncome == income }
        return VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { i, r in
                if i > 0 { Divider().background(HB.line) }
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(r.label).font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                        Text("\(HBFormat.money(r.amount)) · \(r.freq == "biweekly" ? "every 2 weeks" : r.freq)").font(.system(size: 13)).foregroundColor(HB.soft)
                    }
                    Spacer()
                    Button { Task { do { try await store.deleteRecurring(id: r.id) } catch { self.error = error.localizedDescription } } } label: { Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundColor(HB.soft).frame(width: 30, height: 30) }
                        .accessibilityLabel("Remove \(r.label)")
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
            }
        }
        .hbCard().opacity(items.isEmpty ? 0 : 1).frame(height: items.isEmpty ? 0 : nil)
    }

    private func addPayday() {
        hbHideKeyboard(); error = nil
        guard let amount = hbParseAmount(payAmount) else { error = "Enter the amount of your paycheck."; return }
        var d = HBRecurringDraft(date: HBDay.string(payDate), memberID: store.myID)
        d.type = "income"; d.amount = amount; d.label = "Paycheck"; d.freq = payFreq
        busy = true
        Task { do { try await store.addRecurring(d); payAmount = "" } catch { self.error = error.localizedDescription }; busy = false }
    }
    private func addBill() {
        hbHideKeyboard(); error = nil
        let n = billName.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { error = "Name the bill."; return }
        guard let amount = hbParseAmount(billAmount) else { error = "Enter the amount."; return }
        var d = HBRecurringDraft(date: HBDay.string(billDate), memberID: store.myID)
        d.type = "expense"; d.amount = amount; d.label = n; d.freq = billFreq; d.category = billCategory.rawValue
        busy = true
        Task { do { try await store.addRecurring(d); billName = ""; billAmount = "" } catch { self.error = error.localizedDescription }; busy = false }
    }
}
