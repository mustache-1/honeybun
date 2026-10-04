import UIKit
import Capacitor
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
        CAPPluginMethod(name: "setIcon", returnType: CAPPluginReturnPromise)
    ]

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
            call.resolve(["nativeTabs": true, "nativeRefresh": true, "icons": true, "iconsV": 2, "tabsHeight": NativeChrome.shared.height, "version": 2])
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
