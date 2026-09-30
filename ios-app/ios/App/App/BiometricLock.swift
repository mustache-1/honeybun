import Capacitor
import LocalAuthentication

// Face ID / Touch ID / device passcode lock for Honeybun.
// honeybun.me calls BiometricLock.available() and BiometricLock.authenticate({ reason }) from its Settings and lock screen.
@objc(BiometricLockPlugin)
public class BiometricLockPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "BiometricLockPlugin"
    public let jsName = "BiometricLock"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "available", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "authenticate", returnType: CAPPluginReturnPromise)
    ]

    @objc func available(_ call: CAPPluginCall) {
        let ctx = LAContext()
        var err: NSError?
        let ok = ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &err)
        var kind = "none"
        if ok {
            switch ctx.biometryType {
            case .faceID: kind = "faceID"
            case .touchID: kind = "touchID"
            default: kind = "passcode"
            }
        }
        call.resolve(["available": ok, "type": kind])
    }

    @objc func authenticate(_ call: CAPPluginCall) {
        let ctx = LAContext()
        ctx.localizedCancelTitle = "Cancel"
        let reason = call.getString("reason") ?? "Unlock Honeybun"
        // .deviceOwnerAuthentication falls back to the phone passcode when Face ID isn't set up or fails
        ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                if success { call.resolve(["success": true]) }
                else { call.resolve(["success": false, "error": error?.localizedDescription ?? "Not unlocked"]) }
            }
        }
    }
}
