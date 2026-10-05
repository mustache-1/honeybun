import Foundation

// The widget and Siri shortcuts read THIS PHONE'S token (made by honeybun.me, shared through the App Group) instead of a login. It is what ties
// them to one account, so native Honeybun, which now owns login, keeps it exactly in step with the session:
//   sign in  → make a token if the phone has none
//   log out  → revoke it on the server first (so a copy of it can never be used again), then forget it on the phone and redraw the widget
// Foundation only, so it is checked on macOS with the real API calls.
enum HBDeviceToken {
    /// the app sets this to redraw the widget whenever the token changes
    static var onChange: () -> Void = {}

    /// signed in: make this phone's token if it has none
    static func ensure() async {
        guard Honeybun.token == nil else { return }
        guard let data = try? await HBAPI.shared.send("/api/app/token", method: "POST", body: [:]),
              let tok = ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any])?["token"] as? String, !tok.isEmpty else { return }
        Honeybun.token = tok
        onChange()
    }
    /// log out, step 1 (needs the session): remove this account's phone tokens on the server
    static func revokeOnServer() async { _ = try? await HBAPI.shared.send("/api/app/token", method: "DELETE", body: nil) }
    /// log out, step 2: nothing of the account stays on the phone
    static func clearLocal() { Honeybun.token = nil; onChange() }
}
