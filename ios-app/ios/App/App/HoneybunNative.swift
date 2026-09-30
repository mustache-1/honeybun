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
        CAPPluginMethod(name: "refreshWidgets", returnType: CAPPluginReturnPromise)
    ]

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
