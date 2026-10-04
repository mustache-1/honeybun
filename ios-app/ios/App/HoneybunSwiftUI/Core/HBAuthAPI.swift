import Foundation

// Everything the native sign-in screens ask the backend, using the backend's REAL rules:
//  - the normal credential is a USERNAME (the backend stores it as username@u.honeybun.invalid); an email also works in the same field
//  - sign-up needs a name, a password of 8+ characters and EITHER a username OR an email
//  - a username account gets a recovery code (shown once); an email account gets a verification email
//  - one session cookie (`__Host-hb`), set by every login method: password, passkey, Apple, recovery code, password reset

enum HBSignupID: Equatable { case username(String), email(String) }

struct HBSignupDraft {
    var name = ""
    var id: HBSignupID = .username("")
    var password = ""
    var passkeyOnly = false
    var json: [String: Any] {
        var d: [String: Any] = ["name": name, "lang": "en"]
        switch id {
        case let .username(u): d["username"] = u.trimmingCharacters(in: .whitespaces).lowercased()
        case let .email(e): d["email"] = e.trimmingCharacters(in: .whitespaces)
        }
        if passkeyOnly { d["passkey"] = true } else { d["password"] = password }
        return d
    }
}

struct HBAppleSignInResult { let created: Bool }

extension HBAPI {
    // MARK: signing in

    /// `who` is a username or an email, exactly like the website's login box
    func login(who: String, password: String) async throws {
        _ = try await send("/api/login", method: "POST", body: ["email": who.trimmingCharacters(in: .whitespaces), "password": password], unauth: true)
    }
    /// returns the recovery code (username accounts only; show it once)
    func signup(_ d: HBSignupDraft) async throws -> String? {
        let data = try await send("/api/signup", method: "POST", body: d.json, unauth: true)
        return ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any])?["recovery_code"] as? String
    }
    func appleSignIn(identityToken: String, rawNonce: String, name: String?) async throws -> HBAppleSignInResult {
        var body: [String: Any] = ["identity_token": identityToken, "nonce": rawNonce, "lang": "en"]
        if let n = name, !n.isEmpty { body["name"] = n }
        let data = try await send("/api/auth/apple", method: "POST", body: body, unauth: true)
        let created = (((try? JSONSerialization.jsonObject(with: data)) as? [String: Any])?["created"] as? Bool) ?? false
        return HBAppleSignInResult(created: created)
    }
    func logout() async throws { _ = try await send("/api/logout", method: "POST", body: nil, unauth: true) }

    // MARK: forgotten passwords

    func forgotPassword(email: String) async throws { _ = try await send("/api/password/forgot", method: "POST", body: ["email": email], unauth: true) }
    func resetPassword(token: String, password: String) async throws { _ = try await send("/api/password/reset", method: "POST", body: ["token": token, "password": password], unauth: true) }
    /// returns the NEW recovery code (the old one stops working)
    func recoverPassword(username: String, code: String, password: String) async throws -> String? {
        let data = try await send("/api/password/recover", method: "POST", body: ["username": username, "code": code, "password": password], unauth: true)
        return ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any])?["recovery_code"] as? String
    }

    // MARK: email

    func resendVerification() async throws { _ = try await send("/api/email/resend", method: "POST", body: nil) }
    func verifyEmail(token: String) async throws { _ = try await send("/api/email/verify", method: "POST", body: ["token": token], unauth: true) }

    // MARK: passkeys

    func passkeyLoginOptions() async throws -> HBPasskeyCeremony {
        let data = try await send("/api/passkeys/login/options", method: "POST", body: nil, unauth: true)
        guard let o = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any], let c = (o["challenge"] as? String).flatMap(HBBase64URL.decode), let rp = o["rpId"] as? String else { throw HBAPIError.decoding("passkey options") }
        return HBPasskeyCeremony(challenge: c, rpId: rp)
    }
    func passkeyLogin(_ a: HBPasskeyAssertion) async throws {
        _ = try await send("/api/passkeys/login", method: "POST", body: ["id": HBBase64URL.encode(a.credentialID), "clientDataJSON": HBBase64URL.encode(a.clientDataJSON),
                                                                            "authenticatorData": HBBase64URL.encode(a.authenticatorData), "signature": HBBase64URL.encode(a.signature)], unauth: true)
    }
    func passkeyRegistrationOptions() async throws -> HBPasskeyRegistrationOptions {
        let data = try await send("/api/passkeys/options", method: "POST", body: nil)
        guard let o = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any], let c = (o["challenge"] as? String).flatMap(HBBase64URL.decode),
              let rp = (o["rp"] as? [String: Any])?["id"] as? String, let u = o["user"] as? [String: Any], let uid = (u["id"] as? String).flatMap(HBBase64URL.decode) else { throw HBAPIError.decoding("passkey options") }
        return HBPasskeyRegistrationOptions(challenge: c, rpId: rp, userID: uid, userName: u["name"] as? String ?? "", displayName: u["displayName"] as? String ?? "")
    }
    func registerPasskey(_ r: HBPasskeyRegistration, name: String) async throws {
        let p = try HBPasskeyKit.parseAttestation(r.attestationObject)
        _ = try await send("/api/passkeys", method: "POST", body: ["id": HBBase64URL.encode(r.credentialID), "publicKey": HBBase64URL.encode(p.spki), "alg": p.alg,
                                                                   "clientDataJSON": HBBase64URL.encode(r.clientDataJSON), "authenticatorData": HBBase64URL.encode(p.authData), "name": name])
    }
    func passkeys() async throws -> [HBPasskeyInfo] { let l: HBPasskeyList = try decode(try await send("/api/passkeys", method: "GET", body: nil)); return l.passkeys }
    func renamePasskey(id: String, name: String) async throws { _ = try await send("/api/passkeys/" + (id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id), method: "PATCH", body: ["name": name]) }
    func deletePasskey(id: String) async throws { _ = try await send("/api/passkeys/" + (id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id), method: "DELETE", body: nil) }

    // MARK: account

    func newRecoveryCode() async throws -> String {
        let data = try await send("/api/recovery/new", method: "POST", body: nil)
        return (((try? JSONSerialization.jsonObject(with: data)) as? [String: Any])?["recovery_code"] as? String) ?? ""
    }
    func changePassword(current: String, new: String) async throws { _ = try await send("/api/password/change", method: "POST", body: ["current": current, "password": new]) }
    /// the whole account as the JSON file the website downloads
    func exportAccount() async throws -> Data { try await send("/api/account/export", method: "GET", body: nil) }
    /// `password` for accounts that have one; `confirm: "DELETE"` for Apple / passkey accounts (right after a fresh login); `appleCode` lets the backend revoke the Apple link
    func deleteAccount(password: String?, confirm: String?, appleAuthorizationCode: String?) async throws {
        var body: [String: Any] = [:]
        if let p = password { body["password"] = p }
        if let c = confirm { body["confirm"] = c }
        if let a = appleAuthorizationCode { body["apple_authorization_code"] = a }
        _ = try await send("/api/account/delete", method: "POST", body: body)
    }

    // MARK: first budget

    func createBudget(name: String, kind: String) async throws { _ = try await send("/api/nests", method: "POST", body: ["name": name, "kind": kind]) }
    func joinBudget(code: String) async throws { _ = try await send("/api/nests/join", method: "POST", body: ["code": code]) }
    func finishSetup() async throws { _ = try await send("/api/setup/done", method: "POST", body: nil) }
    func authConfigApple() async -> Bool {
        guard let d = try? await send("/api/auth/config", method: "GET", body: nil, unauth: true) else { return false }
        return (((try? JSONSerialization.jsonObject(with: d)) as? [String: Any])?["apple"] as? Bool) ?? false
    }
}

