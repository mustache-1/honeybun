import SwiftUI
import UIKit

private func hbParseAmount(_ s: String) -> Double? {
    let t = s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".").replacingOccurrences(of: "$", with: "")
    guard let v = Double(t), v > 0, v <= 10_000_000 else { return nil }
    return v
}
private func hbHideKeyboard() { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }

@available(iOS 15.0, *)
struct HBField<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.footnote.weight(.semibold)).foregroundColor(HB.soft)
            content
        }
    }
}

// Add / edit an expense or income. Saving goes to the existing /api/entries endpoints; the store then reloads, so Home and Money update by themselves.
@available(iOS 15.0, *)
struct HBEntryForm: View {
    @ObservedObject var store: HBAppStore
    let editing: HBEntry?
    let base: HBEntryDraft
    @Environment(\.dismiss) private var dismiss

    @State private var type: String
    @State private var amountText: String
    @State private var label: String
    @State private var category: String
    @State private var date: Date
    @State private var memberID: String
    @State private var shared: Bool
    @State private var error: String?
    @State private var saving = false
    @State private var confirmDelete = false

    init(store: HBAppStore, editing: HBEntry?, base: HBEntryDraft) {
        self.store = store; self.editing = editing; self.base = base
        _type = State(initialValue: base.type)
        _amountText = State(initialValue: editing == nil ? "" : String(format: "%.2f", base.amount))
        _label = State(initialValue: base.label)
        _category = State(initialValue: base.category)
        _date = State(initialValue: HBDay.parse(base.date) ?? Date())
        _memberID = State(initialValue: base.memberID)
        _shared = State(initialValue: base.shared)
    }

    private var isIncome: Bool { type == "income" }
    private var canShare: Bool { !isIncome && store.members.count > 1 && !store.isJoint }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Type", selection: $type) {
                        Text("Expense").tag("expense")
                        Text("Income").tag("income")
                    }.pickerStyle(.segmented)

                    HBField(title: "Amount") {
                        HStack {
                            Text("$").font(.title2.weight(.bold)).foregroundColor(HB.soft)
                            TextField("0.00", text: $amountText).keyboardType(.decimalPad)
                                .font(.system(size: 34, weight: .heavy).monospacedDigit()).foregroundColor(.white)
                        }
                        .padding(14).hbCard()
                    }
                    HBField(title: isIncome ? "Source" : "What was it for?") {
                        TextField(isIncome ? "Paycheck" : "Groceries", text: $label)
                            .foregroundColor(.white).padding(14).hbCard()
                    }
                    if !isIncome {
                        HBField(title: "Category") {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
                                ForEach(HBCategory.allCases) { c in
                                    Button { category = c.rawValue } label: {
                                        VStack(spacing: 5) {
                                            Image(systemName: c.symbol).font(.system(size: 18, weight: .semibold))
                                            Text(c.name).font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                                        }
                                        .frame(maxWidth: .infinity, minHeight: 58)
                                        .foregroundColor(category == c.rawValue ? Color.black.opacity(0.85) : .white)
                                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(category == c.rawValue ? HB.orange : Color.white.opacity(0.07)))
                                    }
                                }
                            }
                        }
                    }
                    HBField(title: "Date") {
                        DatePicker("Date", selection: $date, displayedComponents: .date).labelsHidden().datePickerStyle(.compact)
                            .padding(10).frame(maxWidth: .infinity, alignment: .leading).hbCard()
                    }
                    if store.members.count > 1 {
                        HBField(title: isIncome ? "Who got it?" : "Who paid?") {
                            Picker("Who", selection: $memberID) {
                                ForEach(store.members) { m in Text(m.id == store.myID ? "\(m.name) (you)" : m.name).tag(m.id) }
                            }.pickerStyle(.segmented)
                        }
                    }
                    if canShare {
                        Toggle("Split with the household", isOn: $shared).tint(HB.orangeDeep).foregroundColor(.white).padding(14).hbCard()
                    }
                    if let error = error { Text(error).font(.footnote.weight(.semibold)).foregroundColor(HB.red) }

                    Button(action: save) {
                        Text(saving ? "Saving…" : (editing == nil ? (isIncome ? "Add income" : "Add expense") : "Save changes"))
                            .font(.headline).foregroundColor(Color.black.opacity(0.85)).frame(maxWidth: .infinity, minHeight: 50)
                            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(isIncome ? HB.green : HB.orange))
                    }
                    .disabled(saving)

                    if editing != nil {
                        Button(role: .destructive) { confirmDelete = true } label: {
                            Text("Delete").font(.headline).frame(maxWidth: .infinity, minHeight: 46)
                                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(HB.red.opacity(0.6), lineWidth: 1))
                        }
                        .foregroundColor(HB.red)
                        .disabled(saving)
                    }
                }
                .frame(maxWidth: 560)
                .padding(HB.gutter)
                .frame(maxWidth: .infinity)
            }
            .background(HB.bg.ignoresSafeArea())
            .navigationTitle(editing == nil ? (isIncome ? "Add income" : "Add expense") : "Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { hbHideKeyboard() } }
            }
            .confirmationDialog("Delete this entry?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { remove() }
                Button("Keep it", role: .cancel) {}
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.dark)
    }

    private func draft() -> HBEntryDraft? {
        guard let amount = hbParseAmount(amountText) else { error = "Enter an amount more than $0."; return nil }
        var d = base
        d.type = type; d.amount = amount
        d.label = label.trimmingCharacters(in: .whitespaces)
        d.category = category
        d.date = HBDay.string(date)
        d.memberID = memberID.isEmpty ? store.myID : memberID
        d.shared = canShare && shared
        if !d.shared { d.splitMode = nil; d.splitValue = nil }
        if isIncome { d.shared = false; d.splitMode = nil; d.splitValue = nil }
        return d
    }

    private func save() {
        hbHideKeyboard(); error = nil
        guard let d = draft() else { return }
        saving = true
        Task {
            do {
                if let e = editing { try await store.updateEntry(id: e.id, d) } else { try await store.addEntry(d) }
                dismiss()
            } catch { self.error = error.localizedDescription }
            saving = false
        }
    }

    private func remove() {
        guard let e = editing else { return }
        saving = true
        Task {
            do { try await store.deleteEntry(id: e.id); dismiss() } catch { self.error = error.localizedDescription }
            saving = false
        }
    }
}
