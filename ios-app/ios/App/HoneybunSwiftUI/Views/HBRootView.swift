import SwiftUI

// Native Honeybun shell. Screens that aren't native yet say so and hand you back to the classic (web) app, which stays fully working.
@available(iOS 15.0, *)
struct HBRootView: View {
    @StateObject private var store: HBAppStore
    let onClose: () -> Void
    @State private var tabH: CGFloat = 80   // measured height of the floating tab bar

    init(store: HBAppStore? = nil, onClose: @escaping () -> Void) {
        HBFonts.register()
        _store = StateObject(wrappedValue: store ?? HBAppStore())
        self.onClose = onClose
    }

    var body: some View {
        ZStack {
            HBBackground()
            content
        }
        // the tab bar is a persistent overlay in the bottom safe area; screens get its measured height as their bottom inset (below)
        .overlay(alignment: .bottom) {
            if store.phase == .ready { HBTabBar(selected: $store.selectedTab) }
        }
        .onPreferenceChange(HBTabBarHeightKey.self) { tabH = $0 }
        // scrolling content fades out under the status bar / Dynamic Island instead of colliding with the clock
        .overlay(alignment: .top) {
            if store.phase == .ready {
                GeometryReader { g in
                    LinearGradient(colors: [Color(red: 0.06, green: 0.04, blue: 0.09).opacity(0.96), Color(red: 0.06, green: 0.04, blue: 0.09).opacity(0.96), Color(red: 0.06, green: 0.04, blue: 0.09).opacity(0)], startPoint: .top, endPoint: .bottom)
                        .frame(height: g.safeAreaInsets.top + 16)
                }
                .ignoresSafeArea(edges: .top).allowsHitTesting(false)
            }
        }
        .fullScreenCover(item: $store.sheet) { sheet in sheetView(sheet) }
        .task { await store.start() }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder private var content: some View {
        switch store.phase {
        case .checking:
            // while the native screens sign in and load your account, the same Halloween splash as app launch
            HalloweenLoadingView()
        case .signedOut:
            HBMessageView(title: "Sign in first", message: "The native screens use your normal Honeybun login. Open the classic Honeybun, sign in, then come back.",
                          primary: ("Open classic Honeybun", onClose), secondary: ("Try again", { Task { await store.start() } }))
        case let .failed(msg):
            HBMessageView(title: "Couldn't load Honeybun", message: msg,
                          primary: ("Try again", { Task { await store.start() } }), secondary: ("Open classic Honeybun", onClose))
        case .ready:
            switch store.selectedTab {
            case .home: HBHomeView(store: store, bottomInset: tabH + 16, onClose: onClose)
            case .money: HBMoneyView(store: store, bottomInset: tabH + 16)
            default:
                HBMessageView(title: "\(store.selectedTab.rawValue) isn't native yet",
                              message: "This screen is still the classic Honeybun. Nothing is lost: it uses the same account and data.",
                              primary: ("Open classic Honeybun", onClose))
                    .padding(.bottom, tabH)
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
        case .allTransactions: HBTransactionsList(store: store)
        }
    }
}
