import SwiftUI
import UIKit

// MARK: - Help: the website's FAQ (same topics and answers), search, and ways to reach us

@available(iOS 15.0, *)
struct HBHelpView: View {
    @ObservedObject var store: HBAppStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var topic: Int?

    private var infoLine: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\n\n— — —\nApp info (helps us help you): iOS app \(v) (\(b)) · \(store.kind)" + (store.account?.email.map { " · " + $0 } ?? "")
    }
    private func mail(_ subject: String, _ body: String) -> URL? {
        var c = URLComponents(string: "mailto:help@honeybun.me")
        c?.queryItems = [URLQueryItem(name: "subject", value: subject), URLQueryItem(name: "body", value: body + infoLine)]
        return c?.url
    }

    var body: some View {
        HBSheetScaffold(title: "Help", onBack: { dismiss() }) {
            Text("Fast answers without digging around.").font(.footnote).foregroundColor(HB.soft)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundColor(HB.soft)
                TextField("How can we help?", text: $query).foregroundColor(.white).autocapitalization(.none).disableAutocorrection(true).accessibilityIdentifier("hb-help-search")
                if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundColor(HB.soft) } }
            }
            .padding(12).background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.07)))

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                ForEach(Array(HBHelp.topics.enumerated()), id: \.offset) { i, t in
                    Button { topic = topic == i ? nil : i } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(t.t).font(.system(size: 15, weight: .bold)).foregroundColor(.white).lineLimit(2)
                            Text(t.d).font(.system(size: 12)).foregroundColor(HB.soft).lineLimit(3)
                        }
                        .frame(maxWidth: .infinity, minHeight: 70, alignment: .topLeading).padding(12)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(topic == i ? HB.orange.opacity(0.22) : Color.white.opacity(0.06)))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(topic == i ? HB.orange.opacity(0.7) : Color.clear, lineWidth: 1))
                    }.accessibilityAddTraits(topic == i ? .isSelected : [])
                }
            }

            let list = HBHelp.faqs(topic: topic, query: query)
            VStack(spacing: 0) {
                if list.isEmpty { Text("No answers match that. Email us and we'll help.").font(.footnote).foregroundColor(HB.soft).padding(16).frame(maxWidth: .infinity) }
                ForEach(Array(list.enumerated()), id: \.offset) { i, f in
                    DisclosureGroup {
                        Text(f.answer).font(.system(size: 14)).foregroundColor(Color(red: 0.86, green: 0.82, blue: 0.95)).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 4).padding(.bottom, 10)
                    } label: { Text(f.question).font(.system(size: 15, weight: .semibold)).foregroundColor(.white).multilineTextAlignment(.leading) }
                    .tint(HB.orange).padding(.horizontal, 14).padding(.vertical, 10)
                    if i < list.count - 1 { Divider().background(HB.line) }
                }
            }.hbCard()

            VStack(spacing: 10) {
                HBPillButton(title: "Ask Bun", symbol: "bubble.left.and.bubble.right") { store.selectedTab = .inbox; dismiss(); store.sheet = nil }.accessibilityIdentifier("hb-help-ask-bun")
                Text("Your reminders and budget come straight from Bun's inbox.").font(.footnote).foregroundColor(HB.soft)
                if let u = mail("Honeybun help", "Hi! I need help with:\n\n") { Link(destination: u) { helpRow("Email support", "help@honeybun.me", "envelope") } }
                if let u = mail("Honeybun problem report", "What happened, and what did you expect?\n\n") { Link(destination: u) { helpRow("Report a problem", "Tell us what went wrong", "exclamationmark.bubble") } }
            }
        }
    }
    private func helpRow(_ title: String, _ sub: String, _ symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundColor(HB.orange).frame(width: 26)
            VStack(alignment: .leading, spacing: 1) { Text(title).font(.system(size: 16, weight: .semibold)).foregroundColor(.white); Text(sub).font(.system(size: 13)).foregroundColor(HB.soft) }
            Spacer(); Image(systemName: "chevron.right").foregroundColor(HB.soft)
        }.padding(14).frame(maxWidth: .infinity, minHeight: 56).hbCard()
    }
}

// MARK: - What's new: the release list, newest first (the same list as the website)

@available(iOS 15.0, *)
struct HBUpdatesView: View {
    @Environment(\.dismiss) private var dismiss
    private static let outFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "MMMM d, yyyy"; return f }()
    private func pretty(_ d: String) -> String { HBDay.parse(d).map { Self.outFmt.string(from: $0) } ?? d }
    private func tint(_ tag: String) -> Color {
        switch tag { case "new": return HB.green; case "improved": return Color(red: 0.45, green: 0.62, blue: 1); case "fixed": return Color(red: 1, green: 0.45, blue: 0.62); case "security": return Color(red: 0.87, green: 0.63, blue: 0.25); default: return Color(red: 0.7, green: 0.62, blue: 1) }
    }
    var body: some View {
        HBSheetScaffold(title: "What's new", onBack: { dismiss() }) {
            Text("Everything we've shipped, newest first.").font(.footnote).foregroundColor(HB.soft)
            ForEach(Array(HBHelp.releases.enumerated()), id: \.element.id) { i, r in
                release(r, open: i == 0)
            }
        }
    }
    private func release(_ r: HBRelease, open: Bool) -> some View {
        HBReleaseCard(release: r, open: open, title: pretty(r.date) + " · \(r.items.count) \(r.items.count == 1 ? "update" : "updates")", tint: tint, names: HBHelp.tagNames)
    }
}

@available(iOS 15.0, *)
private struct HBReleaseCard: View {
    let release: HBRelease
    @State var open: Bool
    let title: String
    let tint: (String) -> Color
    let names: [String: String]
    init(release: HBRelease, open: Bool, title: String, tint: @escaping (String) -> Color, names: [String: String]) {
        self.release = release; self._open = State(initialValue: open); self.title = title; self.tint = tint; self.names = names
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { withAnimation(.easeInOut(duration: 0.2)) { open.toggle() } } label: {
                HStack(spacing: 10) {
                    Text("v" + release.v).font(.system(size: 14, weight: .heavy)).foregroundColor(.black.opacity(0.85)).padding(.horizontal, 10).padding(.vertical, 4).background(Capsule().fill(HB.orange))
                    VStack(alignment: .leading, spacing: 1) { Text(release.name).font(.system(size: 16, weight: .bold)).foregroundColor(.white); Text(title).font(.system(size: 12)).foregroundColor(HB.soft) }
                    Spacer(minLength: 4)
                    Image(systemName: open ? "chevron.up" : "chevron.down").font(.system(size: 13, weight: .bold)).foregroundColor(HB.soft)
                }.padding(14).contentShape(Rectangle())
            }
            if open {
                ForEach(Array(release.items.enumerated()), id: \.offset) { _, it in
                    Divider().background(HB.line)
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 6) {
                            Text(it.t).font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                            ForEach(it.tags, id: \.self) { tag in
                                Text(names[tag] ?? tag).font(.system(size: 10, weight: .bold)).foregroundColor(tint(tag)).padding(.horizontal, 7).padding(.vertical, 2).overlay(Capsule().stroke(tint(tag).opacity(0.6), lineWidth: 1))
                            }
                        }
                        Text(it.d).font(.system(size: 13)).foregroundColor(Color(red: 0.86, green: 0.82, blue: 0.95)).fixedSize(horizontal: false, vertical: true)
                    }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .hbCard()
    }
}
