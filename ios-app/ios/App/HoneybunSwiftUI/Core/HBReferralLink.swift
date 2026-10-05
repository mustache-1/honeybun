import Foundation

// Two small things the referral system needs from the phone.
//
// 1. The friend's link (honeybun.me/r/CODE) is remembered for 60 days until they sign up, exactly like the website does ("hb-ref"), so the code
//    survives going through Welcome → Create account (or Sign in with Apple) and reaches the existing referral system with the sign-up.
// 2. A stable id for this install, sent as `x-hb-device` on every request (the website sends one from the browser). The backend uses it, with its
//    own cookie, to tell when a "new friend" is really on the referrer's own phone, so native sign-ups can't dodge that rule.

enum HBDevice {
    static let key = "hb-device"
    private static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
    static func isValid(_ s: String) -> Bool {
        s.count >= 16 && s.count <= 64 && s.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }
    }
    /// created the first time it is asked for, then kept
    static func id(_ d: UserDefaults = .standard) -> String {
        if let s = d.string(forKey: key), isValid(s) { return s }
        let new = String((0..<22).map { _ in alphabet[Int.random(in: 0..<alphabet.count)] })
        d.set(new, forKey: key)
        return new
    }
}

enum HBReferral {
    static let key = "hb-ref"
    static let keepDays: Double = 60

    /// the code in a friend's link: honeybun.me/r/CODE (4–16 letters or numbers)
    static func code(from url: URL) -> String? {
        guard let h = url.host?.lowercased(), h == "honeybun.me" || h == "www.honeybun.me" else { return nil }
        let parts = url.path.split(separator: "/").map(String.init)
        guard parts.count == 2, parts[0] == "r" else { return nil }
        return clean(parts[1])
    }
    static func clean(_ raw: String) -> String? {
        let ok = raw.count >= 4 && raw.count <= 16 && raw.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }
        return ok ? raw.uppercased() : nil
    }

    static func remember(_ code: String, now: Date = Date(), _ d: UserDefaults = .standard) {
        guard let c = clean(code) else { return }
        d.set(["c": c, "t": now.timeIntervalSince1970] as [String: Any], forKey: key)
    }
    /// the code to send with a sign-up, while it is still fresh
    static func pending(now: Date = Date(), _ d: UserDefaults = .standard) -> String? {
        guard let o = d.dictionary(forKey: key), let c = o["c"] as? String, let t = o["t"] as? Double else { return nil }
        return now.timeIntervalSince1970 - t < keepDays * 86400 ? c : nil
    }
    static func clear(_ d: UserDefaults = .standard) { d.removeObject(forKey: key) }
}
