import SwiftUI
import UIKit

// MARK: - Stats: bunny level & badges, 50/30/20, the year (earned vs spent by month), where it went, the monthly recap card, CSV export.
// The website's Stats screen. The year comes from /api/year, everything else from the month already loaded.

@available(iOS 15.0, *)
struct HBStatsView: View {
    @ObservedObject var store: HBAppStore
    @Environment(\.dismiss) private var dismiss
    @State private var year = Int(HBDay.monthKey().prefix(4)) ?? 2026
    @State private var data: HBYearData?
    @State private var loading = false
    @State private var error: String?
    @State private var whereYear = false
    @State private var showBadges = false
    @State private var showRecap = false
    @State private var csvURL: URL?
    @State private var showShare = false

    private var me: HBMember? { store.members.first { $0.id == store.myID } }
    private var yearTotals: HBYearTotals? { data.map(HBStats.year) }

    var body: some View {
        HBSheetScaffold(title: "Stats", onBack: { dismiss() }) {
            if let m = me, let s = store.snapshot { burrowCard(m, s) }
            if let s = store.snapshot { ruleCard(s) }
            hopCard
            yearCard
            whereCard
            VStack(spacing: 10) {
                HBPillButton(title: "Make my monthly recap", symbol: "sparkles") { showRecap = true }.accessibilityIdentifier("hb-stats-recap")
                HBPillButton(title: "Export \(year) spreadsheet (CSV)", symbol: "square.and.arrow.up", filled: false) { exportCSV() }.disabled(data == nil).accessibilityIdentifier("hb-stats-csv")
            }
            if let e = error { Text(e).font(.footnote).foregroundColor(HB.red) }
        }
        .task(id: year) { await load() }
        .sheet(isPresented: $showBadges) { if let m = me, let s = store.snapshot { HBBadgesSheet(member: m, snapshot: s, months: yearTotals?.monthsWithEntries) } }
        .sheet(isPresented: $showRecap) { HBRecapSheet(store: store) }
        .sheet(isPresented: $showShare) { if let u = csvURL { HBActivityView(items: [u]) } }
    }

    private func load() async {
        if store.isPreview { data = HBStatsView.previewYear(store); return }
        loading = true; error = nil; data = nil
        do { data = try await HBAPI.shared.year(year) } catch { self.error = error.localizedDescription }
        loading = false
    }
    private func exportCSV() {
        guard let d = data else { return }
        let text = HBStats.csv(d, memberName: { store.memberName($0) }, categoryName: { HBCatStyle.of($0).label })
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("honeybun-\(year).csv")
        do { try text.write(to: url, atomically: true, encoding: .utf8); csvURL = url; showShare = true } catch { self.error = "Couldn't make the file." }
    }

    // MARK: bunny level, streak, badges

