import Foundation

// The links Honeybun's own emails and invites contain: honeybun.me/verify/<token>, /reset/<token>, /join/<code>.
// The iPhone app opens these (Universal Links, see the AASA file the site serves) instead of Safari.
enum HBDeepLink: Equatable {
    case verify(String), reset(String), join(String), referral(String)

    /// call when a link opens the app: a referral code is remembered right away (it is needed later, at sign-up, whatever screen is showing)
    @discardableResult static func remember(_ url: URL) -> HBDeepLink? {
        let link = parse(url)
        if case let .referral(code)? = link { HBReferral.remember(code) }
        return link
    }
    static func parse(_ url: URL) -> HBDeepLink? {
        guard let host = url.host?.lowercased(), host == "honeybun.me" || host == "www.honeybun.me" else { return nil }
        if let code = HBReferral.code(from: url) { return .referral(code) }
        let parts = url.path.split(separator: "/").map(String.init)
        guard parts.count == 2, !parts[1].isEmpty else { return nil }
        switch parts[0] {
        case "verify": return .verify(parts[1])
        case "reset": return .reset(parts[1])
        case "join": return .join(parts[1])
        default: return nil
        }
    }
}
