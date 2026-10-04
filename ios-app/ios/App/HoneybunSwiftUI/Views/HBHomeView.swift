import SwiftUI

@available(iOS 15.0, *)
struct HBUpcomingRow: View {
    @ObservedObject var store: HBAppStore
    let item: HBUpcoming
    @State private var working = false
    var body: some View {
        HStack(spacing: 8) {
            Button { store.sheet = .editRecurring(item.recurring) } label: {
                HStack(spacing: 12) {
                    if item.recurring.isIncome { HBTile(symbol: "dollarsign.circle.fill", tint: HB.green) } else { HBTile(symbol: HBCategory.of(item.recurring.category).symbol) }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.recurring.label).font(.body.weight(.semibold)).foregroundColor(.white).lineLimit(1)
                        Text((item.late ? "Late · " : "") + HBDay.short(item.dateString)).font(.footnote).foregroundColor(item.late ? HB.red : HB.soft)
                    }
                    Spacer(minLength: 8)
                    Text(HBFormat.money(item.recurring.amount)).font(.body.weight(.semibold).monospacedDigit())
                        .foregroundColor(item.recurring.isIncome ? HB.green : .white)
                    Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundColor(HB.soft)
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
                Image(systemName: working ? "hourglass" : "checkmark").font(.system(size: 14, weight: .bold)).foregroundColor(HB.orange)
                    .frame(width: 34, height: 34).overlay(Circle().stroke(HB.orange.opacity(0.55), lineWidth: 1))
            }
            .accessibilityLabel(item.recurring.isIncome ? "Mark received" : "Mark paid")
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }
}

@available(iOS 15.0, *)
struct HBMonthPill: View {
    @ObservedObject var store: HBAppStore
    var body: some View {
        HStack(spacing: 2) {
            Button { store.shiftMonth(-1) } label: { Image(systemName: "chevron.left").frame(width: 30, height: 30) }.accessibilityLabel("Previous month")
            Text(HBDay.monthName(store.month)).font(.subheadline.weight(.semibold)).lineLimit(1)
            Button { store.shiftMonth(1) } label: { Image(systemName: "chevron.right").frame(width: 30, height: 30) }.accessibilityLabel("Next month")
        }
        .font(.footnote.weight(.bold)).foregroundColor(Color(red: 1, green: 0.9, blue: 0.8))
        .padding(.horizontal, 4)
        .background(Capsule().fill(Color(red: 1, green: 0.78, blue: 0.5).opacity(0.18)))
        .overlay(Capsule().stroke(Color(red: 1, green: 0.78, blue: 0.55).opacity(0.32), lineWidth: 1))
    }
}

