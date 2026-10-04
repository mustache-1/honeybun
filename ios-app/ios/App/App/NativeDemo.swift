import SwiftUI
import UIKit

// A hands-on SwiftUI preview of Honeybun. It runs on sample data only (nothing is saved or sent), so you can
// tap around, add spending, mark bills paid and swipe things away to feel what a fully native version would be like.
// Opened from Settings > "Native preview" inside the iPhone app.

@available(iOS 15.0, *)
enum DemoStyle {
    static let top = Color(red: 0.086, green: 0.055, blue: 0.125)
    static let bottom = Color(red: 0.24, green: 0.11, blue: 0.30)
    static let card = Color(red: 0.118, green: 0.098, blue: 0.145)
    static let orange = Color(red: 0.96, green: 0.60, blue: 0.29)
    static let green = Color(red: 0.45, green: 0.85, blue: 0.55)
    static let soft = Color.white.opacity(0.62)
    static let line = Color.white.opacity(0.09)
}

struct DemoBill: Identifiable {
    let id = UUID()
    var name: String
    var day: Int
    var amount: Double
    var paid = false
}

struct DemoEntry: Identifiable {
    let id = UUID()
    var label: String
    var amount: Double
    var category: String
    var day: Int
}

func demoMoney(_ value: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.currencySymbol = "$"
    f.minimumFractionDigits = 2
    f.maximumFractionDigits = 2
    return f.string(from: NSNumber(value: value)) ?? "$0.00"
}

func demoTap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
    UIImpactFeedbackGenerator(style: style).impactOccurred()
}

@available(iOS 15.0, *)
final class DemoStore: ObservableObject {
    @Published var bills: [DemoBill] = [
        DemoBill(name: "Netflix", day: 2, amount: 17.99),
        DemoBill(name: "Spotify", day: 16, amount: 11.99),
        DemoBill(name: "Phone", day: 20, amount: 45.00),
        DemoBill(name: "Rent", day: 28, amount: 1100.00)
    ]
    @Published var entries: [DemoEntry] = [
        DemoEntry(label: "Lunch", amount: 36.00, category: "☕️", day: 13),
        DemoEntry(label: "Sushi", amount: 52.00, category: "🍣", day: 11),
        DemoEntry(label: "Tacos", amount: 48.00, category: "🌮", day: 8),
        DemoEntry(label: "Groceries", amount: 64.00, category: "🛒", day: 5)
    ]
    @Published var tipIndex = 0
    let carried = 3657.50
    let came = 2600.0
    let tips = [
        "Eating out is $88 over budget. No stress, next month is a fresh start.",
        "You have 2 no-spend days this month. Keep hopping! 🐾",
        "Netflix went up from $15.49 to $17.99. Still worth it?",
        "Paying bills the day they are due keeps your month calm."
    ]

    var spent: Double { entries.reduce(0) { $0 + $1.amount } }
    var billsDue: Double { bills.filter { !$0.paid }.reduce(0) { $0 + $1.amount } }
    var left: Double { carried + came - spent }
    var thisMonth: Double { came - spent }

    func pay(_ bill: DemoBill) {
        guard let i = bills.firstIndex(where: { $0.id == bill.id }) else { return }
        bills[i].paid = true
        entries.insert(DemoEntry(label: bill.name, amount: bill.amount, category: "🧾", day: 4), at: 0)
    }

    func add(label: String, amount: Double, category: String) {
        entries.insert(DemoEntry(label: label.isEmpty ? "Spending" : label, amount: amount, category: category, day: 4), at: 0)
    }

    func nextTip() { tipIndex = (tipIndex + 1) % tips.count }
}

enum DemoTab { case home, plan, stats, together }

@available(iOS 15.0, *)
struct DemoRoot: View {
    let onClose: () -> Void
    @StateObject private var store = DemoStore()
    @State private var tab: DemoTab = .home
    @State private var adding = false

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [DemoStyle.top, DemoStyle.bottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            content
            DemoTabBar(tab: $tab, onAdd: { adding = true })
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $adding) { DemoAdd(store: store) }
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .home: DemoHome(store: store, onClose: onClose)
        case .plan: DemoPlan(store: store, onClose: onClose)
        case .stats: DemoStats(store: store, onClose: onClose)
        case .together: DemoTogether(store: store, onClose: onClose)
        }
    }
}

@available(iOS 15.0, *)
struct DemoTabBar: View {
    @Binding var tab: DemoTab
    let onAdd: () -> Void

