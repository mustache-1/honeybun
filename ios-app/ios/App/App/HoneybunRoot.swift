import UIKit
import SwiftUI
import Capacitor
import WebKit
import UserNotifications

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
        // CI only: prove the Native → Classic → Native round trip in the simulator (open Classic after 4 s, come back after 16 s)
        if ProcessInfo.processInfo.arguments.contains("-HBClassicDemo") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { HoneybunRoot.shared.openClassic() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 16) { HoneybunRoot.shared.closeClassic() }
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
        guard #available(iOS 15.0, *), let link = HBDeepLink.parse(url), let store = storeBox as? HBAppStore else { return false }
        if classic?.presentingViewController != nil { closeClassic() }
        Task { @MainActor in store.pendingLink = link }
        return true
    }
}

// Notifications: Honeybun used to register for push only from inside the Classic web page. Native is the default now, so the app does it
// itself — but only when notifications were already allowed (turning them on or off still lives in Classic's Settings).
enum HoneybunPush {
    static func refreshIfAllowed() {
        UNUserNotificationCenter.current().getNotificationSettings { s in
            guard s.authorizationStatus == .authorized || s.authorizationStatus == .provisional else { return }
            DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() }
        }
    }
    static func upload(_ token: Data) {
        guard #available(iOS 15.0, *), HBSession.hasSessionCookie else { return }
        let hex = token.map { String(format: "%02x", $0) }.joined()
        Task { _ = try? await HBAPI.shared.send("/api/push/apns", method: "POST", body: ["token": hex]) }
    }
}
