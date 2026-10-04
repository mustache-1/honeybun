import SwiftUI

@available(iOS 15.0, *)
struct HBMoneyView: View {
    @ObservedObject var store: HBAppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Money").font(.system(size: 30, weight: .bold, design: .rounded)).foregroundColor(.white)
                    Spacer()
                    HBMonthPill(store: store)
                }
                HStack(spacing: 10) {
                    sum("Came in", store.income, HB.green, "arrow.down.circle.fill")
                    sum("Spent", store.spent, HB.red, "arrow.up.circle.fill")
                }
                categories
                transactions
            }
            .frame(maxWidth: 560)
            .padding(.horizontal, HB.gutter).padding(.top, 8).padding(.bottom, 24)
            .frame(maxWidth: .infinity)
        }
        .refreshable { await store.refresh() }
    }

    private func sum(_ title: String, _ v: Double, _ tint: Color, _ symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 22)).foregroundColor(tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.footnote).foregroundColor(HB.soft)
                Text(HBFormat.money(v)).font(.headline.monospacedDigit()).foregroundColor(.white).minimumScaleFactor(0.6).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(12).frame(maxWidth: .infinity).hbCard()
    }

    private var categories: some View {
        let totals = store.categoryTotals
        let top = totals.first?.total ?? 1
        return VStack(alignment: .leading, spacing: 6) {
            HBSectionHeader(title: "Where it went")
            VStack(spacing: 0) {
                if totals.isEmpty {
                    Text("No spending this month.").font(.subheadline).foregroundColor(HB.soft).padding(14)
                } else {
                    ForEach(Array(totals.enumerated()), id: \.element.id) { i, row in
                        if i > 0 { Divider().background(HB.line) }
                        HStack(spacing: 12) {
                            HBTile(symbol: row.category.symbol)
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(row.category.name).font(.subheadline.weight(.semibold)).foregroundColor(.white)
                                    Spacer()
                                    Text(HBFormat.money(row.total)).font(.subheadline.weight(.semibold).monospacedDigit()).foregroundColor(.white)
                                }
                                GeometryReader { g in
                                    Capsule().fill(Color.white.opacity(0.1)).overlay(
                                        Capsule().fill(HB.orange).frame(width: max(6, g.size.width * CGFloat(row.total / top))), alignment: .leading)
                                }.frame(height: 6)
                            }
                        }
                        .padding(.horizontal, 12).padding(.vertical, 10)
                    }
                }
            }
            .hbCard()
        }
    }

    private var transactions: some View {
        VStack(alignment: .leading, spacing: 6) {
            HBSectionHeader(title: "Transactions")
            if store.entries.isEmpty {
                Text("Nothing yet this month.").font(.subheadline).foregroundColor(HB.soft).padding(14).frame(maxWidth: .infinity, alignment: .leading).hbCard()
            }
            ForEach(store.dayGroups) { group in
                VStack(alignment: .leading, spacing: 4) {
                    Text(HBDay.short(group.date)).font(.footnote.weight(.semibold)).foregroundColor(HB.soft).padding(.leading, 4)
                    VStack(spacing: 0) {
                        ForEach(Array(group.items.enumerated()), id: \.element.id) { i, e in
                            if i > 0 { Divider().background(HB.line) }
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
    }
}
