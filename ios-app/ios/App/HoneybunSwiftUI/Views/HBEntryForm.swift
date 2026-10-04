import SwiftUI
import UIKit

func hbParseAmount(_ s: String) -> Double? {
    let t = s.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".").replacingOccurrences(of: "$", with: "")
    guard let v = Double(t), v > 0, v <= 10_000_000 else { return nil }
    return v
}
func hbHideKeyboard() { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }

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

// The tiles on the form.
private struct HBTileDef: Identifiable {
    let id: String; let label: String; let symbol: String; let rgb: (Double, Double, Double); let backend: String
}
// expense tiles: every real category of the account (same ids and names as the website), in the mockup's circle style
private let hbExpenseTiles: [HBTileDef] = HBCategory.allCases.map {
    HBTileDef(id: $0.rawValue, label: $0.label, symbol: $0.symbol, rgb: $0.rgb, backend: $0.rawValue)
}
private let hbIncomeTiles: [HBTileDef] = [
    HBTileDef(id: "Paycheck", label: "Paycheck", symbol: "briefcase.fill", rgb: (0.45, 0.90, 0.62), backend: ""),
    HBTileDef(id: "Gift", label: "Gift", symbol: "gift.fill", rgb: (1.00, 0.66, 0.30), backend: ""),
    HBTileDef(id: "Side Hustle", label: "Side Hustle", symbol: "leaf.fill", rgb: (0.45, 0.90, 0.62), backend: ""),
    HBTileDef(id: "Other", label: "Other", symbol: "ellipsis", rgb: (0.78, 0.72, 0.85), backend: ""),
]

