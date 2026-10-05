import SwiftUI
import UIKit

// MARK: - Invite friends / referrals: the website's "Invite & earn" screen (the same /api/referrals data and rules).

@available(iOS 15.0, *)
struct HBReferralsView: View {
    @ObservedObject var store: HBAppStore
    @Environment(\.dismiss) private var dismiss
    @State private var info: HBReferrals?
    @State private var error: String?
    @State private var loading = true
    @State private var copied = false
    @State private var showShare = false

    private func amount(_ cents: Int) -> String { HBFormat.money(Double(cents) / 100.0).replacingOccurrences(of: ".00", with: "") }

    var body: some View {
        HBSheetScaffold(title: "Invite friends", onBack: { dismiss() }) {
            Text("Share Honeybun and earn gift cards.").font(.footnote).foregroundColor(HB.soft)
            if let r = info {
                hero(r)
                linkCard(r)
                howItWorks(r)
                friendsCard(r)
                if !r.rewards.isEmpty { rewardsCard(r) }
                fine
            } else if loading { ProgressView().tint(HB.orange).frame(maxWidth: .infinity).padding(40) }
            if let e = error { Text(e).font(.footnote).foregroundColor(HB.red) }
        }
        .task { await load() }
        .sheet(isPresented: $showShare) { if let r = info { HBActivityView(items: [shareText(r)]) } }
    }

    private func load() async {
        if store.isPreview { info = HBReferralsView.previewInfo; loading = false; return }
        do { info = try await HBAPI.shared.referrals() } catch { self.error = error.localizedDescription }
        loading = false
    }
    private func shareText(_ r: HBReferrals) -> String { "I'm using Honeybun to manage money together. Try it: " + r.link }

