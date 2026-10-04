import UIKit
import SwiftUI

// Opens the native SwiftUI Honeybun over the Capacitor app. Capacitor stays the production root (and the place you sign in);
// the native screens borrow its login session (see HBSession) until they've been verified screen by screen.
enum HBLauncher {
    @available(iOS 15.0, *)
    static func present(from vc: UIViewController, onClosed: @escaping () -> Void) {
        HBFonts.register()
        let host = UIHostingController(rootView: HBRootView(onClose: { [weak vc] in
            vc?.dismiss(animated: true, completion: onClosed)
        }))
        host.modalPresentationStyle = .fullScreen
        host.view.backgroundColor = UIColor(red: 0.051, green: 0.035, blue: 0.075, alpha: 1)
        vc.present(host, animated: true, completion: nil)
    }

#if DEBUG
    @available(iOS 15.0, *)
    @MainActor static func presentMock(from vc: UIViewController) {
        HBFonts.register()
        let store = HBAppStore()
        store.selectedTab = .goals
        let host = UIHostingController(rootView: HBRootView(store: store, onClose: {}))
        host.modalPresentationStyle = .fullScreen
        host.view.backgroundColor = UIColor(red: 0.051, green: 0.035, blue: 0.075, alpha: 1)
        vc.present(host, animated: false, completion: nil)
    }

    @available(iOS 15.0, *)
    @MainActor static func presentPreview(from vc: UIViewController, screen: String) {
        HBFonts.register()
        guard let store = HBPreview.store(for: screen) else { return }
        let host = UIHostingController(rootView: HBRootView(store: store, onClose: {}))
        host.modalPresentationStyle = .fullScreen
        host.view.backgroundColor = UIColor(red: 0.051, green: 0.035, blue: 0.075, alpha: 1)
        vc.present(host, animated: false, completion: nil)
    }
#endif
}
