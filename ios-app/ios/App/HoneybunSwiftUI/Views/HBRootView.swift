import SwiftUI

// Native Honeybun: the app's root. Launch → splash (checking) → Home, or native Welcome when signed out. Classic (the web app) is only a fallback
// reached from Account (`onClose` opens it).
@available(iOS 15.0, *)
struct HBRootView: View {
    @StateObject private var store: HBAppStore
    @ObservedObject private var lock = HBAppLock.shared
    let onClose: () -> Void

    init(store: HBAppStore? = nil, onClose: @escaping () -> Void) {
        HBFonts.register()
        _store = StateObject(wrappedValue: store ?? HBAppStore())
        self.onClose = onClose
    }

    var body: some View {
        ZStack {
            HBBackground()
            rootLayout
        }
        // scrolling content fades out under the status bar / Dynamic Island instead of colliding with the clock
        .overlay(alignment: .top) {
            if store.phase == .ready {
                // a container that starts at the very top of the screen (under the status bar), with the fade at its top edge
                VStack(spacing: 0) {
                    LinearGradient(colors: [Color(red: 0.06, green: 0.04, blue: 0.09).opacity(0.96), Color(red: 0.06, green: 0.04, blue: 0.09).opacity(0.96), Color(red: 0.06, green: 0.04, blue: 0.09).opacity(0)], startPoint: .top, endPoint: .bottom)
                        .frame(height: HBSafeArea.top + 14)
                    Spacer(minLength: 0)
                }
                .ignoresSafeArea(edges: .top).allowsHitTesting(false)
            }
        }
        .fullScreenCover(item: $store.sheet) { sheet in sheetView(sheet) }
        // Face ID lock: covers everything (sheets included) while locked, and the app-switcher snapshot while the lock is on
        .overlay {
            if (lock.locked && store.phase != .signedOut) || lock.covered { HBLockCover(lock: lock).transition(.opacity) }
        }
        .task { await store.start() }
        .onChange(of: store.phase) { _ in Task { await store.processPendingLink() } }
        .onChange(of: lock.locked) { isLocked in if isLocked { store.sheet = nil } }   // sheets sit above the cover, so close them when the lock engages
        .onReceive(NotificationCenter.default.publisher(for: .hbClassicClosed)) { _ in Task { await store.returnedFromClassic() } }
        .preferredColorScheme(.dark)
    }

    // The tab bar is part of the layout, not an overlay: the screen above it ends where the bar begins (with a gap). The bar sits in the bottom
    // safe area on every iPhone. Each scroll view additionally measures its own end against the bar (HBLayoutMetrics), so the last item clears it.
    @ViewBuilder private var rootLayout: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-HBOverlayBar") {
            // test-only: the old arrangement, with the scroll area running underneath the bar, to prove the measuring fixes it
            ZStack(alignment: .bottom) {
                content
                if store.phase == .ready { HBTabBar(selected: $store.selectedTab) }
            }
        } else {
            stackedLayout
        }
        #else
        stackedLayout
        #endif
    }

    private var stackedLayout: some View {
        VStack(spacing: HB.barGap) {
            content
            if store.phase == .ready { HBTabBar(selected: $store.selectedTab) }
        }
    }

    @ViewBuilder private var content: some View {
        switch store.phase {
        case .checking:
            // while the native screens sign in and load your account, the same Halloween splash as app launch
            HalloweenLoadingView()
        case .signedOut:
            // no (or an expired) session: native Welcome / Login / Create account. No Classic needed.
            HBAuthFlowView(store: store, onClose: onClose)
        case .needsBudget:
            HBSetupView(store: store)
        case .onboarding:
            HBOnboardingView(store: store)
        case let .failed(msg):
            HBMessageView(title: "Couldn't load Honeybun", message: msg,
                          primary: ("Try again", { Task { await store.start() } }), secondary: ("Open classic Honeybun", onClose))
        case .ready:
            switch store.selectedTab {
            case .home: HBHomeView(store: store, onClose: onClose)
            case .money: HBMoneyView(store: store)
            case .goals: HBGoalsView(store: store)
            case .together: HBTogetherView(store: store)
            case .inbox: HBInboxView(store: store, onClose: onClose)
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
        case let .goalDetail(id): HBGoalDetail(store: store, goalID: id)
        case let .goalForm(id): HBGoalForm(store: store, goalID: id)
        case let .settle(f, t): HBSettleSheet(store: store, fromID: f, toID: t)
        case .fairShare: HBFairShareSheet(store: store)
        case let .household(invite): HBHouseholdSheet(store: store, focusInvite: invite)
        case .shopping: HBShoppingSheet(store: store)
        case .search: HBSearchSheet(store: store)
        case .editMe: HBEditMeSheet(store: store)
        case .carry: HBCarrySheet(store: store)
        case .account: HBAccountView(store: store, onClose: onClose)
        }
    }
}