    private func hero(_ r: HBReferrals) -> some View {
        let got = r.inCycle, left = r.goal - got
        return VStack(alignment: .leading, spacing: 10) {
            Text("Invite \(r.goal) friends, get a \(amount(r.reward_cents)) gift card").font(.system(size: 22, weight: .bold)).foregroundColor(Color(red: 1, green: 0.83, blue: 0.48))
            Text("When a friend signs up with your link and uses Honeybun for a week, they count. Every \(r.goal) friends = a \(amount(r.reward_cents)) gift card, and there's no limit.")
                .font(.system(size: 15)).foregroundColor(Color(red: 0.86, green: 0.82, blue: 0.95)).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                ForEach(0..<max(1, r.goal), id: \.self) { i in
                    let wait = min(r.pending, r.goal - got)
                    Circle().fill(i < got ? HB.green : (i < got + wait ? HB.orange.opacity(0.6) : Color.white.opacity(0.12))).frame(width: 26, height: 26)
                        .overlay(Group { if i < got { Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundColor(.black.opacity(0.7)) } else if i == r.goal - 1 { Text("🎁").font(.system(size: 13)) } })
                }
            }
            Text(r.qualified >= r.goal && got == 0 ? "You earned \(r.qualified / r.goal) gift card\(r.qualified / r.goal > 1 ? "s" : "")! 🎉 Keep going for the next one." : "\(got) of \(r.goal) · \(left) more to your next gift card")
                .font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).hbCard()
    }

    private func linkCard(_ r: HBReferrals) -> some View {
        VStack(spacing: 10) {
            Text(r.link.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: "")).font(.system(size: 16, weight: .semibold)).foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity).padding(.vertical, 12).background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.06)))
            HStack(spacing: 10) {
                HBPillButton(title: copied ? "Copied" : "Copy", symbol: copied ? "checkmark" : "doc.on.doc", filled: false) { UIPasteboard.general.string = r.link; copied = true }.accessibilityIdentifier("hb-ref-copy")
                HBPillButton(title: "Share link", symbol: "square.and.arrow.up") { showShare = true }.accessibilityIdentifier("hb-ref-share")
            }
            HBPillButton(title: "Text a friend", symbol: "message", filled: false) {
                let body = shareText(r).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                if let u = URL(string: "sms:&body=" + body) { UIApplication.shared.open(u) }
            }
        }
        .padding(16).hbCard()
    }

    private func howItWorks(_ r: HBReferrals) -> some View {
        let steps: [(String, String)] = [
            ("Share your link", "Send it to friends, family, or post it anywhere."),
            ("They sign up", "They create a free account with your link and confirm their email. Bun tells you right away."),
            ("They use it for a week", "Once they've logged on \(r.active_days_needed) different days and are still using it after \(r.days_needed) days, they count. Alone or with a partner, both work."),
            ("Get your \(amount(r.reward_cents)) gift card", "Every \(r.goal) friends who count = a \(amount(r.reward_cents)) gift card, emailed to you."),
        ]
        return VStack(alignment: .leading, spacing: 12) {
            Text("How it works").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
            ForEach(Array(steps.enumerated()), id: \.offset) { i, s in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(i + 1)").font(.system(size: 14, weight: .bold)).foregroundColor(.black.opacity(0.8)).frame(width: 26, height: 26).background(Circle().fill(HB.orange))
                    VStack(alignment: .leading, spacing: 2) { Text(s.0).font(.system(size: 15, weight: .semibold)).foregroundColor(.white); Text(s.1).font(.system(size: 13)).foregroundColor(HB.soft).fixedSize(horizontal: false, vertical: true) }
                }
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).hbCard()
    }

    private func friendsCard(_ r: HBReferrals) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Text("Your friends").font(.system(size: 18, weight: .bold)).foregroundColor(.white); Spacer(); if !r.people.isEmpty { Text("\(r.people.count) signed up").font(.footnote).foregroundColor(HB.soft) } }
            if r.people.isEmpty { Text("No one yet. Share your link and Bun will let you know the moment someone joins 🐰").font(.footnote).foregroundColor(HB.soft) }
            ForEach(Array(r.people.enumerated()), id: \.offset) { _, p in personRow(p, r) }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).hbCard()
    }
    private func personRow(_ p: HBReferralPerson, _ r: HBReferrals) -> some View {
        let name = p.name ?? "Former member"
        let day = min(r.days_needed, Int((Date().timeIntervalSince1970 - p.created_at) / 86400) + 1)
        let (sub, chip, tint): (String, String, Color) = {
            switch p.status {
            case "qualified": return ("Counts toward your gift card", "Counted ✓", HB.green)
            case "pending": return ("Day \(day) of \(r.days_needed) · active \(min(p.active_days, r.active_days_needed)) of \(r.active_days_needed) days", "On the way", HB.orange)
            default: return (HBStats.referralReason(p.reason), "Not counted", HB.soft)
            }
        }()
        return HStack(spacing: 12) {
            Text(String(name.prefix(1)).uppercased()).font(.system(size: 15, weight: .bold)).foregroundColor(.white).frame(width: 34, height: 34).background(Circle().fill(Color.white.opacity(0.1)))
            VStack(alignment: .leading, spacing: 1) { Text(name).font(.system(size: 15, weight: .semibold)).foregroundColor(.white); Text(sub).font(.system(size: 12)).foregroundColor(HB.soft).lineLimit(2) }
            Spacer(minLength: 6)
            Text(chip).font(.system(size: 12, weight: .bold)).foregroundColor(tint).padding(.horizontal, 10).padding(.vertical, 5).overlay(Capsule().stroke(tint.opacity(0.6), lineWidth: 1))
        }
    }
    private func rewardsCard(_ r: HBReferrals) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your gift cards").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
            ForEach(Array(r.rewards.enumerated()), id: \.offset) { _, w in
                let when = Date(timeIntervalSince1970: w.sent_at ?? w.created_at)
                HStack(spacing: 12) {
                    Text("🎁").font(.system(size: 22))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(HBFormat.money(Double(w.amount_cents) / 100.0)) gift card").font(.system(size: 15, weight: .semibold)).foregroundColor(.white)
                        Text((w.status == "sent" ? "Sent " : "On the way · ") + HBReferralsView.dateFmt.string(from: when)).font(.system(size: 12)).foregroundColor(HB.soft)
                    }
                }
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).hbCard()
    }
    private static let dateFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"; return f }()

    private var fine: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Friends must be new to Honeybun, confirm their email, and sign up on their own phone or computer. People in your own budget and accounts made on your devices don't count. Gift cards are sent by email within about 5 business days.")
                .font(.system(size: 12)).foregroundColor(HB.soft).fixedSize(horizontal: false, vertical: true)
            Link("Full referral terms", destination: URL(string: "https://honeybun.me/terms.html#referrals")!).font(.system(size: 12, weight: .semibold)).foregroundColor(HB.orange)
        }
    }

    #if DEBUG
    static let previewInfo: HBReferrals = {
        let j = #"{"code":"ABC123","goal":3,"reward_cents":1000,"qualified":4,"pending":1,"rejected":1,"link":"https://honeybun.me/r/ABC123","days_needed":7,"active_days_needed":4,"people":[{"name":"Alex","status":"qualified","reason":null,"created_at":1790000000,"active_days":7},{"name":"Jo","status":"pending","reason":null,"created_at":1791000000,"active_days":2},{"name":"Sky","status":"rejected","reason":"inactive","created_at":1789000000,"active_days":1}],"rewards":[{"amount_cents":1000,"status":"sent","created_at":1790500000,"sent_at":1790600000}]}"#
        return (try? JSONDecoder().decode(HBReferrals.self, from: Data(j.utf8))) ?? HBReferrals(code: "", goal: 3, reward_cents: 1000, qualified: 0, pending: 0, rejected: 0, link: "https://honeybun.me", days_needed: 7, active_days_needed: 4, people: [], rewards: [])
    }()
    #else
    static let previewInfo = HBReferrals(code: "", goal: 3, reward_cents: 1000, qualified: 0, pending: 0, rejected: 0, link: "https://honeybun.me", days_needed: 7, active_days_needed: 4, people: [], rewards: [])
    #endif
}
