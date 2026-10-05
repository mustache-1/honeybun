import SwiftUI

// MARK: - Plan: the website's Plan screen (budgets, bill calendar, bills & paydays, subscriptions, debts) plus its month-end forecast.
// Opens from Money. Everything here is the account's real data (/api/nest); every change goes through the same endpoints Classic uses.

private enum HBPlanSheet: Identifiable {
    case budgets, editBill(HBRecurring), newBill(subscription: Bool), debt(HBDebt?), pay(HBDebt)
    var id: String {
        switch self {
        case .budgets: return "budgets"
        case let .editBill(r): return "bill-" + r.id
        case let .newBill(s): return s ? "new-sub" : "new-bill"
        case let .debt(d): return "debt-" + (d?.id ?? "new")
        case let .pay(d): return "pay-" + d.id
        }
    }
}

@available(iOS 15.0, *)
struct HBPlanView: View {
    @ObservedObject var store: HBAppStore
    @Environment(\.dismiss) private var dismiss
    @State private var sheet: HBPlanSheet?
    @State private var calMonth = HBDay.monthKey()
    @State private var calSel: String?
    @State private var showSubs = false
    @State private var removing: HBDebtPayment?
    @State private var celebrate: String?
    @State private var error: String?

    private var snap: HBNestSnapshot? { store.snapshot }

