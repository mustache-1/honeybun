import SwiftUI
import UIKit

@available(iOS 15.0, *)
struct HBRecurringForm: View {
    @ObservedObject var store: HBAppStore
    let editing: HBRecurring?
    let base: HBRecurringDraft
    @Environment(\.dismiss) private var dismiss

    @State private var type: String
    @State private var amountText: String
    @State private var label: String
    @State private var category: String
    @State private var showNewCategory = false
    @State private var customCountBefore = 0
    @State private var freq: String
    @State private var date: Date
    @State private var error: String?
    @State private var saving = false
    @State private var confirmDelete = false

    init(store: HBAppStore, editing: HBRecurring?, base: HBRecurringDraft) {
        self.store = store; self.editing = editing; self.base = base
        _type = State(initialValue: base.type)
        _amountText = State(initialValue: editing == nil ? "" : String(format: "%.2f", base.amount))
        _label = State(initialValue: base.label)
        _category = State(initialValue: base.category)
        _freq = State(initialValue: base.freq)
        _date = State(initialValue: HBDay.parse(base.date) ?? Date())
    }

    private var isIncome: Bool { type == "income" }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Type", selection: $type) { Text("Bill").tag("expense"); Text("Payday").tag("income") }.pickerStyle(.segmented)
                    HBField(title: "Name") { TextField(isIncome ? "Paycheck" : "Rent", text: $label).foregroundColor(.white).padding(14).hbCard() }
                    HBField(title: "Amount") {
                        HStack {
                            Text("$").font(.title2.weight(.bold)).foregroundColor(HB.soft)
                            TextField("0.00", text: $amountText).keyboardType(.decimalPad).font(.system(size: 30, weight: .heavy).monospacedDigit()).foregroundColor(.white)
                        }.padding(14).hbCard()
                    }
                    HBField(title: "Repeats") {
                        Picker("Repeats", selection: $freq) { Text("Weekly").tag("weekly"); Text("Every 2 weeks").tag("biweekly"); Text("Monthly").tag("monthly") }.pickerStyle(.segmented)
                    }
                    HBField(title: "Next date") {
                        DatePicker("Next date", selection: $date, displayedComponents: .date).labelsHidden().datePickerStyle(.compact)
                            .padding(10).frame(maxWidth: .infinity, alignment: .leading).hbCard()
                    }
                    if !isIncome {
                        HBField(title: "Category") {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
                                ForEach(HBCatStyle.all) { c in
                                    Button { category = c.id } label: {
                                        VStack(spacing: 5) {
                                            if let e = c.emoji { Text(e).font(.system(size: 18)) } else { Image(systemName: c.symbol).font(.system(size: 18, weight: .semibold)) }
                                            Text(c.label).font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                                        }
                                        .frame(maxWidth: .infinity, minHeight: 58)
                                        .foregroundColor(category == c.id ? Color.black.opacity(0.85) : .white)
                                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(category == c.id ? HB.orange : Color.white.opacity(0.07)))
                                    }
                                }
                                if (store.snapshot?.categories?.count ?? 0) < 12 {
                                    Button { customCountBefore = store.snapshot?.categories?.count ?? 0; showNewCategory = true } label: {
                                        VStack(spacing: 5) { Image(systemName: "plus").font(.system(size: 18, weight: .semibold)); Text("New").font(.caption.weight(.semibold)) }
                                            .frame(maxWidth: .infinity, minHeight: 58).foregroundColor(HB.orange)
                                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(HB.orange.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                                    }.accessibilityIdentifier("hb-recurring-new-category")
                                }
                            }
                            .sheet(isPresented: $showNewCategory, onDismiss: {
                                if let cats = store.snapshot?.categories, cats.count > customCountBefore, let c = cats.last { category = c.id }
                            }) { HBCategoryForm(store: store, existing: nil) }
                        }
                    }
                    if let error = error { Text(error).font(.footnote.weight(.semibold)).foregroundColor(HB.red) }
                    Button(action: save) {
                        Text(saving ? "Saving…" : (editing == nil ? "Add" : "Save changes")).font(.headline).foregroundColor(Color.black.opacity(0.85))
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(isIncome ? HB.green : HB.orange))
                    }.disabled(saving)
                    if editing != nil {
                        Button(role: .destructive) { confirmDelete = true } label: {
                            Text("Delete").font(.headline).frame(maxWidth: .infinity, minHeight: 46)
                                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(HB.red.opacity(0.6), lineWidth: 1))
                        }.foregroundColor(HB.red).disabled(saving)
                    }
                }
                .frame(maxWidth: 560).padding(HB.gutter).frame(maxWidth: .infinity)
            }
            .background(HBBackground(glow: false, scene: false))
            .navigationTitle(editing == nil ? "New bill or payday" : "Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) } }
            }
            .confirmationDialog("Delete this \(isIncome ? "payday" : "bill")?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { remove() }
                Button("Keep it", role: .cancel) {}
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.dark)
    }

    private func save() {
        error = nil
        let t = amountText.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".").replacingOccurrences(of: "$", with: "")
        guard let amount = Double(t), amount > 0 else { error = "Enter an amount more than $0."; return }
        var d = base
        d.type = type; d.amount = amount; d.label = label.trimmingCharacters(in: .whitespaces); d.category = category; d.freq = freq; d.date = HBDay.string(date)
        if d.memberID.isEmpty { d.memberID = store.myID }
        saving = true
        Task {
            do {
                if let r = editing { try await store.updateRecurring(id: r.id, d) } else { try await store.addRecurring(d) }
                dismiss()
            } catch { self.error = error.localizedDescription }
            saving = false
        }
    }

    private func remove() {
        guard let r = editing else { return }
        saving = true
        Task {
            do { try await store.deleteRecurring(id: r.id); dismiss() } catch { self.error = error.localizedDescription }
            saving = false
        }
    }
}

