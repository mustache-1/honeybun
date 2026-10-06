import SwiftUI

// One bar pair (spent / came in) for a few days of the month, drawn from the real entries.
private struct HBBucket: Identifiable { let id: Int; let spent: Double; let last: Double }

@available(iOS 15.0, *)
struct HBMoneyView: View {
    @ObservedObject var store: HBAppStore
    @ObservedObject private var metrics = HBLayoutMetrics.shared
    @State private var showAllCategories = false

    // MARK: derived from the store

    private var daysInMonth: Int {
        guard let d = HBDay.parse(store.month + "-01"), let r = HBDay.cal.range(of: .day, in: .month, for: d) else { return 30 }
        return r.count
    }
    // spending this month vs last month, per couple of days, from the real transactions' dates and amounts (see HBChartMath)
    private var buckets: [HBBucket] {
        let this = HBChartMath.slices(daily: HBChartMath.dailyExpenses(store.entries), daysInMonth: daysInMonth)
        let last = HBChartMath.slices(daily: store.prevDaily, daysInMonth: daysInMonth)
        return (0..<this.count).map { HBBucket(id: $0, spent: this[$0], last: last[$0]) }
    }
    private var axisLabels: [(String, CGFloat)] {
        let mon = String(HBDay.monthName(store.month).prefix(3))
        let days = [1, 8, 15, 22, 29].filter { $0 <= daysInMonth }
        return days.map { ("\(mon) \($0)", CGFloat($0 - 1) / CGFloat(max(1, daysInMonth - 1))) }
    }
    private struct CatRow: Identifiable { let id: String; let category: HBCatStyle; let total: Double; let pct: Int }
    private var categoryRows: [CatRow] {
        let totals = store.categoryTotals
        let sum = totals.reduce(0) { $0 + $1.total }
        guard sum > 0 else { return [] }
        func pct(_ v: Double) -> Int { Int((v / sum * 100).rounded()) }
        // biggest first, but "Other" always last (like the mockup)
        let other = HBCatStyle.of("other")
        let ordered = totals.filter { $0.category.id != "other" } + totals.filter { $0.category.id == "other" }
        let all = ordered.map { CatRow(id: $0.category.id, category: $0.category, total: $0.total, pct: pct($0.total)) }
        if showAllCategories || all.count <= 5 { return all }
        // top four, then everything else together as "Other" (like the mockup)
        let head = Array(all.filter { $0.category.id != "other" }.prefix(4))
        let headIDs = Set(head.map { $0.id })
        let rest = totals.filter { !headIDs.contains($0.category.id) }.reduce(0) { $0 + $1.total }
        return head + (rest > 0 ? [CatRow(id: "other-rest", category: other, total: rest, pct: pct(rest))] : [])
    }

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Money").font(.system(size: 34, weight: .bold)).foregroundColor(.white)
                    Text("Track, plan, and grow together.").font(.system(size: 16)).foregroundColor(Color(red: 0.74, green: 0.69, blue: 0.9))
                }
                HBMonthMenu(store: store)
                HStack(spacing: 12) {
                    sum("Income", store.income, HB.green, "arrow.up")
                    sum("Expenses", store.spent, HB.red, "arrow.down")
                }
                chart
                categories
                if let n = store.notice { Text(n).font(.footnote).foregroundColor(HB.red).onTapGesture { store.notice = nil } }
                carryCard
                insight
                moreCard
            }
            .frame(maxWidth: 560)
            .padding(.horizontal, HB.gutter).padding(.top, 8)
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

    private func sum(_ title: String, _ v: Double, _ tint: Color, _ symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 20, weight: .bold)).foregroundColor(tint)
                .frame(width: 44, height: 44).background(Circle().fill(tint.opacity(0.22))).overlay(Circle().stroke(tint.opacity(0.4), lineWidth: 1))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .medium)).foregroundColor(tint)
                Text(HBFormat.money(v)).font(.system(size: 21, weight: .bold).monospacedDigit()).foregroundColor(.white).minimumScaleFactor(0.55).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(14).frame(maxWidth: .infinity).hbCard()
    }

    // spent (orange) and came in (purple), per couple of days
    private var chart: some View {
        let b = buckets
        let top = max(1, b.map { max($0.spent, $0.last) }.max() ?? 1)
        return VStack(spacing: 8) {
            HStack(spacing: 14) {
                legend("This month", Color(red: 1, green: 0.66, blue: 0.3))
                legend("Last month", Color(red: 0.62, green: 0.48, blue: 0.9))
                Spacer(minLength: 0)
            }
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(b) { x in
                    HStack(alignment: .bottom, spacing: 2) {
                        bar(x.spent / top, [Color(red: 1, green: 0.66, blue: 0.3), Color(red: 0.96, green: 0.5, blue: 0.22)])
                        bar(x.last / top, [Color(red: 0.7, green: 0.55, blue: 0.95), Color(red: 0.5, green: 0.36, blue: 0.85)])
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 150, alignment: .bottom)
            .overlay(Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1), alignment: .bottom)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    ForEach(Array(axisLabels.enumerated()), id: \.offset) { _, l in
                        Text(l.0).font(.system(size: 12)).foregroundColor(HB.soft).fixedSize()
                            .position(x: min(max(28, g.size.width * l.1), g.size.width - 28), y: 8)
                    }
                }
            }
            .frame(height: 18)
        }
        .padding(.horizontal, 14).padding(.top, 18).padding(.bottom, 10)
        .hbCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Chart of spending and income this month")
    }
    private func legend(_ text: String, _ c: Color) -> some View {
        HStack(spacing: 6) { Circle().fill(c).frame(width: 8, height: 8); Text(text).font(.system(size: 12, weight: .medium)).foregroundColor(HB.soft) }
    }
    private func bar(_ ratio: Double, _ colors: [Color]) -> some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom))
            .frame(maxWidth: .infinity)
            .frame(height: ratio > 0 ? max(6, 150 * CGFloat(ratio)) : 3)
            .opacity(ratio > 0 ? 1 : 0.18)
    }

    private var categories: some View {
        let rows = categoryRows
        return VStack(alignment: .leading, spacing: 8) {
            HBSectionHeader(title: "Spending by category", action: store.categoryTotals.count > 5 ? (showAllCategories ? "Show less" : "See all") : nil) { showAllCategories.toggle() }
            VStack(spacing: 0) {
                if rows.isEmpty {
                    Text("No spending this month.").font(.subheadline).foregroundColor(HB.soft).padding(16).frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(Array(rows.enumerated()), id: \.element.id) { i, row in
                    HStack(spacing: 12) {
                        HBCatIcon(style: row.category, size: 36)
                        Text(row.category.label).font(.system(size: 17)).foregroundColor(.white).lineLimit(1)
                        Spacer(minLength: 6)
                        Text("\(row.pct)%").font(.system(size: 15)).foregroundColor(HB.soft).frame(width: 44, alignment: .trailing)
                        Text(HBFormat.money(row.total)).font(.system(size: 17, weight: .semibold).monospacedDigit()).foregroundColor(.white).frame(minWidth: 84, alignment: .trailing)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    if i < rows.count - 1 { Divider().background(HB.line).padding(.leading, 62) }
                }
            }
            .hbCard()
        }
    }

    // where the rest of the website's Plan lives: budgets, calendar, bills, subscriptions, debts
    private var moreCard: some View {
        VStack(spacing: 0) {
            moreRow("Plan", "Budgets, calendar, bills, subscriptions and debts", "calendar", id: "hb-money-plan") { store.sheet = .plan }
            Divider().background(HB.line).padding(.leading, 64)
            moreRow("Stats & year", "Your year, 50/30/20, badges and your monthly recap", "chart.pie.fill", id: "hb-money-stats") { store.sheet = .stats }
        }.hbCard()
        .accessibilityElement(children: .contain).accessibilityIdentifier("hb-last-card")
    }
    private func moreRow(_ title: String, _ sub: String, _ symbol: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                HBCircleIcon(symbol: symbol, tint: HB.orange, size: 38)
                VStack(alignment: .leading, spacing: 2) { Text(title).font(.system(size: 17, weight: .semibold)).foregroundColor(.white); Text(sub).font(.system(size: 13)).foregroundColor(HB.soft).lineLimit(2) }
                Spacer(minLength: 6)
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundColor(HB.soft)
            }
            .padding(.horizontal, 14).padding(.vertical, 12).contentShape(Rectangle())
        }.accessibilityIdentifier(id)
    }

    // "You're doing great!": compares this month with the one before, from real spending
    /// "Carried over from August +$X · This month …" (or "Started this month fresh") with a Change button for this month's decision.
    /// Settings → Monthly carry-over is a different thing: it decides what happens in future months.
    @ViewBuilder private var carryCard: some View {
        if let c = store.carryCard {
            let thisMonth = store.income - store.spent
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(c.kind == .fresh ? "Started this month fresh" : "Carried over from \(HBDay.monthName(c.fromMonth))").font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                    Spacer()
                    if case let .carried(v) = c.kind {
                        Text((v > 0 ? "+" : "") + HBFormat.money(v)).font(.system(size: 17, weight: .bold).monospacedDigit()).foregroundColor(v < 0 ? HB.red : HB.green)
                            .accessibilityIdentifier("hb-money-carry-amount")
                    }
                }
                if case .carried = c.kind {
                    HStack {
                        Text("This month").font(.system(size: 14)).foregroundColor(HB.soft)
                        Spacer()
                        Text((thisMonth > 0 ? "+" : "") + HBFormat.money(thisMonth)).font(.system(size: 15, weight: .semibold).monospacedDigit()).foregroundColor(thisMonth < 0 ? HB.red : .white)
                    }
                }
                if c.canChange {
                    Button { store.sheet = .carryChange } label: {
                        Text("Change this month's choice").font(.system(size: 15, weight: .semibold)).foregroundColor(HB.orange)
                    }
                    .accessibilityIdentifier("hb-money-carry-change")
                }
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading).hbCard()
            .accessibilityElement(children: .contain).accessibilityIdentifier("hb-money-carry")
        }
    }

    private var insight: some View {
        var title = "Keep logging!", text = "Add a few more days and Bun will compare your months."
        if let prev = store.prevSpent, prev > 0.5 {
            let diff = (store.spent - prev) / prev
            let pct = Int((abs(diff) * 100).rounded())
            if pct == 0 { title = "Right on track"; text = "Spending matches last month." }
            else if diff < 0 { title = "You're doing great!"; text = "Spending is \(pct)% lower than last month." }
            else { title = "Heads up"; text = "Spending is \(pct)% higher than last month." }
        }
        return HStack(spacing: 12) {
            Image("HBMoneyBun").resizable().scaledToFit().frame(width: 96, height: 92).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 21, weight: .bold)).foregroundColor(Color(red: 1, green: 0.83, blue: 0.48)).minimumScaleFactor(0.7).lineLimit(2)
                Text(text).font(.system(size: 16)).foregroundColor(Color(red: 0.86, green: 0.82, blue: 0.95)).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10).padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(LinearGradient(colors: [Color(red: 0.24, green: 0.15, blue: 0.14), Color(red: 0.13, green: 0.09, blue: 0.14)], startPoint: .leading, endPoint: .trailing)))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(HB.orange.opacity(0.28), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}
