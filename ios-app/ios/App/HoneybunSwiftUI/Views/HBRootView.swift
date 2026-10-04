import SwiftUI

// Native Honeybun shell. Screens that aren't native yet say so and hand you back to the classic (web) app, which stays fully working.
@available(iOS 15.0, *)
struct HBRootView: View {
    @StateObject private var store = HBAppStore()
    let onClose: () -> Void

    var body: some View {
        ZStack {
            HB.bg.ignoresSafeArea()
            content
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if store.phase == .ready { HBTabBar(selected: $store.selectedTab) }
        }
        .sheet(item: $store.sheet) { sheet in sheetView(sheet) }
        .task { await store.start() }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder private var content: some View {
        switch store.phase {
        case .checking:
            ProgressView().progressViewStyle(.circular).tint(HB.orange)
        case .signedOut:
            HBMessageView(title: "Sign in first", message: "The native screens use your normal Honeybun login. Open the classic Honeybun, sign in, then come back.",
                          primary: ("Open classic Honeybun", onClose), secondary: ("Try again", { Task { await store.start() } }))
        case let .failed(msg):
            HBMessageView(title: "Couldn't load Honeybun", message: msg,
                          primary: ("Try again", { Task { await store.start() } }), secondary: ("Open classic Honeybun", onClose))
        case .ready:
            switch store.selectedTab {
            case .home: HBHomeView(store: store, onClose: onClose)
            case .money: HBMoneyView(store: store)
            default:
                HBMessageView(title: "\(store.selectedTab.rawValue) isn't native yet",
                              message: "This screen is still the classic Honeybun. Nothing is lost: it uses the same account and data.",
                              primary: ("Open classic Honeybun", onClose))
            }
        }
    }

    @ViewBuilder private func sheetView(_ sheet: HBSheet) -> some View {
        switch sheet {
        case let .newEntry(t): HBEntryForm(store: store, editing: nil, base: store.newEntryDraft(type: t))
        case let .editEntry(e): HBEntryForm(store: store, editing: e, base: store.draft(from: e))
        case .newRecurring: HBRecurringForm(store: store, editing: nil, base: HBRecurringDraft(date: HBDay.todayString, memberID: store.myID))
        case let .editRecurring(r): HBRecurringForm(store: store, editing: r, base: store.draft(from: r))
        case .upcoming: HBUpcomingList(store: store)
        }
    }
}
