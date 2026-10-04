import Foundation
import WebKit

// The existing Honeybun login lives in the website's cookie (`__Host-hb`, HttpOnly + Secure), which the Capacitor web view keeps in
// WKWebsiteDataStore. URLSession has its own cookie jar, so the native screens copy honeybun.me's cookies across before they call
// the API. This is the SAME session the website uses: no second login, no stored password, nothing hard-coded. If there is no
// session (signed out in the web view), the native screens say so and send you back to the classic app to sign in.
enum HBSession {
    static let host = "honeybun.me"

    /// Copies every honeybun.me cookie from the web view's store into the shared URLSession store. Returns how many were copied.
    @MainActor @discardableResult
    static func syncFromWebView() async -> Int {
        let store = WKWebsiteDataStore.default().httpCookieStore
        let cookies: [HTTPCookie] = await withCheckedContinuation { cont in
            store.getAllCookies { cont.resume(returning: $0) }
        }
        var n = 0
        for c in cookies where c.domain == host || c.domain == "." + host || c.domain.hasSuffix("." + host) {
            if let exp = c.expiresDate, exp < Date() { continue }
            HTTPCookieStorage.shared.setCookie(c)
            n += 1
        }
        return n
    }

    static var hasSessionCookie: Bool {
        guard let url = URL(string: "https://" + host) else { return false }
        return (HTTPCookieStorage.shared.cookies(for: url) ?? []).contains { $0.name == "__Host-hb" && !$0.value.isEmpty }
    }
}
