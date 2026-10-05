import UIKit
import SwiftUI
import Capacitor
import WebKit
import UserNotifications
import WidgetKit

extension Notification.Name { static let hbClassicClosed = Notification.Name("hbClassicClosed") }

// The iPhone app's root. Native Honeybun (SwiftUI) is what opens: splash → session check → Home, or Welcome when signed out.
// The Classic app (the Capacitor web view) is no longer created at launch. It is built only when someone asks for it
// ("Open Classic Honeybun"), shown over the native app, and dismissed to come back. On iOS 14, which can't run the SwiftUI app, Classic stays the root.
final class HoneybunRoot {
    static let shared = HoneybunRoot()
    private(set) var classic: MainViewController?
    private weak var nativeVC: UIViewController?
    private var storeBox: AnyObject?          // the HBAppStore behind the native root (iOS 15+)
    private var classicShownBefore = false

    @MainActor func makeRoot() -> UIViewController {
        guard #available(iOS 15.0, *) else { return makeClassic() }
        HBFonts.register()
        HoneybunDevice.install()
        let store: HBAppStore
        let host: UIViewController
        #if DEBUG
        // CI screenshots and UI tests: the real native screens against sample data / the in-process stand-in backend (never in Release)
        if let seed = HBMockServer.requestedSeed {
            HBMockServer.install(seed: seed)
            store = HBAppStore(); store.selectedTab = .goals
        } else if let screen = HBPreview.requestedScreen, let s = HBPreview.store(for: screen) {
            store = s
        } else { store = HBAppStore() }
        #else
        store = HBAppStore()
        #endif
        storeBox = store
        #if DEBUG
        // CI only: prove the Native → Classic → Native round trip in the simulator (open Classic after 4 s, come back after 40 s)
        if ProcessInfo.processInfo.arguments.contains("-HBClassicDemo") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { HoneybunRoot.shared.openClassic() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 40) { HoneybunRoot.shared.closeClassic() }
        }
        #endif
        let h = UIHostingController(rootView: HBRootView(store: store, onClose: { HoneybunRoot.shared.openClassic() }))
        h.view.backgroundColor = UIColor(red: 0.051, green: 0.035, blue: 0.075, alpha: 1)
        host = h
        nativeVC = host
        return host
    }

    private func makeClassic() -> MainViewController {
        let vc = UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController() as! MainViewController
        classic = vc
        return vc
    }

    // MARK: Classic fallback

    /// Shows the Classic app over native Honeybun. The session cookie is copied into the web view first, so Classic opens already signed in.
    func openClassic() {
        guard #available(iOS 15.0, *), let top = nativeVC else { NSLog("HBROOT openClassic: no native root"); return }
        NSLog("HBROOT openClassic: start")
        Task { @MainActor in
            await HBSession.mirrorToWebView()
            NSLog("HBROOT openClassic: session mirrored, building Classic")
            let c = self.classic ?? self.makeClassic()
            guard c.presentingViewController == nil else { NSLog("HBROOT openClassic: already showing"); return }
            c.modalPresentationStyle = .fullScreen
            NSLog("HBROOT openClassic: presenting from %@ (in window: %d)", String(describing: type(of: top)), top.view.window != nil ? 1 : 0)
            top.present(c, animated: true) {
                NSLog("HBROOT openClassic: presented")
                // after the first time, reload so Classic shows what changed natively (and the right account)
                if self.classicShownBefore { c.webView?.reload() }
                self.classicShownBefore = true
            }
        }
    }

    /// Back to native Honeybun. If someone signed in as another account inside Classic, native follows that session.
    func closeClassic() {
        guard #available(iOS 15.0, *), let c = classic, c.presentingViewController != nil else { NSLog("HBROOT closeClassic: Classic is not showing"); return }
        Task { @MainActor in
            NSLog("HBROOT closeClassic: closing")
            await HBSession.adoptFromWebView()
            c.dismiss(animated: true) { NotificationCenter.default.post(name: .hbClassicClosed, object: nil) }
        }
    }

    // MARK: links (verify / reset / invite)

    /// Returns true when the URL is one the native app handles itself.
    @discardableResult func handle(url: URL) -> Bool {
        guard #available(iOS 15.0, *), let link = HBDeepLink.remember(url), let store = storeBox as? HBAppStore else { return false }
        if classic?.presentingViewController != nil { closeClassic() }
        Task { @MainActor in store.pendingLink = link }
        return true
    }
}

// Notifications. Native Honeybun owns them now (the Classic web page used to). Two things are kept separate:
//  - iOS permission (the system's answer: not asked yet / allowed / denied), and
//  - Honeybun's own on/off switch for this phone (`hb-native-push`): "off" means the token is removed from the backend and not re-sent.
// Permission is asked only when you flip the switch on, once; if iOS says no, the screen points to iOS Settings instead of asking again.
enum HoneybunPush {
    static let prefKey = "hb-native-push", tokenKey = "hb-native-apns-token"
    static var userTurnedOff: Bool { UserDefaults.standard.string(forKey: prefKey) == "off" }
    static var savedToken: String? { UserDefaults.standard.string(forKey: tokenKey) }

    static func authorization() async -> UNAuthorizationStatus { await UNUserNotificationCenter.current().notificationSettings().authorizationStatus }

    /// Launch / after sign-in: if iOS already allows notifications and you haven't turned them off here, make sure this phone's token is registered.
    static func refreshIfAllowed() {
        guard !userTurnedOff else { return }
        Task {
            let s = await authorization()
            guard s == .authorized || s == .provisional || s == .ephemeral else { return }
            await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
        }
    }

    /// Settings switch ON. Returns an error message, or nil when notifications are on.
    static func enable() async -> String? {
        var s = await authorization()
        if s == .notDetermined {
            let ok = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])) ?? false
            s = ok ? .authorized : .denied
        }
        guard s == .authorized || s == .provisional || s == .ephemeral else { return "Notifications are off for Honeybun in iOS. Turn them on in Settings → Notifications → Honeybun." }
        UserDefaults.standard.set("on", forKey: prefKey)
        await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
        return nil
    }

    /// Settings switch OFF: remove this phone from the backend and stop registering.
    static func disable() async {
        UserDefaults.standard.set("off", forKey: prefKey)
        await removeTokenFromBackend()
        await MainActor.run { UIApplication.shared.unregisterForRemoteNotifications() }
    }

    /// Log out / delete: this phone must stop getting the previous account's notifications. (The switch itself stays as it was.)
    static func removeTokenFromBackend() async {
        guard #available(iOS 15.0, *), let t = savedToken else { return }
        _ = try? await HBAPI.shared.send("/api/push/apns", method: "DELETE", body: ["token": t])
    }

    /// iOS handed us a token: remember it, and send it to the signed-in account (unless it was turned off here).
    static func upload(_ token: Data) {
        let hex = token.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(hex, forKey: tokenKey)
        guard #available(iOS 15.0, *), HBSession.hasSessionCookie, !userTurnedOff else { return }
        Task { _ = try? await HBAPI.shared.send("/api/push/apns", method: "POST", body: ["token": hex]) }
    }
}

// The widget and Siri token follows the native session (see HBDeviceToken): made at sign-in, revoked at log out.
enum HoneybunDevice {
    /// redraw the widget whenever the token changes
    static func install() { HBDeviceToken.onChange = { WidgetCenter.shared.reloadAllTimelines() } }
    static func ensureAppToken() async { await HBDeviceToken.ensure() }
    static func revokeAppToken() async { await HBDeviceToken.revokeOnServer() }
    static func clearLocal() { HBDeviceToken.clearLocal() }
}