// Small pure helpers the sign-in screens use (tested on macOS)
enum HBAuthText {
    /// the token from a pasted emailed link ("https://honeybun.me/reset/TOKEN?x=1", "…/verify/TOKEN") or a bare token
    static func token(from pasted: String) -> String {
        var t = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
        if let q = t.firstIndex(where: { $0 == "?" || $0 == "#" }) { t = String(t[..<q]) }
        if t.contains("/") { t = String(t.split(separator: "/").last ?? "") }
        return t
    }
    /// invite codes are shown as ABCD-EFGH; the backend ignores dashes and case
    static func inviteCode(_ s: String) -> String { s.uppercased().filter { $0.isLetter || $0.isNumber } }
    static func prettyRecoveryCode(_ s: String) -> String { s }
    static let passwordRule = "Use a password with at least 8 characters."
    static func validPassword(_ s: String) -> Bool { s.count >= 8 }
    /// the message under a signup field, or nil when it's fine
    static func signupProblem(_ d: HBSignupDraft) -> String? {
        if d.name.trimmingCharacters(in: .whitespaces).isEmpty { return "Enter your name." }
        switch d.id {
        case let .username(u): if u.trimmingCharacters(in: .whitespaces).isEmpty { return "Pick a username." }
        case let .email(e): if e.trimmingCharacters(in: .whitespaces).isEmpty { return "Enter your email." }
        }
        if !d.passkeyOnly && !validPassword(d.password) { return passwordRule }
        return nil
    }
}
