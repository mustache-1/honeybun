import SwiftUI

// MARK: - Debt Center+: a friendlier home for the debts that already live in Plan.
// Nothing here is a second debt system: the debts, payments, forms, Snowball / Avalanche rules and the "extra each month" setting are the same ones
// Plan uses (HBPlan.payoffPlan, HBDebtPrefs, HBDebtForm, HBDebtPayForm, /api/debts…). This screen only presents them: the journey so far, the payoff
// path, Snowball next to Avalanche, "what if I paid more?", richer rows, and who in the household has paid what.

private enum HBDebtCenterSheet: Identifiable {
    case add, edit(HBDebt), pay(HBDebt)
    var id: String {
        switch self {
        case .add: return "add"
        case let .edit(d): return "edit-" + d.id
        case let .pay(d): return "pay-" + d.id
        }
    }
}

@available(iOS 15.0, *)
struct HBDebtCenterView: View {
    @ObservedObject var store: HBAppStore
    @Environment(\.dismiss) private var dismiss
    @State private var sheet: HBDebtCenterSheet?
    @State private var strategy = HBDebtPrefs.strategy()
    @State private var extraText = { let e = HBDebtPrefs.extra(); return e > 0 ? HBPlanText.percent(e) : "" }()
    @State private var celebrate: String?

