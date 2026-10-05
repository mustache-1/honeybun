import SwiftUI

// The editors behind Plan: monthly budgets (and the account's own categories), a debt, and a debt payment.

private let hbCatEmojis = ["🐶", "🐱", "🎮", "🌱", "✈️", "🎁", "☕", "🏋️", "💅", "📚", "🎬", "🍷", "🧸", "🛠️", "💊", "🎨"]
private func hbNumber(_ s: String) -> Double { Double(s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")) ?? 0 }
private func hbTrim(_ v: Double) -> String { v == v.rounded() ? String(Int(v)) : String(format: "%.2f", v) }

// MARK: - Monthly budgets + your own categories

@available(iOS 15.0, *)
struct HBBudgetEditor: View {
    @ObservedObject var store: HBAppStore
    @Environment(\.dismiss) private var dismiss
    @State private var limits: [String: String] = [:]
    @State private var rollover = false
    @State private var error: String?
    @State private var busy = false
    @State private var catSheet: CatTarget?
    @State private var deleting: HBCustomCategory?
    private enum CatTarget: Identifiable { case new, edit(HBCustomCategory); var id: String { switch self { case .new: return "new"; case let .edit(c): return c.id } } }

    var body: some View {
        HBSheetScaffold(title: "Monthly budgets", onBack: { dismiss() }) {
            Text("Set a monthly limit for any category. Leave blank for no limit.").font(.footnote).foregroundColor(HB.soft)
            VStack(spacing: 0) {
                let cats = HBCatStyle.all
                ForEach(Array(cats.enumerated()), id: \.element.id) { i, c in
                    HStack(spacing: 12) {
                        HBCatIcon(style: c, size: 34)
                        Text(c.label).font(.system(size: 16)).foregroundColor(.white).lineLimit(1)
                        Spacer(minLength: 8)
                        TextField("No limit", text: binding(c.id)).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                            .font(.system(size: 16).monospacedDigit()).foregroundColor(.white).frame(width: 96)
                            .accessibilityIdentifier("hb-budget-" + c.id)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    if i < cats.count - 1 { Divider().background(HB.line).padding(.leading, 60) }
                }
            }.hbCard()
            Toggle(isOn: $rollover) {
                VStack(alignment: .leading, spacing: 2) { Text("Roll over what's left").foregroundColor(.white).font(.system(size: 16, weight: .semibold)); Text("Unspent budget carries into next month").font(.system(size: 13)).foregroundColor(HB.soft) }
            }.tint(HB.orange).padding(14).hbCard()

            // the account's own categories
            VStack(alignment: .leading, spacing: 10) {
                Text("Your categories").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                if (store.snapshot?.categories ?? []).isEmpty { Text("Make your own, with your own emoji (up to 12).").font(.footnote).foregroundColor(HB.soft) }
                ForEach(store.snapshot?.categories ?? []) { c in
                    HStack(spacing: 10) {
                        Text(c.emoji ?? "✨").font(.system(size: 22))
                        Text(c.name).font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                        Spacer()
                        Button("Edit") { catSheet = .edit(c) }.font(.system(size: 14, weight: .semibold)).foregroundColor(HB.orange)
                        Button("Delete") { deleting = c }.font(.system(size: 14, weight: .semibold)).foregroundColor(HB.red)
                    }
                }
                HBPillButton(title: "New category", symbol: "plus", filled: false) { catSheet = .new }.accessibilityIdentifier("hb-budget-new-category")
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading).hbCard()

            if let e = error { Text(e).font(.footnote.weight(.semibold)).foregroundColor(HB.red) }
            HBPillButton(title: busy ? "Saving…" : "Save budgets") { save() }.disabled(busy).accessibilityIdentifier("hb-budget-save")
        }
        .onAppear { load() }
        .sheet(item: $catSheet) { t in
            switch t { case .new: HBCategoryForm(store: store, existing: nil); case let .edit(c): HBCategoryForm(store: store, existing: c) }
        }
        .confirmationDialog("Delete this category?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("Delete", role: .destructive) { if let c = deleting { remove(c) }; deleting = nil }
            Button("Keep it", role: .cancel) { deleting = nil }
        } message: { Text("Things filed under it move to Other, and its budget goes away.") }
    }

    private func binding(_ id: String) -> Binding<String> { Binding(get: { limits[id] ?? "" }, set: { limits[id] = $0 }) }
    private func load() {
        guard limits.isEmpty else { return }
        for b in store.snapshot?.budgets ?? [] { limits[b.category] = hbTrim(Double(b.limit_cents) / 100.0) }
        rollover = (store.snapshot?.nest.rollover ?? 0) == 1
    }
    private func save() {
        busy = true; error = nil
        var out: [String: Double] = [:]
        for (k, v) in limits { let n = hbNumber(v); if n > 0 { out[k] = n } }
        Task {
            do { try await store.saveBudgets(out, rollover: rollover); dismiss() } catch { self.error = error.localizedDescription }
            busy = false
        }
    }
    private func remove(_ c: HBCustomCategory) {
        Task { do { try await store.deleteCategory(id: c.id); limits[c.id] = nil } catch { self.error = error.localizedDescription } }
    }
}

@available(iOS 15.0, *)
struct HBCategoryForm: View {
    @ObservedObject var store: HBAppStore
    let existing: HBCustomCategory?
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var emoji = hbCatEmojis[0]
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        HBSheetScaffold(title: existing == nil ? "New category" : "Edit category", onBack: { dismiss() }) {
            VStack(spacing: 6) {
                Text(emoji).font(.system(size: 44))
                Text(name.trimmingCharacters(in: .whitespaces).isEmpty ? "Your category" : name).font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
            }.frame(maxWidth: .infinity).padding(14).hbCard()
            HBAuthField(label: "Name", placeholder: "e.g. Pets", text: $name, capitalize: true, id: "hb-category-name")
            HBField(title: "Pick an emoji") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 8) {
                    ForEach(hbCatEmojis, id: \.self) { e in
                        Button { emoji = e } label: { Text(e).font(.system(size: 24)).frame(maxWidth: .infinity, minHeight: 40).background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(emoji == e ? HB.orange.opacity(0.3) : Color.white.opacity(0.06))) }
                    }
                }
            }
            if let e = error { Text(e).font(.footnote.weight(.semibold)).foregroundColor(HB.red) }
            HBPillButton(title: busy ? "Saving…" : "Save category") { save() }.disabled(busy).accessibilityIdentifier("hb-category-save")
        }
        .onAppear { if let c = existing { name = c.name; emoji = c.emoji ?? hbCatEmojis[0] } }
    }
    private func save() {
        let n = name.trimmingCharacters(in: .whitespaces)
        guard !n.isEmpty else { error = "Give the category a name."; return }
        busy = true; error = nil
        Task {
            do {
                if let c = existing { try await store.updateCategory(id: c.id, name: n, emoji: emoji) } else { try await store.createCategory(name: n, emoji: emoji) }
                dismiss()
            } catch { self.error = error.localizedDescription }
            busy = false
        }
    }
}