    private func burrowCard(_ m: HBMember, _ s: HBNestSnapshot) -> some View {
        let li = HBProgress.levelInfo(m.xp ?? 0), streak = HBProgress.streak(m)
        let badges = HBProgress.badges(m, s, monthsWithEntries: yearTotals?.monthsWithEntries)
        let got = badges.filter { $0.unlocked }.count
        let carrots = store.members.count > 1 ? store.members.map { "\($0.name) \(HBProgress.weekXP($0)) 🥕" }.joined(separator: " · ") : "\(m.xp ?? 0) carrots"
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                if let mm = store.member(store.myID) { HBMemberAvatar(member: mm, size: 52) }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Level \(li.level) · \(li.title)").font(.system(size: 18, weight: .bold)).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.8)
                    GeometryReader { g in ZStack(alignment: .leading) { Capsule().fill(Color.black.opacity(0.28)); Capsule().fill(HB.orange).frame(width: max(8, g.size.width * CGFloat(li.pct))) } }.frame(height: 8)
                    Text("🐾 \(streak)-day streak · \(carrots)").font(.system(size: 12)).foregroundColor(HB.soft).lineLimit(2)
                }
            }
            Button { showBadges = true } label: {
                HStack { Text("🏅 \(got) of \(badges.count) badges").font(.system(size: 15, weight: .semibold)); Spacer(); Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)) }
                    .foregroundColor(HB.orange).padding(.top, 2)
            }.accessibilityIdentifier("hb-stats-badges")
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).hbCard()
    }

    // MARK: hop calendar

    @State private var hopSel: String?
    private var hopCard: some View {
        let cal = store.snapshot.flatMap { HBStats.hopCalendar($0.entries, month: store.month) }
        return VStack(alignment: .leading, spacing: 10) {
            HBSectionHeader(title: "Hop calendar")
            if let cal = cal {
                VStack(spacing: 8) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                        ForEach(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], id: \.self) { Text($0).font(.system(size: 11, weight: .semibold)).foregroundColor(HB.soft) }
                        ForEach(0..<cal.lead, id: \.self) { _ in Color.clear.frame(height: 46) }
                        ForEach(cal.days) { d in hopCell(d) }
                    }
                    hopDetail(cal)
                    HStack {
                        hopSummary(String(cal.noSpendDays), "no-spend days")
                        hopSummary(calmestText(cal), "calmest week")
                        hopSummary(biggestText(cal), biggestLabel(cal))
                    }
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading).hbCard()
            }
        }
    }
    private func dayString(_ n: Int) -> String { String(format: "%@-%02d", store.month, n) }
    private func calmestText(_ cal: HBStats.HopCalendar) -> String {
        guard let c = cal.calmest else { return "–" }
        return HBDay.short(dayString(c.from)) + "–" + String(c.to)
    }
    private func biggestText(_ cal: HBStats.HopCalendar) -> String {
        guard let b = cal.biggest else { return "–" }
        return HBFormat.money(b.amount).replacingOccurrences(of: ".00", with: "")
    }
    private func biggestLabel(_ cal: HBStats.HopCalendar) -> String {
        guard let b = cal.biggest else { return "biggest day" }
        return "biggest day, " + HBDay.short(dayString(b.day))
    }
    private func hopCell(_ d: HBStats.HopDay) -> some View {
        let tappable = d.done || d.spend > 0
        return Button { hopSel = hopSel == d.date ? nil : d.date } label: {
            VStack(spacing: 2) {
                Text("\(d.day)").font(.system(size: 12, weight: d.isToday ? .heavy : .medium)).foregroundColor(d.isToday ? HB.orange : .white.opacity(d.done || d.spend > 0 ? 1 : 0.4))
                if d.noSpend { Image(systemName: "pawprint.fill").font(.system(size: 11)).foregroundColor(HB.green) }
                else if d.spend > 0 {
                    Circle().fill(HB.orange.opacity(0.55 + d.rank * 0.45)).frame(width: 8 + CGFloat(d.rank) * 12, height: 8 + CGFloat(d.rank) * 12)
                    Text(HBFormat.money(d.spend).replacingOccurrences(of: ".00", with: "").components(separatedBy: ".").first ?? "").font(.system(size: 8, weight: .semibold)).foregroundColor(HB.soft).lineLimit(1).minimumScaleFactor(0.6)
                } else { Spacer(minLength: 0) }
            }
            .frame(maxWidth: .infinity, minHeight: 46)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(hopSel == d.date ? HB.orange.opacity(0.2) : Color.white.opacity(0.04)))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(d.isToday ? HB.orange.opacity(0.8) : Color.clear, lineWidth: 1))
        }.disabled(!tappable)
    }
    private func hopDetailText(_ sel: String, _ spend: Double) -> String {
        let list = (store.snapshot?.entries ?? []).filter { $0.date == sel && !$0.isIncome }
        let day = HBDay.short(sel)
        if list.isEmpty { return day + ": no spending 🐾" }
        let names = list.prefix(3).map { $0.label }.joined(separator: ", ")
        let more = list.count > 3 ? " +" + String(list.count - 3) : ""
        return day + ": " + names + more + " · " + HBFormat.money(spend)
    }
    @ViewBuilder private func hopDetail(_ cal: HBStats.HopCalendar) -> some View {
        if let sel = hopSel, let d = cal.days.first(where: { $0.date == sel }) {
            Text(hopDetailText(sel, d.spend))
                .font(.footnote).foregroundColor(Color(red: 0.86, green: 0.82, blue: 0.95)).frame(maxWidth: .infinity, alignment: .leading)
        } else { Text("Tap a day to see what you spent. A paw means a no-spend day.").font(.footnote).foregroundColor(HB.soft).frame(maxWidth: .infinity, alignment: .leading) }
    }
    private func hopSummary(_ big: String, _ small: String) -> some View {
        VStack(spacing: 2) { Text(big).font(.system(size: 17, weight: .bold).monospacedDigit()).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.6); Text(small).font(.system(size: 11)).foregroundColor(HB.soft).lineLimit(2).multilineTextAlignment(.center) }.frame(maxWidth: .infinity)
    }

    // MARK: 50 / 30 / 20

    private func ruleCard(_ s: HBNestSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let r = HBStats.rule(s) {
                HStack { Text("50 / 30 / 20").font(.system(size: 18, weight: .bold)).foregroundColor(.white); Spacer(); Text(r.verdict).font(.system(size: 14, weight: .semibold)).foregroundColor(r.ok ? HB.green : HB.orange) }
                GeometryReader { g in
                    HStack(spacing: 0) {
                        Rectangle().fill(Color(red: 0.61, green: 0.72, blue: 1)).frame(width: g.size.width * CGFloat(min(100, r.needs)) / 100)
                        Rectangle().fill(Color(red: 1, green: 0.5, blue: 0.64)).frame(width: g.size.width * CGFloat(min(100, r.wants)) / 100)
                        Rectangle().fill(HB.green).frame(width: g.size.width * CGFloat(min(100, r.saved)) / 100)
                        Spacer(minLength: 0)
                    }.clipShape(Capsule()).background(Capsule().fill(Color.black.opacity(0.28)))
                }.frame(height: 12)
                HStack { Text("Needs \(r.needs)%"); Spacer(); Text("Wants \(r.wants)%"); Spacer(); Text("Saved \(r.saved)%") }.font(.system(size: 13)).foregroundColor(HB.soft)
            } else {
                Text("Add this month's income to see your 50 / 30 / 20 split.").font(.footnote).foregroundColor(HB.soft)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).hbCard()
    }

    // MARK: the year

    private var yearCard: some View {
        let t = yearTotals
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your year").font(.system(size: 21, weight: .bold)).foregroundColor(.white)
                Spacer()
                Button { year -= 1 } label: { Image(systemName: "chevron.left").frame(width: 34, height: 34) }.accessibilityLabel("Previous year")
                Text(String(year)).font(.system(size: 16, weight: .semibold).monospacedDigit()).foregroundColor(HB.soft)
                Button { year += 1 } label: { Image(systemName: "chevron.right").frame(width: 34, height: 34) }.accessibilityLabel("Next year")
            }.foregroundColor(.white)
            VStack(spacing: 12) {
                HStack {
                    totalItem("Earned", HBFormat.money(t?.totalIn ?? 0), HB.green)
                    totalItem("Spent", HBFormat.money(t?.totalOut ?? 0), Color(red: 1, green: 0.5, blue: 0.64))
                    totalItem("Kept", t?.keptPct.map { "\($0)%" } ?? "–", HB.orange)
                }
                if let t = t { yearChart(t).frame(height: 150) } else if loading { ProgressView().tint(HB.orange).frame(height: 150).frame(maxWidth: .infinity) }
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading).hbCard()
        }
    }
    private func totalItem(_ title: String, _ value: String, _ tint: Color) -> some View {
        VStack(spacing: 2) { Text(value).font(.system(size: 18, weight: .bold).monospacedDigit()).foregroundColor(.white).minimumScaleFactor(0.6).lineLimit(1); Text(title).font(.system(size: 12, weight: .semibold)).foregroundColor(tint) }.frame(maxWidth: .infinity)
    }
    private func yearChart(_ t: HBYearTotals) -> some View {
        let top = max(1, (t.income + t.spent).max() ?? 1)
        let letters = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]
        return HStack(alignment: .bottom, spacing: 4) {
            ForEach(0..<12, id: \.self) { i in
                VStack(spacing: 4) {
                    HStack(alignment: .bottom, spacing: 2) {
                        RoundedRectangle(cornerRadius: 3).fill(HB.green).frame(width: 8, height: max(2, CGFloat(t.income[i] / top) * 118)).opacity(t.income[i] > 0 ? 1 : 0.25)
                        RoundedRectangle(cornerRadius: 3).fill(Color(red: 1, green: 0.5, blue: 0.64)).frame(width: 8, height: max(2, CGFloat(t.spent[i] / top) * 118)).opacity(t.spent[i] > 0 ? 1 : 0.25)
                    }.frame(height: 120, alignment: .bottom)
                    Text(letters[i]).font(.system(size: 10, weight: .bold)).foregroundColor(HB.soft)
                }.frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(letters[i]): earned \(HBFormat.money(t.income[i])), spent \(HBFormat.money(t.spent[i]))")
            }
        }
    }

    // MARK: where it went (this month / this year)

    private var whereCard: some View {
        let monthData = store.snapshot.map { HBPlan.spentByCategory($0.entries) } ?? [:]
        let src = whereYear ? (yearTotals?.byCategory ?? [:]) : monthData
        let w = HBStats.whereItWent(src)
        let total = src.values.reduce(0, +)
        let mx = max(1, w.rows.map { $0.amount }.max() ?? 1, w.rest)
        return VStack(alignment: .leading, spacing: 10) {
            HBSectionHeader(title: "Where it went")
            Picker("", selection: $whereYear) { Text(HBDay.monthName(store.month)).tag(false); Text(String(year)).tag(true) }.pickerStyle(.segmented)
            VStack(alignment: .leading, spacing: 12) {
                if total > 0 { Text("\(HBFormat.money(total)) · \(whereYear ? String(year) : HBDay.monthName(store.month))").font(.footnote).foregroundColor(HB.soft) }
                if w.rows.isEmpty { Text(whereYear && data == nil ? "Loading…" : "No spending yet.").font(.footnote).foregroundColor(HB.soft) }
                ForEach(w.rows, id: \.id) { r in bar(HBCatStyle.of(r.id).label, r.amount, mx) }
                if w.rest > 0 { bar("Everything else", w.rest, mx) }
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading).hbCard()
        }
    }
    private func bar(_ name: String, _ amount: Double, _ mx: Double) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack { Text(name).font(.system(size: 15)).foregroundColor(.white).lineLimit(1); Spacer(); Text(HBFormat.money(amount)).font(.system(size: 15, weight: .semibold).monospacedDigit()).foregroundColor(.white) }
            GeometryReader { g in ZStack(alignment: .leading) { Capsule().fill(Color.black.opacity(0.28)); Capsule().fill(HB.orange).frame(width: max(6, g.size.width * CGFloat(amount / mx))) } }.frame(height: 8)
        }
    }

    #if DEBUG
    static func previewYear(_ store: HBAppStore) -> HBYearData {
        // sample: this month's entries spread over a few months, for screenshots/tests only
        let src = store.snapshot?.entries ?? []
        var out: [HBYearEntry] = []
        for (i, e) in src.enumerated() {
            let month = 1 + (i % 9)
            let date = String(format: "%@-%02d-%@", String(HBDay.monthKey().prefix(4)), month, String(e.date.suffix(2)))
            if let d = try? JSONDecoder().decode(HBYearEntry.self, from: JSONSerialization.data(withJSONObject: ["type": e.type, "amount_cents": e.amount_cents, "category": e.category as Any, "label": e.label, "member_id": e.member_id, "date": date, "shared": 0, "private": 0])) { out.append(d) }
        }
        return HBYearData(entries: out)
    }
    #else
    static func previewYear(_ store: HBAppStore) -> HBYearData { HBYearData(entries: []) }
    #endif
}

