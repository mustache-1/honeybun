import Foundation
import Security
import WebKit

// Native Honeybun owns its login. Every sign-in method (password, passkey, Apple, recovery code, password reset) makes the backend set the
// `__Host-hb` session cookie (HttpOnly + Secure, 30 days). URLSession puts it in the shared cookie store, which iOS keeps across launches.
// Two extras make that robust:
//  - the cookie value is also kept in the Keychain, and put back if the cookie store was ever emptied
//  - after a native login the cookie is copied into the web view too, so the Classic app (still available as a fallback) is signed in as well
// Native screens no longer need Classic to sign in, and nothing here reads Classic's session.
enum HBSession {
    static let host = "honeybun.me"
    static let cookieName = "__Host-hb"
    private static let keychainAccount = "me.honeybun.session"

    static var url: URL { URL(string: "https://" + host)! }
    static var sessionCookie: HTTPCookie? {
        (HTTPCookieStorage.shared.cookies(for: url) ?? []).first { $0.name == cookieName && !$0.value.isEmpty }
    }
    static var hasSessionCookie: Bool { sessionCookie != nil }

    // MARK: Keychain copy of the session

    static func saveToKeychain() {
        guard let c = sessionCookie else { return }
        let value = Data(c.value.utf8)
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "honeybun", kSecAttrAccount as String: keychainAccount]
        SecItemDelete(q as CFDictionary)
        var add = q
        add[kSecValueData as String] = value
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }
    static func keychainValue() -> String? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "honeybun", kSecAttrAccount as String: keychainAccount,
                                kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }
    /// If the cookie store lost the session (but the Keychain still has it), put it back. Returns true when a cookie is available afterwards.
    @discardableResult static func restore() -> Bool {
        if hasSessionCookie { return true }
        guard let v = keychainValue(), !v.isEmpty else { return false }
        let props: [HTTPCookiePropertyKey: Any] = [.name: cookieName, .value: v, .domain: host, .path: "/", .secure: "TRUE", .expires: Date().addingTimeInterval(29 * 86400)]
        guard let c = HTTPCookie(properties: props) else { return false }
        HTTPCookieStorage.shared.setCookie(c)
        return true
    }
    private static func clearKeychain() {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "honeybun", kSecAttrAccount as String: keychainAccount]
        SecItemDelete(q as CFDictionary)
    }

    // MARK: after a login / logout

    /// Call after any successful sign-in: remember the session and share it with the Classic web view.
    @MainActor static func didSignIn() async {
        saveToKeychain()
        await mirrorToWebView()
    }
    /// Copies the native session cookie into the web view's store so the Classic app is signed in too.
    @MainActor static func mirrorToWebView() async {
        guard let c = sessionCookie else { return }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            WKWebsiteDataStore.default().httpCookieStore.setCookie(c) { cont.resume() }
        }
    }
    /// Forget the session everywhere on this phone (native cookie store, Keychain, and the web view's copy).
    @MainActor static func clearEverywhere() async {
        for c in HTTPCookieStorage.shared.cookies(for: url) ?? [] where c.name == cookieName { HTTPCookieStorage.shared.deleteCookie(c) }
        clearKeychain()
        let store = WKWebsiteDataStore.default().httpCookieStore
        let cookies: [HTTPCookie] = await withCheckedContinuation { cont in store.getAllCookies { cont.resume(returning: $0) } }
        for c in cookies where c.name == cookieName { await withCheckedContinuation { (k: CheckedContinuation<Void, Never>) in store.delete(c) { k.resume() } } }
    }
}