// MARK: - Debt: add / edit / delete

@available(iOS 15.0, *)
struct HBDebtForm: View {
    @ObservedObject var store: HBAppStore
    let debt: HBDebt?
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var balance = ""
    @State private var apr = ""
    @State private var minimum = ""
    @State private var error: String?
    @State private var busy = false
    @State private var confirmDelete = false

    var body: some View {
        HBSheetScaffold(title: debt == nil ? "Add a debt" : "Edit debt", onBack: { dismiss() }) {
            HBAuthField(label: "Name", placeholder: "Credit card, car loan…", text: $name, capitalize: true, id: "hb-debt-name")
            HBAuthField(label: debt == nil ? "Balance (what you owe today)" : "Balance (where you started)", placeholder: "0.00", text: $balance, keyboard: .decimalPad, id: "hb-debt-balance")
            HBAuthField(label: "Interest rate (APR %)", placeholder: "0", text: $apr, keyboard: .decimalPad, id: "hb-debt-apr")
            HBAuthField(label: "Minimum payment per month", placeholder: "0.00", text: $minimum, keyboard: .decimalPad, id: "hb-debt-min")
            Text(debt == nil ? "For a debt you've already been paying, enter what you owe today." : "Balance here is where you started. Payments you log are taken off it.").font(.footnote).foregroundColor(HB.soft)
            if let e = error { Text(e).font(.footnote.weight(.semibold)).foregroundColor(HB.red) }
            HBPillButton(title: busy ? "Saving…" : "Save debt") { save() }.disabled(busy).accessibilityIdentifier("hb-debt-save")
            if debt != nil {
                Button { confirmDelete = true } label: {
                    Text("Delete debt").font(.system(size: 16, weight: .semibold)).foregroundColor(HB.red).frame(maxWidth: .infinity, minHeight: 50).overlay(Capsule().stroke(HB.red.opacity(0.6), lineWidth: 1))
                }.accessibilityIdentifier("hb-debt-delete")
            }
        }
        .onAppear { if let d = debt { name = d.name; balance = hbTrim(d.start); apr = d.apr == 0 ? "" : hbTrim(d.apr); minimum = d.minimum == 0 ? "" : hbTrim(d.minimum) } }
        .confirmationDialog("Delete \(debt?.name ?? "this debt")?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { remove() }
            Button("Keep it", role: .cancel) {}
        } message: { Text("Its payment history goes too. Payments stay in your spending.") }
    }
    private func draft() -> HBDebtDraft { HBDebtDraft(name: name, balance: hbNumber(balance), apr: hbNumber(apr), minimum: hbNumber(minimum)) }
    private func save() {
        let d = draft()
        if d.name.trimmingCharacters(in: .whitespaces).isEmpty { error = "Name the debt."; return }
        if balance.trimmingCharacters(in: .whitespaces).isEmpty { error = "Enter a balance."; return }
        if d.apr < 0 || d.apr > 100 { error = "Enter an interest rate from 0 to 100%."; return }
        busy = true; error = nil
        Task {
            do { if let x = debt { try await store.updateDebt(id: x.id, d) } else { try await store.addDebt(d) }; dismiss() } catch { self.error = error.localizedDescription }
            busy = false
        }
    }
    private func remove() {
        guard let x = debt else { return }
        busy = true
        Task { do { try await store.deleteDebt(id: x.id); dismiss() } catch { self.error = error.localizedDescription }; busy = false }
    }
}