// MARK: - badges

@available(iOS 15.0, *)
struct HBBadgesSheet: View {
    let member: HBMember
    let snapshot: HBNestSnapshot
    let months: Int?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        let list = HBProgress.badges(member, snapshot, monthsWithEntries: months)
        HBSheetScaffold(title: "Badges", onBack: { dismiss() }) {
            Text("\(list.filter { $0.unlocked }.count) of \(list.count) earned").font(.footnote).foregroundColor(HB.soft)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(list) { b in
                    VStack(spacing: 6) {
                        Text(b.unlocked ? b.emoji : "🔒").font(.system(size: 30))
                        Text(b.name).font(.system(size: 14, weight: .bold)).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.8)
                        Text(b.unlocked ? "earned" : b.hint).font(.system(size: 11)).foregroundColor(b.unlocked ? HB.green : HB.soft).multilineTextAlignment(.center).lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, minHeight: 110).padding(10)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(b.unlocked ? 0.09 : 0.04)))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(b.unlocked ? HB.orange.opacity(0.5) : Color.clear, lineWidth: 1))
                    .opacity(b.unlocked ? 1 : 0.7)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

// MARK: - monthly recap (a card to share)

@available(iOS 15.0, *)
struct HBRecapSheet: View {
    @ObservedObject var store: HBAppStore
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var showShare = false
    private var recap: HBRecap? { store.snapshot.map { HBStats.recap($0, month: store.month, me: store.members.first { $0.id == store.myID }) } }
    private var accent: Color {
        switch store.snapshot?.nest.accent ?? "blueberry" { case "blush": return Color(red: 0.93, green: 0.50, blue: 0.64); case "lavender": return Color(red: 0.61, green: 0.51, blue: 0.86); case "honey": return Color(red: 0.87, green: 0.63, blue: 0.25); default: return Color(red: 0.44, green: 0.58, blue: 0.86) }
    }
    var body: some View {
        HBSheetScaffold(title: HBDay.monthName(store.month), onBack: { dismiss() }) {
            if let r = recap {
                HBRecapCard(recap: r, accent: accent, monthTitle: HBDay.monthName(store.month)).frame(width: 1080, height: 1350)
                    .scaleEffect(0.3, anchor: .topLeading).frame(width: 324, height: 405, alignment: .topLeading).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)).frame(maxWidth: .infinity)
                HBPillButton(title: "Share my recap", symbol: "square.and.arrow.up") { share(r) }.accessibilityIdentifier("hb-recap-share")
            }
        }
        .sheet(isPresented: $showShare) { if let i = image { HBActivityView(items: [i]) } }
    }
    private func share(_ r: HBRecap) {
        image = HBImage.render(HBRecapCard(recap: r, accent: accent, monthTitle: HBDay.monthName(store.month)), size: CGSize(width: 1080, height: 1350))
        if image != nil { showShare = true }
    }
}

