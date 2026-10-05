import UIKit
import Capacitor
import StoreKit
import SwiftUI
import WidgetKit

// The bridge honeybun.me uses inside the iPhone app: it hands over the phone's own token so the widget
// and Siri shortcuts can reach your budget, and nudges the widget to refresh.
@objc(HoneybunNativePlugin)
public class HoneybunNativePlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "HoneybunNativePlugin"
    public let jsName = "HoneybunNative"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "setToken", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "clear", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "refreshWidgets", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "info", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setTab", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setIcon", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "getTips", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "buyTip", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "openNativePreview", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "openNativeApp", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "setHalloween", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "splashDone", returnType: CAPPluginReturnPromise)
    ]

    // Halloween Honeybun: the website's Settings switch. This is the one stored value (read at launch for the native loading screen
    // and injected into the website as window.__hbHH). Changing it only changes how things look, never any account data.
    @objc func setHalloween(_ call: CAPPluginCall) {
        HalloweenPref.enabled = call.getBool("on") ?? false
        DispatchQueue.main.async {
            NativeChrome.shared.vc?.applyHalloweenChrome()
            call.resolve()
        }
    }

    // the website calls this once it has its first real screen, so the native loading screen can fade out right away
    @objc func splashDone(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            NativeChrome.shared.splashDone()
            call.resolve()
        }
    }

    // opens the hands-on SwiftUI demo (sample data only) over the app
    @objc func openNativePreview(_ call: CAPPluginCall) {
        guard #available(iOS 15.0, *) else { call.reject("The preview needs iOS 15 or newer."); return }
        DispatchQueue.main.async {
            guard let vc = NativeChrome.shared.vc else { call.reject("Not ready yet."); return }
            let host = UIHostingController(rootView: DemoRoot(onClose: { [weak vc] in vc?.dismiss(animated: true, completion: nil) }))
            host.modalPresentationStyle = .fullScreen
            vc.present(host, animated: true, completion: nil)
            call.resolve()
        }
    }

    // Classic is now the fallback shown over native Honeybun: this is its way back (called from Classic's Settings / login screen)
    @objc func openNativeApp(_ call: CAPPluginCall) {
        guard #available(iOS 15.0, *) else { call.reject("The native app needs iOS 15 or newer."); return }
        DispatchQueue.main.async {
            HoneybunRoot.shared.closeClassic()
            call.resolve()
        }
    }

    // Tip jar: three consumable in-app purchases made in App Store Connect
    private let tipIDs = ["me.honeybun.app.tip.small", "me.honeybun.app.tip.medium", "me.honeybun.app.tip.large"]

    @objc func getTips(_ call: CAPPluginCall) {
        guard #available(iOS 15.0, *) else { call.resolve(["tips": []]); return }
        let ids = tipIDs
        Task {
            do {
                let products = try await Product.products(for: ids)
                let sorted = products.sorted { $0.price < $1.price }
                let tips: [[String: Any]] = sorted.map { ["id": $0.id, "name": $0.displayName, "price": $0.displayPrice] }
                call.resolve(["tips": tips])
            } catch {
                call.reject(error.localizedDescription)
            }
        }
    }

    @objc func buyTip(_ call: CAPPluginCall) {
        guard #available(iOS 15.0, *) else { call.reject("Tips need iOS 15 or newer."); return }
        guard let id = call.getString("id"), tipIDs.contains(id) else { call.reject("That tip isn't available."); return }
        Task {
            do {
                guard let product = try await Product.products(for: [id]).first else { call.reject("That tip isn't available."); return }
                let result = try await product.purchase()
                switch result {
                case .success(let verification):
                    switch verification {
                    case .verified(let transaction):
                        await transaction.finish()
                        call.resolve(["status": "thanks"])
                    case .unverified:
                        call.reject("Apple couldn't verify the purchase.")
                    }
                case .userCancelled:
                    call.resolve(["status": "cancelled"])
                case .pending:
                    call.resolve(["status": "pending"])
                @unknown default:
                    call.resolve(["status": "unknown"])
                }
            } catch {
                call.reject(error.localizedDescription)
            }
        }
    }

    // seasonal home-screen icon: pass the alternate icon's name, or nothing to go back to the normal one
    @objc func setIcon(_ call: CAPPluginCall) {
        let name = call.getString("name")
        DispatchQueue.main.async {
            guard UIApplication.shared.supportsAlternateIcons, UIApplication.shared.alternateIconName != name else { call.resolve(); return }
            UIApplication.shared.setAlternateIconName(name) { error in
                if let error = error { call.reject(error.localizedDescription) } else { call.resolve() }
            }
        }
    }

    // lets the website know which native pieces this build of the app has
    @objc func info(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            call.resolve(["nativeTabs": true, "nativeRefresh": true, "icons": true, "iconsV": 2, "tips": true, "demo": false, "nativeBeta": true, "halloween": true, "tabsHeight": NativeChrome.shared.height, "version": 2])
        }
    }

    // the website tells the native tab bar which tab to highlight, and whether to show
    @objc func setTab(_ call: CAPPluginCall) {
        let tab = call.getString("tab")
        let visible = call.getBool("visible") ?? true
        let app = call.getBool("app") ?? true
        DispatchQueue.main.async {
            NativeChrome.shared.set(tab: tab, visible: visible, app: app)
            call.resolve()
        }
    }

    @objc func setToken(_ call: CAPPluginCall) {
        Honeybun.token = call.getString("token")
        WidgetCenter.shared.reloadAllTimelines()
        call.resolve()
    }

    @objc func clear(_ call: CAPPluginCall) {
        Honeybun.token = nil
        WidgetCenter.shared.reloadAllTimelines()
        call.resolve()
    }

    @objc func refreshWidgets(_ call: CAPPluginCall) {
        WidgetCenter.shared.reloadAllTimelines()
        call.resolve()
    }
}