@available(iOS 15.0, *)
struct HBHomeView: View {
    @ObservedObject var store: HBAppStore
    let onClose: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                summaryCard
                actions
                comingUp
                latest
                if let n = store.notice { Text(n).font(.footnote).foregroundColor(HB.red).onTapGesture { store.notice = nil } }
            }
            .frame(maxWidth: 560)
            .padding(.horizontal, HB.gutter).padding(.top, 8).padding(.bottom, 24)
            .frame(maxWidth: .infinity)
        }
        .refreshable { await store.refresh() }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("honeybun").font(.system(size: 30, weight: .bold, design: .rounded)).foregroundColor(HB.orange)
                Text(store.snapshot?.nest.name ?? "").font(.footnote).foregroundColor(HB.soft).lineLimit(1)
            }
            Spacer()
            Button(action: onClose) {
                Text("Classic").font(.footnote.weight(.semibold)).foregroundColor(HB.orange)
                    .padding(.horizontal, 12).padding(.vertical, 7).overlay(Capsule().stroke(HB.orange.opacity(0.5), lineWidth: 1))
            }
            .accessibilityLabel("Open classic Honeybun")
        }
    }

    private var summaryCard: some View {
        let total = store.income + store.carry
        let ratio = total > 0 ? min(1, store.spent / total) : (store.spent > 0 ? 1 : 0)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(store.isJoint ? "Safe to spend · Joint" : "Safe to spend").font(.headline).foregroundColor(Color(red: 1, green: 0.96, blue: 0.89))
                Spacer()
                HBMonthPill(store: store)
            }
            Text(HBFormat.money(store.left)).font(.system(size: 40, weight: .heavy).monospacedDigit())
                .minimumScaleFactor(0.5).lineLimit(1).foregroundColor(store.left < 0 ? HB.red : .white)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.28))
                    Capsule().fill(LinearGradient(colors: [store.spent > total ? HB.red : HB.orange, Color(red: 1, green: 0.83, blue: 0.48)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(8, g.size.width * CGFloat(ratio)))
                }
            }
            .frame(height: 10)
            HStack {
                Text("\(HBFormat.money(store.spent)) of \(HBFormat.money(total)) spent").font(.footnote).foregroundColor(Color(red: 0.98, green: 0.91, blue: 0.82))
                Spacer()
                Text("\(Int((ratio * 100).rounded()))%").font(.footnote.weight(.semibold)).foregroundColor(Color(red: 0.98, green: 0.91, blue: 0.82))
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(LinearGradient(colors: [Color(red: 0.36, green: 0.21, blue: 0.11), Color(red: 0.20, green: 0.12, blue: 0.08)], startPoint: .topTrailing, endPoint: .bottomLeading)))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(HB.orange.opacity(0.5), lineWidth: 1.5))
    }

    private var actions: some View {
        HStack(spacing: 10) {
            actionButton("Add expense", tint: HB.orange) { store.sheet = .newEntry("expense") }
            actionButton("Add income", tint: HB.green) { store.sheet = .newEntry("income") }
        }
    }
    private func actionButton(_ title: String, tint: Color, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "plus").font(.system(size: 13, weight: .heavy)).foregroundColor(Color.black.opacity(0.8))
                    .frame(width: 26, height: 26).background(Circle().fill(tint))
                Text(title).font(.subheadline.weight(.semibold)).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(tint.opacity(0.12)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(tint.opacity(0.45), lineWidth: 1))
        }
    }

    private var comingUp: some View {
        let items = store.upcoming
        return VStack(alignment: .leading, spacing: 6) {
            HBSectionHeader(title: "Coming up", action: "See all") { store.sheet = .upcoming }
            VStack(spacing: 0) {
                if items.isEmpty {
                    HStack {
                        Text("Add rent, bills and paydays once.").font(.subheadline).foregroundColor(HB.soft)
                        Spacer()
                        Button("Add") { store.sheet = .newRecurring }.font(.subheadline.weight(.bold)).foregroundColor(HB.orange)
                    }.padding(14)
                } else {
                    ForEach(Array(items.prefix(3).enumerated()), id: \.element.id) { i, item in
                        if i > 0 { Divider().background(HB.line) }
                        HBUpcomingRow(store: store, item: item)
                    }
                }
            }
            .hbCard()
        }
    }

    private var latest: some View {
        let recent = Array(store.entries.prefix(4))
        return VStack(alignment: .leading, spacing: 6) {
            HBSectionHeader(title: "Latest", action: "See all") { store.selectedTab = .money }
            VStack(spacing: 0) {
                if recent.isEmpty {
                    Text("Nothing yet this month. Add your first expense or income.").font(.subheadline).foregroundColor(HB.soft).padding(14)
                } else {
                    ForEach(Array(recent.enumerated()), id: \.element.id) { i, e in
                        if i > 0 { Divider().background(HB.line) }
                        Button { store.sheet = .editEntry(e) } label: { HBEntryRow(entry: e, who: store.members.count > 1 ? store.memberName(e.member_id) : nil) }
                            .buttonStyle(.plain)
                    }
                }
            }
            .hbCard()
        }
    }
}
