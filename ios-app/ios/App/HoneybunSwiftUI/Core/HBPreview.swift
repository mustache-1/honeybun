#if DEBUG
import UIKit
import SwiftUI

// Debug builds only: launch with `-HBPreview home|money|addexp|addinc|upcoming|editbill` and the native screens open on a fixed sample month with
// no network and no login, so CI can take simulator screenshots of the real SwiftUI views. Compiled out of Release (TestFlight) builds.
enum HBPreview {
    static var requestedScreen: String? {
        let a = ProcessInfo.processInfo.arguments
        guard let i = a.firstIndex(of: "-HBPreview"), i + 1 < a.count else { return nil }
        return a[i + 1]
    }

    @available(iOS 15.0, *)
    @MainActor static func store(for screen: String) -> HBAppStore? {
        // Together screens: "together" (partner), "togethersolo", "togetherfamily", "togetherjoint" and their sheets
        let tvariant: String? = {
            if screen == "inboxempty" { return "inboxempty" }
            if screen.hasPrefix("inbox") { return "inbox" }
            if screen.hasPrefix("togethersolo") { return "solo" }
            if screen.hasPrefix("togetherfamily") { return "family" }
            if screen.hasPrefix("togetherjoint") { return "joint" }
            if screen.hasPrefix("together") || screen == "household" || screen == "householdinvite" || screen == "settle" || screen == "fairshare" || screen == "shopping" || screen == "search" || screen == "editme" || screen == "settlefamily" { return screen == "settlefamily" ? "family" : "partner" }
            return nil
        }()
        let source: Data? = tvariant.flatMap { try? JSONSerialization.data(withJSONObject: HBPreviewVariants.make($0)) } ?? HBPreviewData.json.data(using: .utf8)
        guard let data = source, let snap = try? JSONDecoder().decode(HBNestSnapshot.self, from: data) else { return nil }
        let s = HBAppStore(previewSnapshot: snap, month: HBPreviewData.month, prevSpent: HBPreviewData.previousDaily.values.reduce(0, +), prevDaily: HBPreviewData.previousDaily)
        switch screen {
        case "splash": s.forceLoading = true
        case "homeend": s.previewScrollToEnd = true
        case "moneyend": s.selectedTab = .money; s.previewScrollToEnd = true
        case "goals": s.selectedTab = .goals
        case "goalsend": s.selectedTab = .goals; s.previewScrollToEnd = true
        case "goaldetail": if let g = snap.goals.first { s.sheet = .goalDetail(g.id) }
        case "goalform": s.sheet = .goalForm(nil)
        case "goaledit": if let g = snap.goals.first { s.sheet = .goalForm(g.id) }
        case "money": s.selectedTab = .money
        case "inbox": s.selectedTab = .inbox; s.seedPreviewInbox("mixed")
        case "inboxupdates": s.selectedTab = .inbox; s.seedPreviewInbox("mixed"); s.previewInboxTab = "updates"
        case "inboxshared": s.selectedTab = .inbox; s.seedPreviewInbox("mixed"); s.previewInboxTab = "shared"
        case "inboxempty": s.selectedTab = .inbox; s.seedPreviewInbox("empty")
        case "inboxend": s.selectedTab = .inbox; s.seedPreviewInbox("long"); s.previewScrollToEnd = true; s.previewInboxTab = "updates"
        case "inboxcarry": s.selectedTab = .inbox; s.seedPreviewInbox("mixed"); s.sheet = .carry
        case "together", "togethersolo", "togetherfamily", "togetherjoint": s.selectedTab = .together; s.seedPreviewShopping()
        case "togetherend", "togethersoloend", "togetherfamilyend", "togetherjointend": s.selectedTab = .together; s.previewScrollToEnd = true; s.seedPreviewShopping()
        case "household": s.selectedTab = .together; s.sheet = .household(false)
        case "householdinvite": s.selectedTab = .together; s.sheet = .household(true)
        case "editme": s.selectedTab = .together; s.sheet = .editMe
        case "fairshare": s.selectedTab = .together; s.sheet = .fairShare
        case "shopping": s.selectedTab = .together; s.seedPreviewShopping(); s.sheet = .shopping
        case "search": s.selectedTab = .together; s.sheet = .search
        case "settle": if let p = s.pairs.first { s.selectedTab = .together; s.sheet = .settle(p.from.id, p.to.id) }
        case "settlefamily": if let p = s.pairs.first { s.selectedTab = .together; s.sheet = .settle(p.from.id, p.to.id) }
        case "addexp": s.sheet = .newEntry("expense")
        case "addinc": s.sheet = .newEntry("income")
        case "upcoming": s.sheet = .upcoming
        case "editbill": if let r = snap.recurring.first { s.sheet = .editRecurring(r) }
        case "editexp": if let e = snap.entries.first(where: { !$0.isIncome }) { s.sheet = .editEntry(e) }
        default: break
        }
        return s
    }
}
#endif