// A row inside the details card: label on the left, value (and optional chevron) on the right.
@available(iOS 15.0, *)
private struct HBDetailRow<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing
    var body: some View {
        HStack(spacing: 12) {
            Text(title).font(.system(size: 17, weight: .medium)).foregroundColor(.white)
            Spacer(minLength: 8)
            trailing
        }
        .frame(minHeight: 52).padding(.horizontal, 16)
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
    @State private var pick: String          // which income tile is chosen
    @State private var date: Date
    @State private var showDate = false
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
        _pick = State(initialValue: base.type == "income"
            ? (hbIncomeTiles.first { $0.id == base.label }?.id ?? (editing == nil ? "Paycheck" : ""))
            : (editing == nil ? "" : (hbExpenseTiles.first { $0.backend == base.category }?.id ?? "")))
        _date = State(initialValue: HBDay.parse(base.date) ?? Date())
        _memberID = State(initialValue: base.memberID)
        _shared = State(initialValue: base.shared)
    }

    private var isIncome: Bool { type == "income" }
    private var canShare: Bool { !isIncome && store.members.count > 1 && !store.isJoint }
    private var tint: Color { isIncome ? HB.green : HB.orange }
    private var title: String { editing == nil ? (isIncome ? "Add Income" : "Add Expense") : "Edit " + (isIncome ? "Income" : "Expense") }
    private static let dayFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"; return f }()

    var body: some View {
        NavigationView {
            ZStack {
                HBBackground(glow: false, scene: false)
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        header
                        typeSwitch
                        amountCard
                        tiles
                        details
                        if let error = error { Text(error).font(.footnote.weight(.semibold)).foregroundColor(HB.red) }
                        saveButton
                        if editing != nil {
                            Button(role: .destructive) { confirmDelete = true } label: {
                                Text("Delete").font(.system(size: 17, weight: .semibold)).frame(maxWidth: .infinity, minHeight: 50)
                                    .overlay(RoundedRectangle(cornerRadius: 25, style: .continuous).stroke(HB.red.opacity(0.6), lineWidth: 1))
                            }
                            .foregroundColor(HB.red).disabled(saving)
                        }
                    }
                    .frame(maxWidth: 560)
                    .padding(.horizontal, HB.gutter).padding(.top, 6).padding(.bottom, 24)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationBarHidden(true)
            .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { hbHideKeyboard() } } }
            .confirmationDialog("Delete this entry?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { remove() }
                Button("Keep it", role: .cancel) {}
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.dark)
    }

    // back arrow + title, with the peeking witch-bun sitting on the top edge of the switch
    private var header: some View {
        ZStack(alignment: .top) {
            HStack {
                Button { dismiss() } label: { Image(systemName: "arrow.left").font(.system(size: 20, weight: .medium)).foregroundColor(.white).frame(width: 44, height: 44) }
                    .accessibilityLabel("Back")
                Spacer()
            }
            Text(title).font(.system(size: 22, weight: .bold)).foregroundColor(.white).frame(height: 44)
        }
        .overlay(alignment: .topTrailing) {
            HBPeekBun(width: 118, height: 83)
                .offset(x: -8, y: -12)
        }
        .zIndex(2)
    }

    private var typeSwitch: some View {
        HStack(spacing: 0) {
            segment("Expense", on: !isIncome, color: HB.orange) { if isIncome { pick = "" }; type = "expense"; error = nil }
            segment("Income", on: isIncome, color: HB.green) { if !isIncome { pick = "Paycheck" }; type = "income"; error = nil }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Color.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .padding(.top, 18)
    }
    private func segment(_ text: String, on: Bool, color: Color, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(text).font(.system(size: 17, weight: .semibold))
                .foregroundColor(on ? Color.black.opacity(0.82) : Color(red: 0.74, green: 0.69, blue: 0.9))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Capsule().fill(on ? color : Color.clear).shadow(color: on ? color.opacity(0.5) : .clear, radius: 8))
        }
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private var amountCard: some View {
        HStack(spacing: 2) {
            Text("$").font(.system(size: 40, weight: .bold)).foregroundColor(amountText.isEmpty ? Color(red: 0.76, green: 0.70, blue: 0.95) : .white)
            ZStack(alignment: .leading) {
                if amountText.isEmpty { Text("0.00").font(.system(size: 40, weight: .bold).monospacedDigit()).foregroundColor(Color(red: 0.76, green: 0.70, blue: 0.95)).allowsHitTesting(false) }
                TextField("", text: $amountText).keyboardType(.decimalPad)
                    .font(.system(size: 40, weight: .bold).monospacedDigit()).foregroundColor(.white).multilineTextAlignment(.leading)
                    .accessibilityLabel("Amount")
            }
            .fixedSize(horizontal: true, vertical: false).frame(minWidth: 96)
        }
        .frame(maxWidth: .infinity, minHeight: 84)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
    }

    private var tiles: some View {
        let defs = isIncome ? hbIncomeTiles : hbExpenseTiles
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8, alignment: .top), count: 4), spacing: 14) {
            ForEach(defs) { t in
                let on = pick == t.id
                Button {
                    pick = t.id
                    if !isIncome { category = t.backend }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: t.symbol).font(.system(size: 22, weight: .semibold)).foregroundColor(Color(rgb: t.rgb))
                            .frame(width: 58, height: 58)
                            .background(Circle().fill(Color(rgb: t.rgb).opacity(on ? 0.30 : 0.14)))
                            .overlay(Circle().stroke(Color(rgb: t.rgb).opacity(on ? 1 : 0.4), lineWidth: on ? 2 : 1))
                            .shadow(color: on ? Color(rgb: t.rgb).opacity(0.5) : .clear, radius: 8)
                        Text(t.label).font(.system(size: 12, weight: .medium)).foregroundColor(on ? .white : Color(red: 0.8, green: 0.76, blue: 0.9))
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                }
                .accessibilityLabel(t.label)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
    }

    private var details: some View {
        VStack(spacing: 0) {
            HBDetailRow(title: "Description") {
                TextField(isIncome ? (pick.isEmpty ? "Where did it come from?" : pick) : "What was this for?", text: $label)
                    .multilineTextAlignment(.trailing).foregroundColor(.white)
            }
            Divider().background(HB.line)
            Button { withAnimation(.easeInOut(duration: 0.2)) { showDate.toggle() }; hbHideKeyboard() } label: {
                HBDetailRow(title: "Date") {
                    HStack(spacing: 6) {
                        Text(Self.dayFmt.string(from: date)).font(.system(size: 17)).foregroundColor(Color(red: 0.74, green: 0.69, blue: 0.9))
                        Image(systemName: showDate ? "chevron.down" : "chevron.right").font(.system(size: 13, weight: .bold)).foregroundColor(HB.soft)
                    }
                }
            }
            .buttonStyle(.plain)
            if showDate {
                DatePicker("Date", selection: $date, displayedComponents: .date).datePickerStyle(.graphical).labelsHidden()
                    .padding(.horizontal, 8).tint(tint)
            }
            if store.members.count > 1 {
                Divider().background(HB.line)
                HBDetailRow(title: isIncome ? "Received by" : "Paid by") {
                    Menu {
                        ForEach(store.members) { m in
                            Button { memberID = m.id } label: { Text(m.id == store.myID ? "\(m.name) (you)" : m.name) }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(memberID == store.myID ? "You" : store.memberName(memberID)).font(.system(size: 17)).foregroundColor(Color(red: 0.74, green: 0.69, blue: 0.9))
                            Image(systemName: "chevron.up.chevron.down").font(.system(size: 11, weight: .bold)).foregroundColor(HB.soft)
                        }
                    }
                }
            }
            if !isIncome {
                Divider().background(HB.line)
                HBDetailRow(title: "Shared with") {
                    if canShare {
                        Menu {
                            Button { shared = false } label: { Text("Just me") }
                            Button { shared = true } label: { Text("Everyone (split equally)") }
                        } label: {
                            HStack(spacing: 6) {
                                Text(shared ? "Everyone" : "Just me").font(.system(size: 17)).foregroundColor(Color(red: 0.74, green: 0.69, blue: 0.9))
                                Image(systemName: "chevron.up.chevron.down").font(.system(size: 11, weight: .bold)).foregroundColor(HB.soft)
                            }
                        }
                    } else {
                        Text(store.isJoint ? "Joint account" : "Just me").font(.system(size: 17)).foregroundColor(Color(red: 0.74, green: 0.69, blue: 0.9))
                    }
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.09), lineWidth: 1))
    }

    private var saveButton: some View {
        Button(action: save) {
            Text(saving ? "Saving…" : (editing == nil ? (isIncome ? "Save Income" : "Save Expense") : "Save changes"))
                .font(.system(size: 19, weight: .bold)).foregroundColor(Color.black.opacity(0.85))
                .frame(maxWidth: .infinity, minHeight: 58)
                .background(Capsule().fill(LinearGradient(colors: [tint.opacity(1), tint.opacity(0.88)], startPoint: .top, endPoint: .bottom)))
                .shadow(color: tint.opacity(0.4), radius: 12, y: 4)
        }
        .disabled(saving)
        .padding(.top, 4)
    }

    private func draft() -> HBEntryDraft? {
        guard let amount = hbParseAmount(amountText) else { error = "Enter an amount more than $0."; return nil }
        var d = base
        d.type = type; d.amount = amount
        let typed = label.trimmingCharacters(in: .whitespaces)
        d.label = typed.isEmpty ? (isIncome ? (pick.isEmpty ? "Paycheck" : pick) : "") : typed
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
