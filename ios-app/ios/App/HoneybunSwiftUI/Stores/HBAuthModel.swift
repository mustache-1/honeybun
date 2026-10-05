import SwiftUI
import AuthenticationServices

// The state behind the native sign-in screens. Each action calls the real backend (HBAuthAPI) and, once the backend has set the
// `__Host-hb` session cookie, hands over to HBAppStore.didAuthenticate(), which loads the account and opens the app.
@available(iOS 15.0, *)
@MainActor final class HBAuthModel: ObservableObject {
    enum Screen: Equatable { case welcome, login, signup, forgot, recover, reset, recoveryCode(String), verifyEmail }
    enum IDMode: String { case username = "Username", email = "Email" }

    @Published var screen: Screen = .welcome
    @Published var busy = false
    @Published var error: String?
    @Published var info: String?

    // login
    @Published var who = ""
    @Published var password = ""
    // sign up
    @Published var name = ""
    @Published var idMode: IDMode = .username
    @Published var identifier = ""
    @Published var signupPassword = ""
    @Published var inviteCode = ""
    // forgot / recover / reset
    @Published var forgotEmail = ""
    @Published var recoverUser = ""
    @Published var recoverCode = ""
    @Published var recoverPassword = ""
    @Published var resetLink = ""
    @Published var resetPassword = ""
    @Published var resetPassword2 = ""
    // recovery-code screen
    @Published var savedCode = false
    @Published var copied = false

    private var appleNonce = ""
    private var afterRecovery: Screen? = nil          // where to go once the recovery code was saved
    let store: HBAppStore
    init(store: HBAppStore) { self.store = store }

    func go(_ s: Screen) { error = nil; info = nil; screen = s }

    /// A link from an email or an invite opened the app while signed out.
    func consume(_ link: HBDeepLink?) async {
        guard let link = link else { return }
        store.pendingLink = nil
        switch link {
        case .referral: go(.signup); info = nil          // the code is already remembered; the sign-up screen says a friend invited them
        case let .reset(t): resetLink = t; go(.reset)
        case let .join(c): inviteCode = c; go(.signup); info = "Invite code added. Create an account to join."
        case let .verify(t):
            go(.login)
            await run { try await HBAPI.shared.verifyEmail(token: t); info = "Email confirmed. Log in to continue." }
        }
    }

    private func run(_ work: () async throws -> Void) async {
        busy = true; error = nil; info = nil
        defer { busy = false }
        do { try await work() } catch let e as HBPlatformAuthError { if let m = e.errorDescription { error = m } }
        catch { self.error = error.localizedDescription }
    }

    /// the backend has set the session: join the invite household if one was typed, then open the app
    private func signedIn() async {
        let code = HBAuthText.inviteCode(inviteCode)
        if !code.isEmpty {
            do { try await HBAPI.shared.joinBudget(code: code) } catch { store.notice = error.localizedDescription }   // shown on the next screen; the account is fine
        }
        await store.didAuthenticate()
    }

    // MARK: username / email + password

    func login() async {
        let w = who.trimmingCharacters(in: .whitespaces)
        guard !w.isEmpty else { error = "Enter your email or username."; return }
        guard !password.isEmpty else { error = "Enter your password."; return }
        await run { try await HBAPI.shared.login(who: w, password: password); password = ""; await signedIn() }
    }

    private var signupDraft: HBSignupDraft {
        var d = HBSignupDraft()
        d.name = name.trimmingCharacters(in: .whitespaces)
        d.id = idMode == .username ? .username(identifier) : .email(identifier)
        d.password = signupPassword
        return d
    }

