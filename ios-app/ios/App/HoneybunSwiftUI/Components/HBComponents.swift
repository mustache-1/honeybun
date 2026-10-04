import SwiftUI

@available(iOS 15.0, *)
struct HBSectionHeader: View {
    let title: String
    var action: String? = nil
    var onAction: (() -> Void)? = nil
    var body: some View {
        HStack {
            Text(title).font(.system(size: 21, weight: .bold)).foregroundColor(.white)
            Spacer()
            if let action = action, let onAction = onAction {
                Button(action: onAction) {
                    HStack(spacing: 3) { Text(action); Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)) }
                        .font(.subheadline.weight(.semibold)).foregroundColor(Color(red: 0.72, green: 0.68, blue: 0.9))
                }
            }
        }
        .padding(.top, 4)
    }
}

// A round colored icon, like the category icons in the mockups.
@available(iOS 15.0, *)
struct HBCircleIcon: View {
    let symbol: String
    var tint: Color = HB.orange
    var size: CGFloat = 38
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .bold))
            .foregroundColor(tint)
            .frame(width: size, height: size)
            .background(Circle().fill(tint.opacity(0.16)))
            .overlay(Circle().stroke(tint.opacity(0.35), lineWidth: 1))
    }
}

@available(iOS 15.0, *)
struct HBEntryRow: View {
    let entry: HBEntry
    var who: String? = nil
    var body: some View {
        let cat = HBCategory.of(entry.category)
        HStack(spacing: 12) {
            if entry.isIncome { HBCircleIcon(symbol: "arrow.down", tint: HB.green) } else { HBCircleIcon(symbol: cat.symbol, tint: Color(rgb: cat.rgb)) }
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.label).font(.system(size: 16, weight: .semibold)).foregroundColor(.white).lineLimit(1)
                Text([who, HBDay.short(entry.date)].compactMap { $0 }.joined(separator: " · ")).font(.system(size: 13)).foregroundColor(HB.soft)
            }
            Spacer(minLength: 8)
            Text((entry.isIncome ? "+" : "") + HBFormat.money(entry.amount)).font(.system(size: 16, weight: .semibold).monospacedDigit())
                .foregroundColor(entry.isIncome ? HB.green : .white)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

// The Honeybun bottom bar: a rounded floating bar with the selected tab glowing orange. It sits in the safe area, so it clears the home indicator
// on every iPhone and the content scrolls behind/above it.
@available(iOS 15.0, *)
struct HBTabBar: View {
    @Binding var selected: HBTab
    private func symbol(_ t: HBTab, _ on: Bool) -> String {
        switch t {
        case .home: return on ? "house.fill" : "house"
        case .money: return "chart.bar.fill"
        case .goals: return "scope"
        case .together: return "person.2"
        case .inbox: return on ? "envelope.fill" : "envelope"
        }
    }
    var body: some View {
        HStack(spacing: 0) {
            ForEach(HBTab.allCases, id: \.self) { t in
                let on = selected == t
                Button { selected = t } label: {
                    VStack(spacing: 3) {
                        Image(systemName: symbol(t, on)).font(.system(size: 21, weight: .semibold)).frame(height: 24)
                        Text(t.rawValue).font(.system(size: 11, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .foregroundColor(on ? HB.orange : Color(red: 0.72, green: 0.68, blue: 0.85).opacity(0.85))
                    .shadow(color: on ? HB.orange.opacity(0.55) : .clear, radius: 7)
                }
                .accessibilityLabel(t.rawValue)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(.horizontal, 6).padding(.vertical, 4)
        .background(HBProbe(kind: .barTop))
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.13, green: 0.095, blue: 0.16), Color(red: 0.075, green: 0.052, blue: 0.10)], startPoint: .top, endPoint: .bottom))   // fully solid: nothing shows through
        )
        .overlay(RoundedRectangle(cornerRadius: 30, style: .continuous).stroke(Color.white.opacity(0.10), lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 14, y: 6)
        .padding(.horizontal, 12).padding(.top, 6).padding(.bottom, 4)
    }
}

@available(iOS 15.0, *)
struct HBMessageView: View {
    let title: String
    let message: String
    var primary: (String, () -> Void)? = nil
    var secondary: (String, () -> Void)? = nil
    var body: some View {
        VStack(spacing: 14) {
            Image("HBMoneyBun").resizable().scaledToFit().frame(width: 96)
            Text(title).font(.title3.weight(.bold)).foregroundColor(.white)
            Text(message).font(.subheadline).foregroundColor(HB.soft).multilineTextAlignment(.center)
            if let p = primary { Button(p.0, action: p.1).buttonStyle(.borderedProminent).tint(HB.orangeDeep) }
            if let s = secondary { Button(s.0, action: s.1).foregroundColor(HB.orange) }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// Month menu used by Home and Money: "This Month" with a chevron, listing the last 12 months.
@available(iOS 15.0, *)
struct HBMonthMenu: View {
    @ObservedObject var store: HBAppStore
    var body: some View {
        Menu {
            ForEach(store.recentMonths, id: \.self) { m in
                Button { store.setMonth(m) } label: {
                    if m == store.month { Label(store.monthTitle(m) + (m == HBDay.monthKey() ? "" : ""), systemImage: "checkmark") } else { Text(store.monthTitle(m)) }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(store.monthTitle(store.month)).font(.system(size: 15, weight: .medium)).lineLimit(1)
                Image(systemName: "chevron.down").font(.system(size: 11, weight: .bold))
            }
            .foregroundColor(Color(red: 1, green: 0.92, blue: 0.84))
            .padding(.horizontal, 14).frame(height: 36)
            .background(Capsule().fill(Color.white.opacity(0.07)))
            .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
        }
        .accessibilityLabel("Month: \(store.monthTitle(store.month))")
    }
}