    var body: some View {
        HStack {
            item("house.fill", "Home", .home)
            item("calendar", "Plan", .plan)
            Button(action: { demoTap(.medium); onAdd() }) {
                VStack(spacing: 3) {
                    Image(systemName: "plus.circle.fill").font(.system(size: 30))
                    Text("Add").font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(DemoStyle.orange)
                .frame(maxWidth: .infinity)
            }
            item("chart.bar.fill", "Stats", .stats)
            item("heart.fill", "Together", .together)
        }
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Color(red: 0.08, green: 0.06, blue: 0.11).opacity(0.96).ignoresSafeArea(edges: .bottom))
        .overlay(Rectangle().fill(DemoStyle.line).frame(height: 1), alignment: .top)
    }

    private func item(_ symbol: String, _ label: String, _ value: DemoTab) -> some View {
        Button(action: { demoTap(); withAnimation(.easeInOut(duration: 0.18)) { tab = value } }) {
            VStack(spacing: 3) {
                Image(systemName: symbol).font(.system(size: 21, weight: .semibold))
                Text(label).font(.system(size: 11, weight: .bold))
            }
            .foregroundColor(tab == value ? DemoStyle.orange : Color.white.opacity(0.55))
            .frame(maxWidth: .infinity)
        }
    }
}

@available(iOS 15.0, *)
struct DemoHeader: View {
    let title: String
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                Text("SwiftUI preview").font(.system(size: 12, weight: .bold)).foregroundColor(DemoStyle.orange)
                Text(title).font(.system(size: 28, weight: .bold, design: .rounded)).foregroundColor(.white)
            }
            Spacer()
            Button(action: { demoTap(); onClose() }) {
                Text("Close")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
            }
        }
    }
}

@available(iOS 15.0, *)
struct DemoCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 24).fill(DemoStyle.card))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(DemoStyle.line, lineWidth: 1))
    }
}

@available(iOS 15.0, *)
struct DemoStat: View {
    let title: String
    let value: String
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 13, weight: .semibold)).foregroundColor(DemoStyle.soft)
            Text(value).font(.system(size: 17, weight: .bold, design: .rounded)).foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@available(iOS 15.0, *)
struct DemoHome: View {
    @ObservedObject var store: DemoStore
    let onClose: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                DemoHeader(title: "Home", onClose: onClose).padding(.top, 8)
                hero
                tipCard
                comingUp
                Spacer().frame(height: 90)
            }
            .padding(.horizontal, 16)
        }
        .refreshable {
            demoTap()
            try? await Task.sleep(nanoseconds: 700_000_000)
        }
    }

    private var progress: CGFloat {
        let total = store.came + store.carried
        return CGFloat(min(1, max(0, store.spent / total)))
    }

    private var hero: some View {
        DemoCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Left in October").font(.system(size: 16, weight: .semibold)).foregroundColor(DemoStyle.soft)
                    Spacer()
                    Text(store.left > 0 ? "On track" : "Over budget")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(store.left > 0 ? DemoStyle.green : DemoStyle.orange)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill((store.left > 0 ? DemoStyle.green : DemoStyle.orange).opacity(0.16)))
                }
                Text(demoMoney(store.left))
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text("Carried over from September").foregroundColor(DemoStyle.soft)
                    Text("+" + demoMoney(store.carried)).foregroundColor(DemoStyle.green)
                }
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                HStack(spacing: 8) {
                    Text("This month").foregroundColor(DemoStyle.soft)
                    Text((store.thisMonth >= 0 ? "+" : "-") + demoMoney(abs(store.thisMonth)))
                        .foregroundColor(store.thisMonth >= 0 ? DemoStyle.green : Color.red)
                }
                .font(.system(size: 13, weight: .semibold))
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.black.opacity(0.45))
                        Capsule().fill(DemoStyle.orange).frame(width: g.size.width * progress)
                            .animation(.easeInOut(duration: 0.35), value: progress)
                    }
                }
                .frame(height: 9)
                HStack {
                    DemoStat(title: "Came in", value: demoMoney(store.came), color: DemoStyle.green)
                    DemoStat(title: "Spent", value: demoMoney(store.spent), color: .white)
                    DemoStat(title: "Bills due", value: demoMoney(store.billsDue), color: .white)
                }
            }
        }
    }

    private var tipCard: some View {
        Button(action: { demoTap(); withAnimation { store.nextTip() } }) {
            HStack(alignment: .top, spacing: 12) {
                Text("🐰").font(.system(size: 26)).frame(width: 50, height: 50)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
                VStack(alignment: .leading, spacing: 4) {
                    Text("BUN'S TIP · tap for another").font(.system(size: 12, weight: .heavy))
                        .foregroundColor(Color(red: 0.75, green: 0.62, blue: 1.0))
                    Text(store.tips[store.tipIndex])
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 24).fill(Color(red: 0.19, green: 0.14, blue: 0.27)))
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var comingUp: some View {
        DemoCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Coming up").font(.system(size: 20, weight: .bold)).foregroundColor(.white)
                    Spacer()
                    Text("next 30 days").font(.system(size: 13, weight: .semibold)).foregroundColor(DemoStyle.soft)
                }
                ForEach(store.bills.filter { !$0.paid }) { bill in
                    DemoBillRow(bill: bill) {
                        demoTap(.medium)
                        withAnimation(.easeInOut(duration: 0.3)) { store.pay(bill) }
                    }
                }
                if store.bills.allSatisfy({ $0.paid }) {
                    Text("All paid! 🎉").font(.system(size: 16, weight: .bold)).foregroundColor(DemoStyle.green)
                }
            }
        }
    }
}