    func signup(passkeyOnly: Bool = false) async {
        var d = signupDraft; d.passkeyOnly = passkeyOnly
        d.ref = HBReferral.pending()                          // a friend's link: the code goes with the sign-up
        if let p = HBAuthText.signupProblem(d) { error = p; return }
        await run {
            let code = try await HBAPI.shared.signup(d)
            HBReferral.clear()                                // used: the account exists now
            signupPassword = ""
            if passkeyOnly { await addPasskeyRightAfterSignup() }
            await afterAccountCreated(recoveryCode: code)
        }
    }
    /// passkey-first sign-up: the account exists (no password), so register this iPhone's passkey for it right away
    private func addPasskeyRightAfterSignup() async {
        do {
            let o = try await HBAPI.shared.passkeyRegistrationOptions()
            let reg = try await HBPasskeyService.shared.register(o)
            try await HBAPI.shared.registerPasskey(reg, name: UIDevice.current.name)
        } catch {
            store.notice = "Account made. You can add a passkey later in Account."
        }
    }
    private func afterAccountCreated(recoveryCode: String?) async {
        let next: Screen? = idMode == .email ? .verifyEmail : nil
        if let code = recoveryCode { afterRecovery = next; savedCode = false; copied = false; screen = .recoveryCode(code) }
        else if let n = next { screen = n }
        else { await signedIn() }
    }
    /// the recovery code was saved (or the email notice read): carry on
    func continueAfterCodes() async {
        if case .recoveryCode = screen, let n = afterRecovery { afterRecovery = nil; screen = n; return }
        await signedIn()
    }

    // MARK: Sign in with Apple

    func prepareApple(_ request: ASAuthorizationAppleIDRequest) {
        appleNonce = HBAppleNonce.makeRaw()
        request.requestedScopes = [.fullName, .email]
        request.nonce = HBAppleNonce.sha256Hex(appleNonce)
    }
    func finishApple(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case let .failure(e):
            if let a = e as? ASAuthorizationError, a.code == .canceled { return }
            error = "Sign in with Apple didn't work. Try again."
        case let .success(auth):
            guard let cred = auth.credential as? ASAuthorizationAppleIDCredential, let apple = HBAppleCredential(cred, rawNonce: appleNonce) else { error = "Sign in with Apple didn't return what Honeybun needs. Try again."; return }
            await run {
                let r = try await HBAPI.shared.appleSignIn(identityToken: apple.identityToken, rawNonce: apple.rawNonce, name: apple.fullName, ref: HBReferral.pending())
                if r.created { HBReferral.clear() }               // a new account used the friend's code (an existing one ignores it)
                await signedIn()
            }
        }
    }

    // MARK: passkey

    func passkeyLogin() async {
        await run {
            let ceremony = try await HBAPI.shared.passkeyLoginOptions()
            let assertion = try await HBPasskeyService.shared.assertion(ceremony)
            try await HBAPI.shared.passkeyLogin(assertion)
            await signedIn()
        }
    }

    // MARK: forgotten password

    func sendResetEmail() async {
        let e = forgotEmail.trimmingCharacters(in: .whitespaces)
        guard !e.isEmpty else { error = "Enter your email."; return }
        await run { try await HBAPI.shared.forgotPassword(email: e); info = "If there's an account for that email, a reset link is on its way. It works for 1 hour." }
    }
    func recover() async {
        let u = recoverUser.trimmingCharacters(in: .whitespaces), c = recoverCode.trimmingCharacters(in: .whitespaces)
        guard !u.isEmpty, !c.isEmpty else { error = "Enter your username and recovery code."; return }
        guard HBAuthText.validPassword(recoverPassword) else { error = HBAuthText.passwordRule; return }
        await run {
            let newCode = try await HBAPI.shared.recoverPassword(username: u, code: c, password: recoverPassword)
            recoverPassword = ""; recoverCode = ""
            if let n = newCode { afterRecovery = nil; savedCode = false; copied = false; screen = .recoveryCode(n) } else { await signedIn() }
        }
    }
    func reset() async {
        let t = HBAuthText.token(from: resetLink)
        guard !t.isEmpty else { error = "Paste the reset link from your email."; return }
        guard HBAuthText.validPassword(resetPassword) else { error = HBAuthText.passwordRule; return }
        guard resetPassword == resetPassword2 else { error = "The two passwords don't match."; return }
        await run { try await HBAPI.shared.resetPassword(token: t, password: resetPassword); resetPassword = ""; resetPassword2 = ""; await signedIn() }
    }

    // MARK: email

    func resendVerification() async {
        await run { try await HBAPI.shared.resendVerification(); info = "Sent. Check your inbox (and spam)." }
    }
}
