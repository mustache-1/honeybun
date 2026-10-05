import SwiftUI
import LocalAuthentication
import UIKit

// Native Face ID app lock. It only decides whether the native app's screens are visible: it never signs you out, and a cancelled or failed
// Face ID just leaves Honeybun locked with an Unlock button. The "device owner" policy lets the phone's passcode stand in when Face ID
// isn't set up or doesn't work. The on/off switch is a per-device setting (Classic's lock is separate: it lives in the web view).
@available(iOS 15.0, *)
@MainActor final class HBAppLock: ObservableObject {
    static let shared = HBAppLock()
    static let key = "hb-native-lock"
    static let relockAfter: TimeInterval = 15      // same as Classic: come back after 15 s away and it asks again

    @Published private(set) var enabled: Bool
    @Published private(set) var locked: Bool
    @Published private(set) var covered = false    // hides the screen in the app switcher while the lock is on
    @Published var message: String?
    private var backgroundedAt: Date?
    private var authenticating = false

    private init() {
        let on = UserDefaults.standard.bool(forKey: Self.key)
        enabled = on; locked = on                  // a cold start with the lock on begins locked
        let nc = NotificationCenter.default
        nc.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.willResign() } }
        nc.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.backgroundedAt = Date() } }
        nc.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.didBecomeActive() } }
    }

    /// whether this phone can ask for Face ID / Touch ID / the passcode at all
    var available: Bool { var e: NSError?; return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &e) }
    var methodName: String {
        let c = LAContext(); var e: NSError?
        _ = c.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &e)
        switch c.biometryType { case .faceID: return "Face ID"; case .touchID: return "Touch ID"; default: return "your passcode" }
    }

    private func authenticate(_ reason: String) async -> Bool {
        let ctx = LAContext(); ctx.localizedCancelTitle = "Cancel"
        do { return try await ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) } catch { return false }
    }

    /// Turn the lock on: only after the phone confirms it's really you (so a lock can't be set up that nobody can open).
    func enable() async -> String? {
        guard available else { return "Set up Face ID or a passcode in your iPhone's Settings first." }
        guard await authenticate("Turn on the Honeybun lock") else { return "The lock stayed off: Face ID or the passcode wasn't confirmed." }
        UserDefaults.standard.set(true, forKey: Self.key)
        enabled = true; locked = false
        return nil
    }
    func disable() async -> String? {
        guard await authenticate("Turn off the Honeybun lock") else { return "The lock stayed on: it wasn't confirmed." }
        UserDefaults.standard.set(false, forKey: Self.key)
        enabled = false; locked = false; covered = false
        return nil
    }

    func unlock() async {
        guard enabled, locked, !authenticating else { return }
        authenticating = true; message = nil
        let ok = await authenticate("Unlock Honeybun")
        authenticating = false
        if ok { locked = false } else { message = "Couldn't unlock. Try again." }
    }

    /// signed out / account deleted: nothing left to protect, so the next account starts unlocked (the on/off switch stays)
    func reset() { locked = false; covered = false; message = nil }
    /// a fresh sign-in has just proved who you are
    func signedIn() { locked = false; message = nil }

    private func willResign() { if enabled { covered = true } }
    private func didBecomeActive() {
        covered = false
        if enabled, !locked, let t = backgroundedAt, Date().timeIntervalSince(t) > Self.relockAfter { locked = true }
        backgroundedAt = nil
        if enabled && locked { Task { await unlock() } }
    }
}

/// what covers the app while it's locked (and, with no button, in the app switcher)
@available(iOS 15.0, *)
struct HBLockCover: View {
    @ObservedObject var lock: HBAppLock
    var body: some View {
        ZStack {
            HBBackground(glow: true, scene: false).ignoresSafeArea()
            if lock.locked {
                VStack(spacing: 16) {
                    Image("HBHero").resizable().scaledToFit().frame(width: 150).accessibilityHidden(true)
                    Text("Honeybun is locked").font(.system(size: 24, weight: .heavy)).foregroundColor(.white)
                    Text("Use \(lock.methodName) to open your budget.").font(.system(size: 16)).foregroundColor(HB.soft).multilineTextAlignment(.center)
                    if let m = lock.message { Text(m).font(.footnote).foregroundColor(HB.red) }
                    HBPillButton(title: "Unlock", symbol: "faceid") { Task { await lock.unlock() } }.frame(maxWidth: 260).accessibilityIdentifier("hb-lock-unlock")
                }
                .padding(32)
            }
        }
    }
}
