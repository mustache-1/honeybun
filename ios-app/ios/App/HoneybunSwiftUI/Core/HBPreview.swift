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
        guard let data = HBPreviewData.json.data(using: .utf8), let snap = try? JSONDecoder().decode(HBNestSnapshot.self, from: data) else { return nil }
        let s = HBAppStore(previewSnapshot: snap, month: HBPreviewData.month, prevSpent: HBPreviewData.previousDaily.values.reduce(0, +), prevDaily: HBPreviewData.previousDaily)
        switch screen {
        case "splash": s.forceLoading = true
        case "homeend": s.previewScrollToEnd = true
        case "moneyend": s.selectedTab = .money; s.previewScrollToEnd = true
        case "money": s.selectedTab = .money
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