@available(iOS 15.0, *)
struct DemoBillRow: View {
    let bill: DemoBill
    let onPaid: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 18))
                .foregroundColor(Color(red: 0.7, green: 0.6, blue: 1.0))
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.07)))
            VStack(alignment: .leading, spacing: 2) {
                Text(bill.name).font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                Text(bill.day < 4 ? "Overdue, was due Oct \(bill.day)" : "Due Oct \(bill.day)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(bill.day < 4 ? DemoStyle.orange : DemoStyle.soft)
            }
            Spacer()
            Text(demoMoney(bill.amount)).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.white)
            Button(action: onPaid) {
                Text("Paid").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(Capsule().fill(Color.white.opacity(0.1)))
            }
        }
    }
}

@available(iOS 15.0, *)
struct DemoAdd: View {
    @ObservedObject var store: DemoStore
    @Environment(\.presentationMode) private var presentation
    @State private var amount = ""
    @State private var note = ""
    @State private var category = "🛒"
    private let cats = ["🛒", "☕️", "🍣", "🌮", "⛽️", "🎁", "🐶", "🏠"]

    var body: some View {
        ZStack {
            LinearGradient(colors: [DemoStyle.top, DemoStyle.bottom], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Add spending").font(.system(size: 24, weight: .bold, design: .rounded)).foregroundColor(.white)
                    Spacer()
                    Button("Cancel") { presentation.wrappedValue.dismiss() }.foregroundColor(DemoStyle.orange)
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("$").font(.system(size: 34, weight: .bold)).foregroundColor(DemoStyle.soft)
                    TextField("0", text: $amount)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                Text("What for?").font(.system(size: 14, weight: .bold)).foregroundColor(DemoStyle.soft)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(cats, id: \.self) { c in
                            Button(action: { demoTap(); category = c }) {
                                Text(c).font(.system(size: 28)).frame(width: 58, height: 58)
                                    .background(RoundedRectangle(cornerRadius: 18).fill(category == c ? DemoStyle.orange.opacity(0.35) : DemoStyle.card))
                                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(category == c ? DemoStyle.orange : DemoStyle.line, lineWidth: 2))
                            }
                        }
                    }
                }
                TextField("Note (optional)", text: $note)
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 16).fill(DemoStyle.card))
                    .foregroundColor(.white)
                Spacer()
                Button(action: save) {
                    Text("Add it")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(red: 0.16, green: 0.1, blue: 0.05))
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(Capsule().fill(DemoStyle.orange))
                }
            }
            .padding(20)
        }
        .preferredColorScheme(.dark)
    }

    private func save() {
        let value = Double(amount.replacingOccurrences(of: ",", with: ".")) ?? 0
        guard value > 0 else { demoTap(.heavy); return }
        demoTap(.medium)
        store.add(label: note, amount: value, category: category)
        presentation.wrappedValue.dismiss()
    }
}