    private var extra: Double { max(0, Double(extraText.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")) ?? 0) }

    var body: some View {
        HBSheetScaffold(title: "Debt Center", onBack: { dismiss() }) {
            if let s = store.snapshot {
                let debts = s.debts ?? []
                if debts.isEmpty { emptyCard } else { center(s, debts) }
            } else {
                ProgressView().tint(HB.orange).frame(maxWidth: .infinity).padding(40)
            }
        }
        .sheet(item: $sheet) { which in
            switch which {
            case .add: HBDebtForm(store: store, debt: nil)
            case let .edit(d): HBDebtForm(store: store, debt: d)
            case let .pay(d): HBDebtPayForm(store: store, debt: d) { name in celebrate = name }
            }
        }
        .alert("🎉 Paid off!", isPresented: Binding(get: { celebrate != nil }, set: { if !$0 { celebrate = nil } })) {
            Button("Yay!", role: .cancel) { celebrate = nil }
        } message: { Text("\(celebrate ?? "That debt") is paid off. Well done!") }
    }

    // MARK: layout

    @ViewBuilder private func center(_ s: HBNestSnapshot, _ debts: [HBDebt]) -> some View {
        let summary = HBPlan.debtSummary(debts)
        let plan = HBPlan.payoffPlan(debts, strategy: strategy, extra: extra)
        heroCard(summary, plan)
        if summary.remaining > 0 {
            if let m = plan.months, m > 0 { pathCard(debts, plan, summary) }
            strategyCard(debts)
            extraCard(debts)
        }
        debtsCard(s, debts, plan, summary)
        if s.members.count > 1 { householdCard(s, debts) }
        HBPillButton(title: "Add a debt", symbol: "plus", filled: false) { sheet = .add }.accessibilityIdentifier("hb-debtcenter-add")
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Track what you owe").font(.system(size: 20, weight: .bold)).foregroundColor(.white)
            Text("Add credit cards, car loans or student loans. Honeybun shows your payoff path, compares Snowball and Avalanche, and shows what a little extra each month would do.")
                .font(.system(size: 15)).foregroundColor(HB.soft).fixedSize(horizontal: false, vertical: true)
            HBPillButton(title: "Add a debt", symbol: "plus") { sheet = .add }.accessibilityIdentifier("hb-debtcenter-add")
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).hbCard()
    }

    // MARK: the journey

    private func heroCard(_ sum: HBDebtSummary, _ plan: HBPayoffPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YOUR DEBT-FREE JOURNEY").font(.system(size: 12, weight: .bold)).tracking(1.1).foregroundColor(HB.orange)
            if sum.remaining <= 0 {
                Text("Everything's paid off 🎉").font(.system(size: 26, weight: .heavy)).foregroundColor(.white)
                Text("You paid down \(HBFormat.money(sum.paidTotal)). That took real effort.").font(.system(size: 15)).foregroundColor(HB.soft)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(HBFormat.money(sum.remaining)).font(.system(size: 34, weight: .heavy).monospacedDigit()).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.55)
                    Text("left").font(.system(size: 17, weight: .semibold)).foregroundColor(HB.soft)
                }
                progressBar(sum.progress, height: 12)
                Text("\(percent(sum.progress)) paid · \(HBFormat.money(sum.paidTotal)) of \(HBFormat.money(sum.startTotal))")
                    .font(.system(size: 14)).foregroundColor(HB.soft).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    statTile("Debt-free", plan.months.map { HBPlan.monthsOut($0) } ?? "—", sub: plan.months.map { HBPlan.duration(months: $0) }, id: "hb-debtcenter-free")
                    statTile("Interest", plan.months != nil ? HBFormat.money(plan.interest, cents: false) : "—", sub: "at this pace", id: "hb-debtcenter-interest")
                    statTile("Monthly", HBFormat.money(sum.minimums + extra, cents: false), sub: extra > 0 ? "with extra" : "minimums", id: "hb-debtcenter-monthly")
                }
                if plan.months == nil { Text(noDateText(sum)).font(.system(size: 14)).foregroundColor(HB.orange).fixedSize(horizontal: false, vertical: true) }
                else { Text(encouragement(sum.progress)).font(.system(size: 14)).foregroundColor(Color(red: 0.86, green: 0.82, blue: 0.95)).fixedSize(horizontal: false, vertical: true) }
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).hbCard()
        .accessibilityIdentifier("hb-debtcenter-hero")
    }

    private func noDateText(_ sum: HBDebtSummary) -> String {
        if sum.minimums + extra <= 0 { return "Add minimum payments to your debts (or an extra amount below) to see your debt-free date." }
        return "At this pace the payments don't catch up with the interest. Try an extra amount below."
    }

    private func encouragement(_ p: Double) -> String {
        if p >= 0.75 { return "So close. The finish line is in sight." }
        if p >= 0.5 { return "Past halfway. Bun is cheering you on." }
        if p >= 0.25 { return "A quarter of the way there. Keep going." }
        if p > 0 { return "Every payment counts. You've started, and that's the hard part." }
        return "Log a payment and watch this bar start to fill."
    }

    private func percent(_ p: Double) -> String { "\(Int((p * 100).rounded()))%" }

    private func statTile(_ title: String, _ value: String, sub: String?, id: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 11, weight: .bold)).foregroundColor(HB.soft).lineLimit(1).minimumScaleFactor(0.8)
            Text(value).font(.system(size: 16, weight: .bold).monospacedDigit()).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.6)
            if let sub = sub { Text(sub).font(.system(size: 11)).foregroundColor(HB.soft).lineLimit(1).minimumScaleFactor(0.8) }
        }
        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.06)))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(id)
    }

    private func progressBar(_ p: Double, height: CGFloat) -> some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.black.opacity(0.28))
                Capsule().fill(HB.green).frame(width: max(0, g.size.width * CGFloat(min(1, max(0, p)))))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }

    // MARK: the payoff path

    private func pathCard(_ debts: [HBDebt], _ plan: HBPayoffPlan, _ sum: HBDebtSummary) -> some View {
        // "minimums only" for comparison, when an extra payment is planned and the minimums alone do pay everything off
        let base: HBPayoffPlan? = extra > 0 ? HBPlan.payoffPlan(debts, strategy: strategy, extra: 0) : nil
        let baseline: HBPayoffPlan? = (base?.months != nil) ? base : nil
        let end = plan.months ?? 0
        return VStack(alignment: .leading, spacing: 10) {
            Text("Your payoff path").font(.system(size: 21, weight: .bold)).foregroundColor(.white)
            chart(plan, baseline: baseline).frame(height: 120)
            HStack {
                Text("Today").font(.system(size: 11)).foregroundColor(HB.soft)
                Spacer()
                Text(HBPlan.monthsOut(end)).font(.system(size: 11, weight: .semibold)).foregroundColor(HB.orange)
            }
            if let b = baseline, let bm = b.months, bm > end {
                HStack(spacing: 14) {
                    legend("With your plan", solid: true)
                    legend("Minimums only (\(HBPlan.monthsOut(bm)))", solid: false)
                }
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).hbCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Payoff path. \(HBFormat.money(sum.remaining)) owed today, debt-free around \(HBPlan.monthsOut(end)).")
        .accessibilityIdentifier("hb-debtcenter-path")
    }

    private func legend(_ text: String, solid: Bool) -> some View {
        HStack(spacing: 6) {
            Capsule().fill(solid ? HB.orange : Color.white.opacity(0.4)).frame(width: 16, height: 3)
            Text(text).font(.system(size: 11)).foregroundColor(HB.soft).lineLimit(1).minimumScaleFactor(0.8)
        }
    }

    private func chart(_ plan: HBPayoffPlan, baseline: HBPayoffPlan?) -> some View {
        GeometryReader { g in chartBody(plan, baseline, g.size) }
    }

    private func chartBody(_ plan: HBPayoffPlan, _ baseline: HBPayoffPlan?, _ size: CGSize) -> some View {
        let longest = max(plan.balances.count, baseline?.balances.count ?? 0)
        let maxX = max(1, longest - 1)
        let maxY = max(plan.balances.first ?? 0, baseline?.balances.first ?? 0)
        let line = linePath(plan.balances, size: size, maxY: maxY, maxX: maxX)
        let area = areaPath(plan.balances, size: size, maxY: maxY, maxX: maxX)
        let flat = baseline.map { linePath($0.balances, size: size, maxY: maxY, maxX: maxX) } ?? Path()
        return ZStack {
            area.fill(LinearGradient(colors: [HB.orange.opacity(0.28), HB.orange.opacity(0.02)], startPoint: .top, endPoint: .bottom))
            flat.stroke(Color.white.opacity(0.4), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [3, 6]))
            line.stroke(HB.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
        }
    }

    private func points(_ series: [Double], size: CGSize, maxY: Double, maxX: Int) -> [CGPoint] {
        guard series.count > 1, maxY > 0 else { return [] }
        let step = max(1, series.count / 120)
        var idx = Array(stride(from: 0, to: series.count, by: step))
        if idx.last != series.count - 1 { idx.append(series.count - 1) }
        return idx.map { i in
            CGPoint(x: CGFloat(i) / CGFloat(maxX) * size.width, y: size.height - CGFloat(series[i] / maxY) * (size.height - 8) - 4)
        }
    }

    private func linePath(_ series: [Double], size: CGSize, maxY: Double, maxX: Int) -> Path {
        var p = Path()
        for (n, pt) in points(series, size: size, maxY: maxY, maxX: maxX).enumerated() {
            if n == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        return p
    }

    private func areaPath(_ series: [Double], size: CGSize, maxY: Double, maxX: Int) -> Path {
        var p = linePath(series, size: size, maxY: maxY, maxX: maxX)
        if let last = points(series, size: size, maxY: maxY, maxX: maxX).last {
            p.addLine(to: CGPoint(x: last.x, y: size.height))
            p.addLine(to: CGPoint(x: 0, y: size.height))
            p.closeSubpath()
        }
        return p
    }

    // MARK: Snowball next to Avalanche

    private func strategyCard(_ debts: [HBDebt]) -> some View {
        let cmp = HBPlan.compareStrategies(debts, extra: extra)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Snowball or Avalanche?").font(.system(size: 21, weight: .bold)).foregroundColor(.white)
            HStack(alignment: .top, spacing: 10) {
                strategyOption(.snowball, cmp.snowball, best: cmp.better == .snowball)
                strategyOption(.avalanche, cmp.avalanche, best: cmp.better == .avalanche)
            }
            Text(verdict(cmp)).font(.system(size: 14)).foregroundColor(Color(red: 0.86, green: 0.82, blue: 0.95)).fixedSize(horizontal: false, vertical: true)
            Text(strategy.hint).font(.footnote).foregroundColor(HB.soft).fixedSize(horizontal: false, vertical: true)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).hbCard()
        .accessibilityIdentifier("hb-debtcenter-strategy")
    }

    private func verdict(_ cmp: HBStrategyCompare) -> String {
        guard cmp.snowball.months != nil, cmp.avalanche.months != nil else { return "Add minimum payments or an extra amount to compare the two." }
        guard let better = cmp.better else { return "For your debts, Snowball and Avalanche finish together with about the same interest." }
        var t = "\(better.title) costs about \(HBFormat.money(cmp.interestSaved)) less in interest"
        if cmp.monthsSooner > 0 { t += " and finishes \(HBPlan.duration(months: cmp.monthsSooner)) sooner." } else { t += "." }
        if better == .avalanche { t += " Snowball trades some of that for quicker first wins." }
        return t
    }

    private func strategyOption(_ s: HBDebtStrategy, _ p: HBPayoffPlan, best: Bool) -> some View {
        let selected = strategy == s
        return Button {
            strategy = s
            HBDebtPrefs.setStrategy(s)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(s.title).font(.system(size: 16, weight: .bold)).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.8)
                    Spacer(minLength: 2)
                    if best { Text("Saves most").font(.system(size: 10, weight: .bold)).foregroundColor(HB.green).lineLimit(1).minimumScaleFactor(0.7) }
                }
                Text(p.months.map { HBPlan.monthsOut($0) } ?? "No date yet").font(.system(size: 15, weight: .semibold)).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.7)
                Text(p.months.map { "\(HBPlan.duration(months: $0)) · \(HBFormat.money(p.interest)) interest" } ?? "Needs a monthly payment")
                    .font(.system(size: 12)).foregroundColor(HB.soft).fixedSize(horizontal: false, vertical: true)
            }
            .padding(12).frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(selected ? HB.orange.opacity(0.14) : Color.white.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(selected ? HB.orange : Color.white.opacity(0.08), lineWidth: selected ? 1.5 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("hb-debtcenter-strategy-" + s.rawValue)
    }

    // MARK: what if I paid more?

    private static let tryAdding: [Double] = [25, 50, 100, 250]

    private func extraCard(_ debts: [HBDebt]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What if I paid more?").font(.system(size: 21, weight: .bold)).foregroundColor(.white)
            HStack(spacing: 8) {
                Text("Extra each month $").font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                TextField("0", text: Binding(get: { extraText }, set: { setExtraText($0) }))
                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing).font(.system(size: 17, weight: .semibold).monospacedDigit()).foregroundColor(.white)
                    .padding(.horizontal, 12).frame(height: 40).background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white.opacity(0.07)))
                    .accessibilityIdentifier("hb-debtcenter-extra")
            }
            Text("Another amount toward your debts every month, on top of the minimums:").font(.footnote).foregroundColor(HB.soft).fixedSize(horizontal: false, vertical: true)
            ForEach(Self.tryAdding, id: \.self) { add in impactRow(debts, add) }
            if extra > 0 {
                Button { setExtraText("") } label: { Text("Back to minimums only").font(.footnote.weight(.semibold)).foregroundColor(HB.orange) }
                    .accessibilityIdentifier("hb-debtcenter-extra-reset")
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).hbCard()
        .accessibilityIdentifier("hb-debtcenter-extra-card")
    }

    private func setExtraText(_ t: String) {
        extraText = t
        HBDebtPrefs.setExtra(Double(t.replacingOccurrences(of: ",", with: ".")) ?? 0)
    }

    private func impactRow(_ debts: [HBDebt], _ add: Double) -> some View {
        let r = HBPlan.extraImpact(debts, strategy: strategy, extra: extra, adding: add)
        return Button {
            setExtraText(HBPlanText.percent(extra + add))
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("+" + HBFormat.money(add).replacingOccurrences(of: ".00", with: "")).font(.system(size: 16, weight: .bold).monospacedDigit()).foregroundColor(HB.orange).frame(minWidth: 52, alignment: .leading)
                Text(impactText(r)).font(.system(size: 14)).foregroundColor(.white).frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.05)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Sets your extra monthly payment to \(HBFormat.money(extra + add))")
    }

    private func impactText(_ r: HBExtraImpact) -> String {
        guard let m = r.plan.months else { return "Still no payoff date" }
        let date = HBPlan.monthsOut(m)
        if let sooner = r.monthsSooner, let saved = r.interestSaved {
            if sooner == 0 && saved < 0.5 { return "Debt-free around \(date)" }
            return (sooner > 0 ? "\(HBPlan.duration(months: sooner)) sooner · " : "") + "saves \(HBFormat.money(saved)) · \(date)"
        }
        return "Gives you a debt-free date: \(date)"
    }

    // MARK: each debt

    private func debtsCard(_ s: HBNestSnapshot, _ debts: [HBDebt], _ plan: HBPayoffPlan, _ sum: HBDebtSummary) -> some View {
        let ordered = HBPlan.debtsInPlanOrder(debts, plan: plan)
        return VStack(alignment: .leading, spacing: 12) {
            Text("Your debts").font(.system(size: 21, weight: .bold)).foregroundColor(.white)
            ForEach(Array(ordered.enumerated()), id: \.element.id) { i, d in
                if i > 0 { Divider().background(HB.line) }
                debtRow(s, d, rank: d.paidOff ? nil : i + 1, plan: plan, open: sum.openCount)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).hbCard()
        .accessibilityIdentifier("hb-debtcenter-debts")
    }

    private func debtRow(_ s: HBNestSnapshot, _ d: HBDebt, rank: Int?, plan: HBPayoffPlan, open: Int) -> some View {
        let focus = rank == 1 && open > 1
        let who = HBPlan.contributions(for: d, snapshot: s)
        return HStack(alignment: .top, spacing: 12) {
            Button { sheet = .edit(d) } label: {
                HStack(alignment: .top, spacing: 12) {
                    HBCircleIcon(symbol: d.paidOff ? "party.popper.fill" : "creditcard.fill", tint: d.paidOff ? HB.green : Color(red: 1, green: 0.55, blue: 0.45), size: 40)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Text((rank.map { "\($0). " } ?? "") + d.name).font(.system(size: 16, weight: .semibold)).foregroundColor(.white).lineLimit(2)
                            Spacer(minLength: 4)
                            Text(d.paidOff ? "Paid off" : HBFormat.money(d.remaining)).font(.system(size: 15, weight: .semibold).monospacedDigit()).foregroundColor(d.paidOff ? HB.green : .white).lineLimit(1).minimumScaleFactor(0.8)
                        }
                        progressBar(d.progress, height: 7)
                        Text("\(percent(d.progress)) paid of \(HBFormat.money(d.start))").font(.system(size: 12)).foregroundColor(HB.soft).fixedSize(horizontal: false, vertical: true)
                        if !d.paidOff { Text(facts(d, plan)).font(.system(size: 13)).foregroundColor(HB.soft).fixedSize(horizontal: false, vertical: true) }
                        if focus { Text(extra > 0 ? "Your extra goes here first" : "Focus here next").font(.system(size: 12, weight: .bold)).foregroundColor(HB.orange) }
                        if s.members.count > 1 && !who.isEmpty {
                            Text(contributionLine(who))
                                .font(.system(size: 12)).foregroundColor(Color(red: 0.72, green: 0.68, blue: 0.9)).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Edit this debt")
            if !d.paidOff {
                Button { sheet = .pay(d) } label: {
                    Text("Pay").font(.system(size: 14, weight: .bold)).foregroundColor(HB.orange).padding(.horizontal, 14).frame(height: 34).overlay(Capsule().stroke(HB.orange.opacity(0.7), lineWidth: 1))
                }
                .accessibilityLabel("Log a payment on \(d.name)")
            }
        }
    }

    private func contributionLine(_ who: [(memberID: String, paid: Double)]) -> String {
        var parts: [String] = []
        for c in who {
            let name = store.memberName(c.memberID)
            parts.append((name.isEmpty ? "Someone" : name) + " " + HBFormat.money(c.paid))
        }
        return parts.joined(separator: " · ")
    }

    private func facts(_ d: HBDebt, _ plan: HBPayoffPlan) -> String {
        var parts: [String] = []
        parts.append("\(HBPlanText.percent(d.apr))% APR")
        parts.append("min \(HBFormat.money(d.minimum))")
        if d.apr > 0 { parts.append("about \(HBFormat.money(d.remaining * d.apr / 100.0 / 12.0)) interest a month") }
        if let m = plan.done[d.id] { parts.append("paid off ~" + HBPlan.monthsOut(m)) }
        return parts.joined(separator: " · ")
    }

    // MARK: paying it down together

    private func householdCard(_ s: HBNestSnapshot, _ debts: [HBDebt]) -> some View {
        var acc: [String: Double] = [:]
        for d in debts { for c in HBPlan.contributions(for: d, snapshot: s) { acc[c.memberID, default: 0] += c.paid } }
        let totals = acc
        let ids = totals.keys.filter { (totals[$0] ?? 0) > 0 }.sorted { (totals[$0] ?? 0) > (totals[$1] ?? 0) }
        let all = totals.values.reduce(0, +)
        return Group {
            if !ids.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Paying it down together").font(.system(size: 21, weight: .bold)).foregroundColor(.white)
                    ForEach(ids, id: \.self) { id in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(memberLabel(id)).font(.system(size: 15, weight: .semibold)).foregroundColor(.white).lineLimit(1)
                                Spacer(minLength: 4)
                                Text(HBFormat.money(totals[id] ?? 0)).font(.system(size: 15, weight: .semibold).monospacedDigit()).foregroundColor(.white)
                            }
                            progressBar(all > 0 ? (totals[id] ?? 0) / all : 0, height: 6)
                        }
                        .accessibilityElement(children: .combine)
                    }
                    Text("Debts, and the payments logged on them, are shared with everyone in your household. Private entries stay private.")
                        .font(.footnote).foregroundColor(HB.soft).fixedSize(horizontal: false, vertical: true)
                }
                .padding(16).frame(maxWidth: .infinity, alignment: .leading).hbCard()
                .accessibilityIdentifier("hb-debtcenter-household")
            }
        }
    }

    private func memberLabel(_ id: String) -> String {
        let name = store.memberName(id)
        let who = name.isEmpty ? "Someone" : name
        if let e = store.member(id)?.emoji, !e.isEmpty { return e + " " + who }
        return who
    }
}