// MARK: - Debt: log a payment

@available(iOS 15.0, *)
struct HBDebtPayForm: View {
    @ObservedObject var store: HBAppStore
    let debt: HBDebt
    let onPaidOff: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var who = ""
    @State private var error: String?
    @State private var busy = false

    var body: some View {
        HBSheetScaffold(title: "Log a payment", onBack: { dismiss() }) {
            Text("\(debt.name) · \(HBFormat.money(debt.remaining)) left").font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
            HBAuthField(label: "Amount you paid", placeholder: "0.00", text: $amount, keyboard: .decimalPad, id: "hb-pay-amount")
            if store.members.count > 1 {
                HBField(title: "Who paid") {
                    HStack(spacing: 8) {
                        ForEach(store.members) { m in
                            Button { who = m.id } label: {
                                Text(m.name).font(.system(size: 15, weight: .semibold)).lineLimit(1).padding(.horizontal, 14).frame(height: 38)
                                    .foregroundColor(who == m.id ? Color.black.opacity(0.85) : .white).background(Capsule().fill(who == m.id ? HB.orange : Color.white.opacity(0.08)))
                            }
                        }
                    }
                }
            }
            Text("It's also logged as an expense so it counts in this month's spending.").font(.footnote).foregroundColor(HB.soft)
            if let e = error { Text(e).font(.footnote.weight(.semibold)).foregroundColor(HB.red) }
            HBPillButton(title: busy ? "Saving…" : "Log payment") { save() }.disabled(busy).accessibilityIdentifier("hb-pay-save")
        }
        .onAppear { who = store.myID; if amount.isEmpty && debt.min_cents > 0 { amount = String(format: "%.2f", debt.minimum) } }
    }
    private func save() {
        let a = hbNumber(amount)
        guard a > 0 else { error = "Enter the amount you paid."; return }
        busy = true; error = nil
        Task {
            do {
                try await store.payDebt(debt, amount: a, memberID: who.isEmpty ? store.myID : who)
                let nowPaidOff = store.snapshot?.debts?.first { $0.id == debt.id }?.paidOff ?? false
                dismiss()
                if nowPaidOff { onPaidOff(debt.name) }
            } catch { self.error = error.localizedDescription }
            busy = false
        }
    }
}