    var body: some View {
        HBSheetScaffold(title: "Plan", onBack: { dismiss() }) {
            if let s = snap {
                forecastCard(s)
                budgetsCard(s)
                calendarCard(s)
                billsCard(s)
                debtsCard(s)
                if let e = error { Text(e).font(.footnote).foregroundColor(HB.red) }
            } else { ProgressView().tint(HB.orange).frame(maxWidth: .infinity).padding(40) }
        }
        .sheet(item: $sheet) { which in
            switch which {
            case .budgets: HBBudgetEditor(store: store)
            case let .editBill(r): HBRecurringForm(store: store, editing: r, base: store.draft(from: r))
            case let .newBill(sub):
                HBRecurringForm(store: store, editing: nil, base: { var d = HBRecurringDraft(date: HBDay.todayString, memberID: store.myID); if sub { d.category = "subs" }; return d }())
            case let .debt(d): HBDebtForm(store: store, debt: d)
            case let .pay(d): HBDebtPayForm(store: store, debt: d) { name in celebrate = name }
            }
        }
        .alert("Remove this payment?", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } })) {
            Button("Remove", role: .destructive) { if let p = removing { Task { do { try await store.deleteDebtPayment(id: p.id) } catch { self.error = error.localizedDescription } }; removing = nil } }
            Button("Keep it", role: .cancel) { removing = nil }
        } message: { Text("It's also removed from that month's spending.") }
        .alert("🎉 Paid off!", isPresented: Binding(get: { celebrate != nil }, set: { if !$0 { celebrate = nil } })) {
            Button("Yay!", role: .cancel) { celebrate = nil }
        } message: { Text("\(celebrate ?? "That debt") is paid off. Well done!") }
    }

    // MARK: forecast

    @ViewBuilder private func forecastCard(_ s: HBNestSnapshot) -> some View {
        switch HBPlan.forecast(s, month: store.month, myID: store.myID, lastMonthSpent: store.prevSpent) {
        case .notThisMonth: EmptyView()
        case .wait:
            VStack(alignment: .leading, spacing: 6) {
                Text("MONTH-END FORECAST").font(.system(size: 12, weight: .bold)).tracking(1.1).foregroundColor(HB.orange)
                Text("Check back in a few days").font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                Text("Bun needs a few days of spending to guess where the month is heading.").font(.footnote).foregroundColor(HB.soft)
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading).hbCard()
        case let .ready(f): HBForecastCard(f: f)
        }
    }

    // MARK: budgets

    private func budgetsCard(_ s: HBNestSnapshot) -> some View {
        let b = HBPlan.budgets(s)
        return VStack(alignment: .leading, spacing: 10) {
            HBSectionHeader(title: "Budget", action: "Edit") { sheet = .budgets }
            VStack(alignment: .leading, spacing: 12) {
                if b.rows.isEmpty {
                    Text("Give each category a monthly limit, like $400 for groceries. We'll warn you before you go over.").font(.footnote).foregroundColor(HB.soft)
                    HBPillButton(title: "Set budgets", symbol: "slider.horizontal.3", filled: false) { sheet = .budgets }.accessibilityIdentifier("hb-plan-set-budgets")
                } else {
                    budgetBar(title: "All budgets", ratio: b.totalLimit > 0 ? b.totalSpent / b.totalLimit : 0, over: b.over, warn: b.warn,
                              detail: "\(HBFormat.money(b.totalSpent)) of \(HBFormat.money(b.totalLimit))" + (b.totalCarry > 0 ? " (+\(HBFormat.money(b.totalCarry)) rolled over)" : ""))
                    ForEach(b.rows) { r in
                        budgetBar(title: HBCatStyle.of(r.category).label, ratio: r.ratio, over: r.over, warn: r.warn,
                                  detail: r.over ? "Over by \(HBFormat.money(r.spent - r.limit))" : "\(HBFormat.money(r.left)) left of \(HBFormat.money(r.limit))", style: HBCatStyle.of(r.category))
                    }
                }
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading).hbCard()
        }
    }
    private func budgetBar(title: String, ratio: Double, over: Bool, warn: Bool, detail: String, style: HBCatStyle? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if let st = style { HBCatIcon(style: st, size: 26) }
                Text(title).font(.system(size: 16, weight: .semibold)).foregroundColor(.white).lineLimit(1)
                Spacer(minLength: 6)
                Text(detail).font(.system(size: 13)).foregroundColor(over ? HB.red : (warn ? HB.orange : HB.soft)).lineLimit(1).minimumScaleFactor(0.75)
            }
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.28))
                    Capsule().fill(over ? HB.red : (warn ? HB.orange : Color(red: 1, green: 0.78, blue: 0.4))).frame(width: max(8, g.size.width * CGFloat(min(1, ratio))))
                }
            }.frame(height: 9)
        }
    }

    // MARK: calendar

    private func calendarCard(_ s: HBNestSnapshot) -> some View {
        let cal = HBPlan.calendar(month: calMonth, snapshot: s)
        let today = HBDay.todayString
        let cols = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Calendar").font(.system(size: 21, weight: .bold)).foregroundColor(.white)
                Spacer()
                Button { calMonth = HBDay.shiftMonth(calMonth, by: -1); calSel = nil } label: { Image(systemName: "chevron.left").frame(width: 34, height: 34) }.accessibilityLabel("Previous month")
                Text(HBDay.monthName(calMonth) + " " + String(calMonth.prefix(4))).font(.system(size: 15, weight: .semibold)).foregroundColor(HB.soft)
                Button { calMonth = HBDay.shiftMonth(calMonth, by: 1); calSel = nil } label: { Image(systemName: "chevron.right").frame(width: 34, height: 34) }.accessibilityLabel("Next month")
            }.foregroundColor(.white)
            VStack(spacing: 8) {
                LazyVGrid(columns: cols, spacing: 4) {
                    ForEach(Array(["S", "M", "T", "W", "T", "F", "S"].enumerated()), id: \.offset) { _, d in Text(d).font(.system(size: 12, weight: .semibold)).foregroundColor(HB.soft) }
                    ForEach(0..<cal.leadingBlanks, id: \.self) { _ in Color.clear.frame(height: 40) }
                    ForEach(cal.days) { d in dayCell(d, isToday: d.date == today) }
                }
                calendarDetail(cal.days)
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading).hbCard()
        }
    }
    private func dayCell(_ d: HBCalDay, isToday: Bool) -> some View {
        let on = calSel == d.date
        return Button { calSel = on ? nil : d.date } label: {
            VStack(spacing: 3) {
                Text("\(d.day)").font(.system(size: 15, weight: isToday ? .heavy : .medium)).foregroundColor(isToday ? HB.orange : .white)
                HStack(spacing: 2) {
                    ForEach(Array(d.items.prefix(3).enumerated()), id: \.offset) { _, it in
                        Circle().fill(it.recurring.isIncome ? HB.green : Color(red: 1, green: 0.37, blue: 0.53)).frame(width: 5, height: 5).opacity(it.done ? 0.35 : 1)
                    }
                }.frame(height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 40)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(on ? HB.orange.opacity(0.22) : Color.white.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(isToday ? HB.orange.opacity(0.8) : Color.clear, lineWidth: 1))
        }
        .accessibilityLabel("\(d.day)" + (d.items.isEmpty ? "" : ", " + d.items.map { $0.recurring.label }.joined(separator: ", ")))
    }
    @ViewBuilder private func calendarDetail(_ days: [HBCalDay]) -> some View {
        if let sel = calSel, let day = days.first(where: { $0.date == sel }) {
            VStack(alignment: .leading, spacing: 6) {
                Text(HBDay.short(sel)).font(.footnote.weight(.semibold)).foregroundColor(HB.soft)
                if day.items.isEmpty { Text("Nothing due this day.").font(.footnote).foregroundColor(HB.soft) }
                ForEach(Array(day.items.enumerated()), id: \.offset) { _, it in
                    HStack {
                        Text(it.recurring.label).foregroundColor(.white)
                        Spacer()
                        Text((it.recurring.isIncome ? "+" : "") + HBFormat.money(it.recurring.amount) + " · " + (it.done ? "Done ✓" : (it.date < HBDay.startOfToday() ? "Overdue" : (it.recurring.isIncome ? "Expected" : "Due"))))
                            .foregroundColor(HB.soft)
                    }.font(.system(size: 15))
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text("Tap a day to see what's due. Pink dots are bills, green are paydays.").font(.footnote).foregroundColor(HB.soft).frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: bills & paydays / subscriptions

    private func billsCard(_ s: HBNestSnapshot) -> some View {
        let subs = HBPlan.subscriptions(s)
        let bills = HBPlan.billsAndPaydays(s)
        let rows = showSubs ? subs.rows : bills
        return VStack(alignment: .leading, spacing: 10) {
            HBSectionHeader(title: showSubs ? "Subscriptions" : "Bills & paydays", action: showSubs ? "Add" : "Add") { sheet = .newBill(subscription: showSubs) }
            Picker("", selection: $showSubs) {
                Text("Bills & paydays").tag(false)
                Text("Subscriptions" + (subs.rows.isEmpty ? "" : " (\(subs.rows.count))")).tag(true)
            }.pickerStyle(.segmented).accessibilityIdentifier("hb-plan-bills-tab")
            VStack(spacing: 0) {
                if showSubs && !subs.rows.isEmpty { subsSummary(subs); Divider().background(HB.line) }
                if rows.isEmpty {
                    Text(showSubs ? "No subscriptions yet. Add Netflix, Spotify, your gym… and Bun will remind you before each charge 🐰" : "Rent, bills, paychecks. Add them once.")
                        .font(.footnote).foregroundColor(HB.soft).multilineTextAlignment(.center).padding(18).frame(maxWidth: .infinity)
                }
                ForEach(Array(rows.enumerated()), id: \.element.id) { i, r in
                    Button { sheet = .editBill(r) } label: { billRow(r) }
                    if i < rows.count - 1 { Divider().background(HB.line).padding(.leading, 62) }
                }
            }
            .hbCard()
            if !showSubs && !subs.rows.isEmpty {
                Button { showSubs = true } label: { Text("\(subs.rows.count) subscription\(subs.rows.count == 1 ? "" : "s") in the Subscriptions tab ›").font(.footnote.weight(.semibold)).foregroundColor(HB.orange) }
            }
        }
    }
    private func subsSummary(_ x: HBSubsSummary) -> some View {
        HStack {
            summaryItem(HBFormat.money(x.perMonth), "a month")
            summaryItem(HBFormat.money(x.perYear).replacingOccurrences(of: ".00", with: ""), "a year")
            summaryItem(x.next.map { HBDay.short(HBDay.string($0.date)) } ?? "–", x.next.map { "next: " + $0.recurring.label } ?? "next charge")
        }.padding(14)
    }
    private func summaryItem(_ big: String, _ small: String) -> some View {
        VStack(spacing: 2) { Text(big).font(.system(size: 18, weight: .bold).monospacedDigit()).foregroundColor(.white).minimumScaleFactor(0.7).lineLimit(1); Text(small).font(.system(size: 11)).foregroundColor(HB.soft).lineLimit(1).minimumScaleFactor(0.7) }
            .frame(maxWidth: .infinity)
    }
    private func billRow(_ r: HBRecurring) -> some View {
        let next = HBPlan.nextDate(r)
        let freq = ["weekly": "Every week", "biweekly": "Every 2 weeks", "monthly": "Every month"][r.freq] ?? r.freq
        var sub = freq + (next.map { ", next " + HBDay.short(HBDay.string($0)) } ?? "")
        if showSubs { sub += " · " + HBFormat.money(HBPlan.monthlyCost(r) * 12).replacingOccurrences(of: ".00", with: "") + "/yr" }
        else { sub += ", " + store.memberName(r.member_id) }
        return HStack(spacing: 12) {
            if r.isIncome { HBCircleIcon(symbol: "arrow.down", tint: HB.green, size: 38) } else { HBCatIcon(style: HBCatStyle.of(r.category), size: 38) }
            VStack(alignment: .leading, spacing: 2) {
                Text(r.label).font(.system(size: 16, weight: .semibold)).foregroundColor(.white).lineLimit(1)
                Text(sub).font(.system(size: 13)).foregroundColor(HB.soft).lineLimit(1).minimumScaleFactor(0.8)
            }
            Spacer(minLength: 8)
            Text((r.isIncome ? "+" : "") + HBFormat.money(r.amount)).font(.system(size: 16, weight: .semibold).monospacedDigit()).foregroundColor(r.isIncome ? HB.green : .white)
        }
        .padding(.horizontal, 14).padding(.vertical, 10).contentShape(Rectangle())
    }

    // MARK: debts

    private func debtsCard(_ s: HBNestSnapshot) -> some View {
        let debts = s.debts ?? []
        let pays = s.debt_payments ?? []
        let left = debts.reduce(0) { $0 + $1.remaining }, paid = debts.reduce(0) { $0 + Double($1.paid_cents) / 100.0 }
        return VStack(alignment: .leading, spacing: 10) {
            HBSectionHeader(title: "Debts", action: "Add") { sheet = .debt(nil) }
            VStack(alignment: .leading, spacing: 12) {
                if debts.isEmpty {
                    Text("Track credit cards, car loans, or student loans and see what's left.").font(.footnote).foregroundColor(HB.soft)
                    HBPillButton(title: "Add a debt", symbol: "plus", filled: false) { sheet = .debt(nil) }.accessibilityIdentifier("hb-plan-add-debt")
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(left <= 0 ? "Everything's paid off 🎉" : "\(HBFormat.money(left)) left").font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                        if paid > 0 { Text("\(HBFormat.money(paid)) paid so far").font(.footnote).foregroundColor(HB.soft) }
                    }
                    ForEach(debts) { d in debtRow(d) }
                    if !pays.isEmpty {
                        Divider().background(HB.line)
                        Text("Recent payments").font(.footnote.weight(.semibold)).foregroundColor(HB.soft)
                        ForEach(pays.prefix(5)) { p in paymentRow(p, debts) }
                    }
                }
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading).hbCard()
        }
    }
    private func debtRow(_ d: HBDebt) -> some View {
        HStack(spacing: 12) {
            Button { sheet = .debt(d) } label: {
                HStack(spacing: 12) {
                    HBCircleIcon(symbol: d.paidOff ? "party.popper.fill" : "creditcard.fill", tint: d.paidOff ? HB.green : Color(red: 1, green: 0.55, blue: 0.45), size: 40)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack { Text(d.name).font(.system(size: 16, weight: .semibold)).foregroundColor(.white).lineLimit(1); Spacer(minLength: 4); Text(HBFormat.money(d.remaining)).font(.system(size: 15, weight: .semibold).monospacedDigit()).foregroundColor(.white) }
                        Text(String(format: "%@%% APR · min %@", HBPlanText.percent(d.apr), HBFormat.money(d.minimum))).font(.system(size: 13)).foregroundColor(HB.soft)
                        GeometryReader { g in ZStack(alignment: .leading) { Capsule().fill(Color.black.opacity(0.28)); Capsule().fill(HB.green).frame(width: max(0, g.size.width * CGFloat(d.progress))) } }.frame(height: 7)
                    }
                }.contentShape(Rectangle())
            }
            if !d.paidOff {
                Button { sheet = .pay(d) } label: { Text("Pay").font(.system(size: 14, weight: .bold)).foregroundColor(HB.orange).padding(.horizontal, 14).frame(height: 34).overlay(Capsule().stroke(HB.orange.opacity(0.7), lineWidth: 1)) }
                    .accessibilityLabel("Log a payment on \(d.name)")
            }
        }
    }
    private func paymentRow(_ p: HBDebtPayment, _ debts: [HBDebt]) -> some View {
        let name = debts.first { $0.id == p.debt_id }?.name ?? "a debt"
        return HStack {
            Text("\(store.memberName(p.member_id)) paid \(HBFormat.money(p.amount)) on \(name), \(HBDay.short(p.date))").font(.system(size: 14)).foregroundColor(Color(red: 0.86, green: 0.82, blue: 0.95)).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 6)
            Button { removing = p } label: { Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundColor(HB.soft).frame(width: 30, height: 30) }.accessibilityLabel("Remove payment")
        }
    }
}

// MARK: - month-end forecast card

@available(iOS 15.0, *)
struct HBForecastCard: View {
    let f: HBForecast
    var body: some View {
        let neg = f.endLeft < 0
        VStack(alignment: .leading, spacing: 10) {
            Text("MONTH-END FORECAST").font(.system(size: 12, weight: .bold)).tracking(1.1).foregroundColor(HB.orange)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(neg ? "You're on pace to run" : "You'll end with about").font(.system(size: 17)).foregroundColor(Color(red: 0.86, green: 0.82, blue: 0.95))
                Text(neg ? HBFormat.money(abs(f.endLeft)) + " short" : HBFormat.money(f.endLeft) + " left").font(.system(size: 20, weight: .heavy)).foregroundColor(neg ? HB.red : Color(red: 1, green: 0.83, blue: 0.48)).minimumScaleFactor(0.7).lineLimit(1)
            }
            chart(neg: neg).frame(height: 70)
            HStack {
                Text("Day 1").font(.system(size: 11)).foregroundColor(HB.soft); Spacer()
                Text("today").font(.system(size: 11)).foregroundColor(HB.soft); Spacer()
                Text("Day \(f.dim)").font(.system(size: 11)).foregroundColor(HB.soft)
            }
            VStack(spacing: 6) {
                row("Left right now", HBFormat.money(f.leftNow))
                row("Paychecks still coming", "+" + HBFormat.money(f.pays))
                row("Bills still due", "−" + HBFormat.money(f.bills))
                row("Everyday spending ahead", "−" + HBFormat.money(f.ahead))
            }
            if f.pays == 0 { Text("No paychecks are scheduled. Set your pay as a recurring income for a better guess.").font(.footnote).foregroundColor(HB.soft) }
            ForEach(notes, id: \.self) { n in Text(n).font(.footnote).foregroundColor(Color(red: 0.86, green: 0.82, blue: 0.95)) }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).hbCard()
        .accessibilityIdentifier("hb-plan-forecast")
    }
    private var notes: [String] {
        var out: [String] = []
        if let r = f.risky { out.append("\(HBCatStyle.of(r.category).label) is on pace to hit \(HBFormat.money(r.projected).replacingOccurrences(of: ".00", with: "")) of your \(HBFormat.money(r.limit).replacingOccurrences(of: ".00", with: "")) budget.") }
        if f.daysLeft > 1 { out.append("Cut \(HBFormat.money(f.saveEach).replacingOccurrences(of: ".00", with: "")) a day and you'd end with \(HBFormat.money(f.saveEnd)).") }
        if let p = f.vsLastMonthPct { out.append("Spending is on pace to be \(abs(p))% \(p <= 0 ? "lower" : "higher") than last month.") }
        return out
    }
    private func row(_ l: String, _ v: String) -> some View {
        HStack { Text(l).font(.system(size: 14)).foregroundColor(HB.soft); Spacer(); Text(v).font(.system(size: 14, weight: .semibold).monospacedDigit()).foregroundColor(.white) }
    }
    private func chart(neg: Bool) -> some View {
        GeometryReader { g in chartBody(size: g.size, neg: neg) }
    }
    private func chartBody(size: CGSize, neg: Bool) -> some View {
        let vals = f.points.map { $0.left } + [f.endLeft, 0]
        let lo = vals.min() ?? 0, hi = vals.max() ?? 1, span = max(hi - lo, 0.0001)
        let W = size.width, H = size.height
        let dimSpan = CGFloat(max(1, f.dim - 1))
        func X(_ d: Int) -> CGFloat { CGFloat(d - 1) / dimSpan * W }
        func Y(_ v: Double) -> CGFloat { H - CGFloat((v - lo) / span) * (H - 8) - 4 }
        let col = neg ? HB.red : HB.orange
        let pts: [CGPoint] = f.points.map { CGPoint(x: X($0.day), y: Y($0.left)) }
        let solid = Path { p in
            for (i, q) in pts.enumerated() { if i == 0 { p.move(to: q) } else { p.addLine(to: q) } }
        }
        let tail = Path { p in
            if let last = pts.last { p.move(to: last); p.addLine(to: CGPoint(x: W, y: Y(f.endLeft))) }
        }
        return ZStack {
            solid.stroke(col, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            tail.stroke(col, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [3, 7]))
            if let last = pts.last { Circle().fill(col).frame(width: 9, height: 9).position(x: last.x, y: last.y) }
        }
    }
}
