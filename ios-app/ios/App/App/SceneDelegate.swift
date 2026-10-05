import UIKit
import Capacitor

// UIScene lifecycle (required by the iOS 26+ SDKs). The scene owns the window and the root view controller;
// AppDelegate keeps only app-level work (push tokens, launch-time notification refresh).
// Opening links used to arrive at the AppDelegate; with scenes they arrive here, on cold launch (in `connectionOptions`) and while running.
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        // Native Honeybun is the root (see HoneybunRoot); Classic is only built when asked for.
        let w = UIWindow(windowScene: windowScene)
        w.backgroundColor = UIColor(red: 0.051, green: 0.035, blue: 0.075, alpha: 1)
        w.rootViewController = HoneybunRoot.shared.makeRoot()
        w.makeKeyAndVisible()
        window = w

        // cold launch from a Universal Link or a custom-scheme URL: the root exists now, so the link can be handled
        for activity in connectionOptions.userActivities { handle(activity) }
        if !connectionOptions.urlContexts.isEmpty { open(connectionOptions.urlContexts) }
    }

    // Universal Links while the app is running: honeybun.me verify / reset / invite links open the native screens
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        handle(userActivity)
    }

    // Custom-scheme / file URLs while the app is running
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        open(URLContexts)
    }

    @discardableResult private func handle(_ userActivity: NSUserActivity) -> Bool {
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb, let url = userActivity.webpageURL, HoneybunRoot.shared.handle(url: url) { return true }
        return ApplicationDelegateProxy.shared.application(UIApplication.shared, continue: userActivity, restorationHandler: { _ in })
    }

    private func open(_ contexts: Set<UIOpenURLContext>) {
        for context in contexts {
            var options: [UIApplication.OpenURLOptionsKey: Any] = [.openInPlace: context.options.openInPlace]
            if let source = context.options.sourceApplication { options[.sourceApplication] = source }
            if let annotation = context.options.annotation { options[.annotation] = annotation }
            _ = ApplicationDelegateProxy.shared.application(UIApplication.shared, open: context.url, options: options)
        }
    }
}