@available(iOS 15.0, *)
struct DemoTogether: View {
    @ObservedObject var store: DemoStore
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DemoHeader(title: "Together", onClose: onClose).padding(.top, 8).padding(.horizontal, 16)
            Text("Swipe a row left to delete it").font(.system(size: 13, weight: .semibold)).foregroundColor(DemoStyle.soft).padding(.horizontal, 16)
            List {
                ForEach(store.entries) { e in
                    HStack(spacing: 12) {
                        Text(e.category).font(.system(size: 24)).frame(width: 44, height: 44)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.07)))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(e.label).font(.system(size: 17, weight: .bold)).foregroundColor(.white)
                            Text("Me, Oct \(e.day), joint account").font(.system(size: 13, weight: .semibold)).foregroundColor(DemoStyle.soft)
                        }
                        Spacer()
                        Text("-" + demoMoney(e.amount)).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(.white)
                    }
                    .listRowBackground(DemoStyle.card)
                }
                .onDelete { offsets in
                    demoTap(.medium)
                    withAnimation { store.entries.remove(atOffsets: offsets) }
                }
            }
            .listStyle(.plain)
            .onAppear { UITableView.appearance().backgroundColor = .clear }
            Spacer().frame(height: 70)
        }
    }
}

@available(iOS 15.0, *)
struct DemoPlan: View {
    @ObservedObject var store: DemoStore
    let onClose: () -> Void
    @State private var picked = 4
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                DemoHeader(title: "Plan", onClose: onClose).padding(.top, 8)
                DemoCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("October 2026").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                        LazyVGrid(columns: columns, spacing: 6) {
                            ForEach(1...31, id: \.self) { d in dayCell(d) }
                        }
                        Text("Tap a day to see what's due. Pink dots are bills.").font(.system(size: 13, weight: .semibold)).foregroundColor(DemoStyle.soft)
                    }
                }
                DemoCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Oct \(picked)").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                        let due = store.bills.filter { $0.day == picked }
                        if due.isEmpty {
                            Text("Nothing due this day 🐾").font(.system(size: 15, weight: .semibold)).foregroundColor(DemoStyle.soft)
                        }
                        ForEach(due) { b in
                            HStack {
                                Text(b.name).font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                                Spacer()
                                Text(demoMoney(b.amount)).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundColor(b.paid ? DemoStyle.green : .white)
                            }
                        }
                    }
                }
                Spacer().frame(height: 90)
            }
            .padding(.horizontal, 16)
        }
    }

    private func dayCell(_ d: Int) -> some View {
        let hasBill = store.bills.contains { $0.day == d && !$0.paid }
        let on = d == picked
        return Button(action: { demoTap(); withAnimation(.easeInOut(duration: 0.15)) { picked = d } }) {
            VStack(spacing: 2) {
                Text("\(d)").font(.system(size: 14, weight: .bold)).foregroundColor(on ? Color.black : .white)
                Circle().fill(hasBill ? Color(red: 0.93, green: 0.55, blue: 0.67) : Color.clear).frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity).frame(height: 40)
            .background(RoundedRectangle(cornerRadius: 12).fill(on ? DemoStyle.orange : Color.white.opacity(0.06)))
        }
    }
}

@available(iOS 15.0, *)
struct DemoStats: View {
    @ObservedObject var store: DemoStore
    let onClose: () -> Void
    @State private var picked = 4
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                DemoHeader(title: "Stats", onClose: onClose).padding(.top, 8)
                DemoCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Hop calendar").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                        Text("Bigger dot, more spent. Paw = no-spend day.").font(.system(size: 13, weight: .semibold)).foregroundColor(DemoStyle.soft)
                        LazyVGrid(columns: columns, spacing: 6) {
                            ForEach(1...31, id: \.self) { d in cell(d) }
                        }
                    }
                }
                DemoCard {
                    let total = store.entries.filter { $0.day == picked }.reduce(0) { $0 + $1.amount }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Oct \(picked)").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                        Text(total > 0 ? "Spent " + demoMoney(total) : "No-spend day 🐾")
                            .font(.system(size: 16, weight: .semibold)).foregroundColor(total > 0 ? .white : DemoStyle.green)
                    }
                }
                Spacer().frame(height: 90)
            }
            .padding(.horizontal, 16)
        }
    }

    private func cell(_ d: Int) -> some View {
        let total = store.entries.filter { $0.day == d }.reduce(0) { $0 + $1.amount }
        let size = CGFloat(min(22, max(6, total / 6)))
        let past = d <= 4
        return Button(action: { demoTap(); picked = d }) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(d == picked ? 0.18 : 0.06))
                if total > 0 {
                    Circle().fill(Color(red: 0.93, green: 0.77, blue: 0.35)).frame(width: size, height: size)
                } else if past || d < 14 {
                    Image(systemName: "pawprint.fill").font(.system(size: 12)).foregroundColor(DemoStyle.green.opacity(0.8))
                }
            }
            .frame(height: 44)
        }
    }
}