@available(iOS 15.0, *)
struct HBUpcomingList: View {
    @ObservedObject var store: HBAppStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 14) {
                    VStack(spacing: 0) {
                        let items = store.upcoming
                        if items.isEmpty {
                            Text("Nothing coming up. Add rent, bills and paydays once.").font(.subheadline).foregroundColor(HB.soft).padding(16)
                        }
                        ForEach(Array(items.enumerated()), id: \.element.id) { i, item in
                            if i > 0 { Divider().background(HB.line) }
                            HBUpcomingRow(store: store, item: item)
                        }
                    }.hbCard()
                    Button { store.sheet = .newRecurring } label: {
                        Text("Add a bill or payday").font(.headline).foregroundColor(Color.black.opacity(0.85)).frame(maxWidth: .infinity, minHeight: 50)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(HB.orange))
                    }
                }
                .frame(maxWidth: 560).padding(HB.gutter).frame(maxWidth: .infinity)
            }
            .background(HBBackground(glow: false, scene: false))
            .navigationTitle("Coming up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.dark)
    }
}

// Every transaction of the month on screen, grouped by day; tap one to edit or delete it. Opened from "See all" next to Latest.
@available(iOS 15.0, *)
struct HBTransactionsList: View {
    @ObservedObject var store: HBAppStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    HBMonthMenu(store: store)
                    if store.entries.isEmpty {
                        Text("Nothing yet this month.").font(.subheadline).foregroundColor(HB.soft).padding(16).frame(maxWidth: .infinity, alignment: .leading).hbCard()
                    }
                    ForEach(store.dayGroups) { group in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(HBDay.short(group.date)).font(.footnote.weight(.semibold)).foregroundColor(HB.soft).padding(.leading, 4)
                            VStack(spacing: 0) {
                                ForEach(Array(group.items.enumerated()), id: \.element.id) { i, e in
                                    if i > 0 { Divider().background(HB.line).padding(.leading, 62) }
                                    Button { store.sheet = .editEntry(e) } label: { HBEntryRow(entry: e, who: store.members.count > 1 ? store.memberName(e.member_id) : nil) }
                                        .buttonStyle(.plain)
                                        .contextMenu {
                                            Button { store.sheet = .editEntry(e) } label: { Label("Edit", systemImage: "pencil") }
                                            Button(role: .destructive) { Task { do { try await store.deleteEntry(id: e.id) } catch { store.notice = error.localizedDescription } } } label: { Label("Delete", systemImage: "trash") }
                                        }
                                }
                            }
                            .hbCard()
                        }
                    }
                    if let n = store.notice { Text(n).font(.footnote).foregroundColor(HB.red).onTapGesture { store.notice = nil } }
                }
                .frame(maxWidth: 560).padding(HB.gutter).padding(.bottom, 24).frame(maxWidth: .infinity)
            }
            .background(HBBackground(glow: false, scene: false))
            .navigationTitle("All transactions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.dark)
    }
}
