import SwiftUI

@available(iOS 15.0, *)
struct HBSectionHeader: View {
    let title: String
    var action: String? = nil
    var onAction: (() -> Void)? = nil
    var body: some View {
        HStack {
            Text(title).font(.title3.weight(.bold)).foregroundColor(.white)
            Spacer()
            if let action = action, let onAction = onAction {
                Button(action: onAction) { Text(action + " ›").font(.subheadline.weight(.semibold)).foregroundColor(Color(red: 0.72, green: 0.68, blue: 0.85)) }
            }
        }
        .padding(.top, 6)
    }
}

@available(iOS 15.0, *)
struct HBTile: View {
    let symbol: String
    var tint: Color = HB.orange
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(tint)
            .frame(width: 38, height: 38)
            .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(tint.opacity(0.16)))
    }
}

@available(iOS 15.0, *)
struct HBEntryRow: View {
    let entry: HBEntry
    var who: String? = nil
    var body: some View {
        HStack(spacing: 12) {
            if entry.isIncome { HBTile(symbol: "dollarsign.circle.fill", tint: HB.green) } else { HBTile(symbol: HBCategory.of(entry.category).symbol) }
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.label).font(.body.weight(.semibold)).foregroundColor(.white).lineLimit(1)
                Text([who, HBDay.short(entry.date)].compactMap { $0 }.joined(separator: " · ")).font(.footnote).foregroundColor(HB.soft)
            }
            Spacer(minLength: 8)
            Text((entry.isIncome ? "+" : "") + HBFormat.money(entry.amount)).font(.body.weight(.semibold).monospacedDigit())
                .foregroundColor(entry.isIncome ? HB.green : .white)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

@available(iOS 15.0, *)
struct HBTabBar: View {
    @Binding var selected: HBTab
    private func symbol(_ t: HBTab) -> String {
        switch t { case .home: return "house.fill"; case .money: return "chart.bar.fill"; case .goals: return "target"; case .together: return "heart.fill"; case .inbox: return "bell.fill" }
    }
    var body: some View {
        HStack(spacing: 0) {
            ForEach(HBTab.allCases, id: \.self) { t in
                Button { selected = t } label: {
                    VStack(spacing: 3) {
                        Image(systemName: symbol(t)).font(.system(size: 20, weight: .semibold))
                        Text(t.rawValue).font(.caption2.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .foregroundColor(selected == t ? HB.orange : Color.white.opacity(0.55))
                }
                .accessibilityLabel(t.rawValue)
            }
        }
        .padding(.horizontal, 8).padding(.top, 4)
        .background(
            Rectangle().fill(Color(red: 0.07, green: 0.05, blue: 0.10).opacity(0.96))
                .overlay(Rectangle().fill(HB.line).frame(height: 1), alignment: .top)
                .ignoresSafeArea(edges: .bottom)
        )
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
            Image(systemName: "exclamationmark.bubble.fill").font(.system(size: 36)).foregroundColor(HB.orange)
            Text(title).font(.title3.weight(.bold)).foregroundColor(.white)
            Text(message).font(.subheadline).foregroundColor(HB.soft).multilineTextAlignment(.center)
            if let p = primary { Button(p.0, action: p.1).buttonStyle(.borderedProminent).tint(HB.orangeDeep) }
            if let s = secondary { Button(s.0, action: s.1).foregroundColor(HB.orange) }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