/// The share card. Light, like the website's recap picture (it is meant to look the same wherever it is posted).
@available(iOS 15.0, *)
struct HBRecapCard: View {
    let recap: HBRecap
    let accent: Color
    let monthTitle: String
    private let ink = Color(red: 0.17, green: 0.15, blue: 0.20), soft = Color(red: 0.56, green: 0.53, blue: 0.60)
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(red: 0.95, green: 0.96, blue: 0.98)
            Circle().fill(accent.opacity(0.12)).frame(width: 520, height: 520).offset(x: 620, y: -170)
            Circle().fill(accent.opacity(0.12)).frame(width: 400, height: 400).offset(x: -140, y: 1000)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 30) {
                    Image("HBHero").resizable().scaledToFit().frame(width: 150, height: 150)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Honeybun").font(.system(size: 34, weight: .semibold, design: .rounded)).foregroundColor(soft)
                        Text(monthTitle).font(.system(size: 58, weight: .semibold, design: .rounded)).foregroundColor(ink)
                    }
                }.padding(.top, 80)
                big.padding(.top, 50)
                LazyVGrid(columns: [GridItem(.fixed(450), spacing: 20), GridItem(.fixed(450), spacing: 20)], spacing: 30) {
                    tile("🐾", "Hop streak", "\(recap.streak) · best \(recap.bestStreak)")
                    tile("🥕", "Level", "\(recap.level) · \(recap.levelTitle)")
                    tile(recap.topCategory.map { HBCatStyle.of($0.id).emoji ?? "✨" } ?? "✨", "Top spend", recap.topCategory.map { "\(HBCatStyle.of($0.id).label) \(HBFormat.money($0.amount))" } ?? "–")
                    tile("🎯", "Budgets kept", recap.budgetsTotal > 0 ? "\(recap.budgetsKept) / \(recap.budgetsTotal)" : "–")
                }.padding(.top, 40)
                Spacer(minLength: 0)
                Text(recap.message).font(.system(size: 40, weight: .semibold, design: .rounded)).foregroundColor(ink).multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.7).frame(maxWidth: .infinity)
                Text("A cute little budget · honeybun.me").font(.system(size: 34, weight: .semibold, design: .rounded)).foregroundColor(soft).frame(maxWidth: .infinity).padding(.top, 50).padding(.bottom, 70)
            }.padding(.horizontal, 80)
        }
        .frame(width: 1080, height: 1350)
    }
    private var big: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(recap.keptPct == nil ? "Spent this month" : "You kept").font(.system(size: 36, weight: .semibold, design: .rounded)).foregroundColor(soft)
            Text(recap.keptPct.map { "\($0)%" } ?? HBFormat.money(recap.spent)).font(.system(size: 150, weight: .semibold, design: .rounded)).foregroundColor((recap.keptPct ?? 0) < 0 ? Color(red: 0.85, green: 0.4, blue: 0.55) : accent).minimumScaleFactor(0.6).lineLimit(1)
            if recap.keptPct != nil { Text("Earned \(HBFormat.money(recap.income))  ·  Spent \(HBFormat.money(recap.spent))").font(.system(size: 32, weight: .semibold, design: .rounded)).foregroundColor(soft) }
        }
        .padding(50).frame(width: 920, alignment: .leading).background(RoundedRectangle(cornerRadius: 44, style: .continuous).fill(Color.white))
    }
    private func tile(_ emoji: String, _ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(emoji).font(.system(size: 56))
            Text(title).font(.system(size: 30, weight: .semibold, design: .rounded)).foregroundColor(soft)
            Text(value).font(.system(size: 36, weight: .semibold, design: .rounded)).foregroundColor(ink).lineLimit(1).minimumScaleFactor(0.6)
        }
        .padding(34).frame(width: 450, height: 200, alignment: .leading).background(RoundedRectangle(cornerRadius: 38, style: .continuous).fill(Color.white))
    }
}

/// turns a SwiftUI view into a picture (for sharing)
@available(iOS 15.0, *)
@MainActor enum HBImage {
    static func render<V: View>(_ view: V, size: CGSize) -> UIImage? {
        if #available(iOS 16.0, *) {
            let r = ImageRenderer(content: view.frame(width: size.width, height: size.height))
            r.scale = 1
            return r.uiImage
        }
        let host = UIHostingController(rootView: view.frame(width: size.width, height: size.height))
        host.view.frame = CGRect(origin: .zero, size: size)
        host.view.backgroundColor = .clear
        let win = UIWindow(frame: CGRect(origin: .zero, size: size))
        win.rootViewController = host; win.isHidden = false
        host.view.layoutIfNeeded()
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1
        return UIGraphicsImageRenderer(size: size, format: fmt).image { _ in host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true) }
    }
}
