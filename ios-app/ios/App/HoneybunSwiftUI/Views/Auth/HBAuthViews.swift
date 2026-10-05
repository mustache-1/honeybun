import SwiftUI
import AuthenticationServices

// MARK: - shared pieces

@available(iOS 15.0, *)
struct HBAuthScaffold<Content: View>: View {
    var title: String? = nil
    var subtitle: String? = nil
    var onBack: (() -> Void)? = nil
    @ViewBuilder var content: Content
    var body: some View {
        ZStack {
            HBBackground(glow: true, scene: false)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let onBack = onBack {
                        Button(action: onBack) { Image(systemName: "arrow.left").font(.system(size: 20, weight: .medium)).foregroundColor(.white).frame(width: 44, height: 44) }
                            .accessibilityLabel("Back").accessibilityIdentifier("hb-auth-back")
                    }
                    if let title = title {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(title).font(.system(size: 32, weight: .bold)).foregroundColor(.white)
                            if let subtitle = subtitle { Text(subtitle).font(.system(size: 16)).foregroundColor(Color(red: 0.74, green: 0.69, blue: 0.9)).fixedSize(horizontal: false, vertical: true) }
                        }
                    }
                    content
                }
                .frame(maxWidth: 560).padding(.horizontal, HB.gutter).padding(.top, 8).padding(.bottom, 32)
                .frame(maxWidth: .infinity)
            }
        }
        .toolbar { ToolbarItemGroup(placement: .keyboard) { Spacer(); Button("Done") { hbHideKeyboard() } } }
    }
}

@available(iOS 15.0, *)
struct HBAuthField: View {
    let label: String
    var placeholder = ""
    @Binding var text: String
    var secure = false
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    var capitalize = false
    var id: String
    @State private var reveal = false
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.footnote.weight(.semibold)).foregroundColor(HB.soft)
            HStack(spacing: 8) {
                Group {
                    if secure && !reveal { SecureField("", text: $text) } else { TextField("", text: $text) }
                }
                .textContentType(contentType).keyboardType(keyboard)
                .textInputAutocapitalization(capitalize ? .words : .never).autocorrectionDisabled()
                .font(.system(size: 18)).foregroundColor(.white)
                .overlay(alignment: .leading) { if text.isEmpty { Text(placeholder).font(.system(size: 18)).foregroundColor(Color.white.opacity(0.4)).allowsHitTesting(false) } }
                .accessibilityIdentifier(id)
                if secure {
                    Button { reveal.toggle() } label: { Image(systemName: reveal ? "eye.slash" : "eye").foregroundColor(HB.soft).frame(width: 36, height: 36) }
                        .accessibilityLabel(reveal ? "Hide password" : "Show password")
                }
            }
            .padding(.horizontal, 16).frame(minHeight: 54)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.14), lineWidth: 1))
        }
    }
}

@available(iOS 15.0, *)
struct HBAuthNote: View {
    let error: String?
    let info: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let e = error { Text(e).font(.system(size: 15, weight: .semibold)).foregroundColor(HB.red).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("hb-auth-error") }
            if let i = info { Text(i).font(.system(size: 15, weight: .semibold)).foregroundColor(HB.green).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("hb-auth-info") }
        }
    }
}

@available(iOS 15.0, *)
struct HBAuthLink: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) { Text(title).font(.system(size: 16, weight: .semibold)).foregroundColor(Color(red: 0.72, green: 0.68, blue: 0.9)).frame(maxWidth: .infinity, minHeight: 44) }
    }
}

@available(iOS 15.0, *)
struct HBAppleButton: View {
    @ObservedObject var model: HBAuthModel
    var body: some View {
        SignInWithAppleButton(.continue, onRequest: { model.prepareApple($0) }, onCompletion: { r in Task { await model.finishApple(r) } })
            .signInWithAppleButtonStyle(.white).frame(height: 54).clipShape(Capsule())
            .accessibilityIdentifier("hb-auth-apple")
    }
}

// MARK: - the flow

@available(iOS 15.0, *)
struct HBAuthFlowView: View {
    @ObservedObject var store: HBAppStore
    let onClose: () -> Void
    @StateObject private var model: HBAuthModel

    init(store: HBAppStore, onClose: @escaping () -> Void) {
        self.store = store; self.onClose = onClose
        _model = StateObject(wrappedValue: HBAuthModel(store: store))
    }

    var body: some View {
        Group {
            switch model.screen {
            case .welcome: welcome
            case .login: login
            case .signup: signup
            case .forgot: forgot
            case .recover: recover
            case .reset: reset
            case let .recoveryCode(code): recoveryCode(code)
            case .verifyEmail: verifyEmail
            }
        }
        .task { await model.consume(store.pendingLink) }
        .onChange(of: store.pendingLink) { link in Task { await model.consume(link) } }
        #if DEBUG
        .onAppear { applyPreviewScreen() }
        #endif
    }

    #if DEBUG
    private func applyPreviewScreen() {
        guard let s = store.previewAuthScreen else { return }
        switch s {
        case "login": model.screen = .login
        case "loginerror": model.screen = .login; model.who = "una"; model.password = "wrong"; model.error = "Wrong email, username or password."
        case "signup": model.screen = .signup
        case "signuperror": model.screen = .signup; model.name = "Una"; model.identifier = "una"; model.error = "That username is taken. Try another one."
        case "signupemail": model.screen = .signup; model.idMode = .email
        case "forgot": model.screen = .forgot
        case "forgotsent": model.screen = .forgot; model.forgotEmail = "una@example.com"; model.info = "If there's an account for that email, a reset link is on its way. It works for 1 hour."
        case "recover": model.screen = .recover
        case "reset": model.screen = .reset
        case "recoverycode": model.screen = .recoveryCode("K7QM-4X2P-WD9R")
        case "verify": model.screen = .verifyEmail
        default: model.screen = .welcome
        }
    }
    #endif

    // MARK: Welcome — Apple and Passkey first, username below

    private var welcome: some View {
        ZStack {
            HBBackground(glow: true, scene: true)
            ScrollView {
                VStack(spacing: 18) {
                    Spacer(minLength: 20)
                    Image("HBHero").resizable().scaledToFit().frame(width: 200).accessibilityHidden(true)
                    VStack(spacing: 8) {
                        HBWordmark(size: 46).onLongPressGesture(minimumDuration: 1.5) { onClose() }   // emergency way to Classic; new users never see it
                        Text("A happier way to manage money together.").font(.system(size: 17)).foregroundColor(Color(red: 0.74, green: 0.69, blue: 0.9)).multilineTextAlignment(.center)
                    }
                    Spacer(minLength: 16)
                    VStack(spacing: 12) {
                        HBAppleButton(model: model)
                        if HBPasskeyService.isAvailable {
                            Button { Task { await model.passkeyLogin() } } label: {
                                HStack(spacing: 10) { Image(systemName: "person.badge.key.fill"); Text("Log in with Passkey") }
                                    .font(.system(size: 17, weight: .bold)).foregroundColor(HB.orange).frame(maxWidth: .infinity, minHeight: 54)
                                    .background(Capsule().fill(Color.white.opacity(0.05))).overlay(Capsule().stroke(HB.orange.opacity(0.7), lineWidth: 1.5))
                            }
                            .disabled(model.busy).accessibilityIdentifier("hb-auth-passkey")
                        }
                        HStack { Rectangle().fill(Color.white.opacity(0.14)).frame(height: 1); Text("or").font(.footnote).foregroundColor(HB.soft); Rectangle().fill(Color.white.opacity(0.14)).frame(height: 1) }
                        HBAuthLink(title: "Log in with username") { model.go(.login) }.accessibilityIdentifier("hb-auth-username")
                        HBAuthNote(error: model.error, info: model.info)
                        HStack(spacing: 4) {
                            Text("New to Honeybun?").foregroundColor(HB.soft)
                            Button("Create account") { model.go(.signup) }.foregroundColor(HB.orange).font(.system(size: 16, weight: .bold)).accessibilityIdentifier("hb-auth-create")
                        }
                        .font(.system(size: 16))
                    }
                    .frame(maxWidth: 420)
                }
                .padding(.horizontal, HB.gutter).padding(.bottom, 28).frame(maxWidth: .infinity)
            }
            if model.busy { ProgressView().tint(HB.orange).scaleEffect(1.3).padding(24).background(RoundedRectangle(cornerRadius: 16).fill(Color.black.opacity(0.6))) }
        }
    }

    // MARK: Log in

    private var login: some View {
        HBAuthScaffold(title: "Log in", subtitle: "Use your username (or the email you signed up with).", onBack: { model.go(.welcome) }) {
            HBAuthField(label: "Username or email", placeholder: "yourname", text: $model.who, keyboard: .emailAddress, contentType: .username, id: "hb-login-who")
            HBAuthField(label: "Password", text: $model.password, secure: true, contentType: .password, id: "hb-login-password")
            HBAuthNote(error: model.error, info: model.info)
            HBPillButton(title: model.busy ? "Logging in…" : "Log in") { hbHideKeyboard(); Task { await model.login() } }.disabled(model.busy).accessibilityIdentifier("hb-login-submit")
            HBAuthLink(title: "Forgot password?") { model.forgotEmail = model.who.contains("@") ? model.who : ""; model.recoverUser = model.who.contains("@") ? "" : model.who; model.go(model.who.isEmpty || model.who.contains("@") ? .forgot : .recover) }
                .accessibilityIdentifier("hb-login-forgot")
            if HBPasskeyService.isAvailable { HBAuthLink(title: "Log in with Passkey instead") { Task { await model.passkeyLogin() } } }
        }
    }

    // MARK: Create account

    private var signup: some View {
        HBAuthScaffold(title: "Create account", subtitle: "Start your budget. It takes about a minute.", onBack: { model.go(.welcome) }) {
            HBAuthField(label: "Your name", placeholder: "What should we call you?", text: $model.name, contentType: .givenName, capitalize: true, id: "hb-signup-name")
            HStack(spacing: 0) {
                ForEach([HBAuthModel.IDMode.username, .email], id: \.self) { m in
                    Button { model.idMode = m; model.identifier = "" } label: {
                        Text(m.rawValue).font(.system(size: 15, weight: .semibold)).foregroundColor(model.idMode == m ? Color.black.opacity(0.85) : Color(red: 0.74, green: 0.69, blue: 0.9))
                            .frame(maxWidth: .infinity, minHeight: 38).background(Capsule().fill(model.idMode == m ? HB.orange : Color.clear))
                    }
                    .accessibilityAddTraits(model.idMode == m ? .isSelected : []).accessibilityIdentifier("hb-signup-mode-\(m.rawValue.lowercased())")
                }
            }
            .padding(4).background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.white.opacity(0.05)))
            if model.idMode == .username {
                HBAuthField(label: "Username", placeholder: "Pick a username", text: $model.identifier, contentType: .username, id: "hb-signup-identifier")
                Text("3 to 20 letters, numbers, dots, dashes or underscores. No email needed: you'll get a recovery code to save instead.").font(.footnote).foregroundColor(HB.soft)
            } else {
                HBAuthField(label: "Email", placeholder: "you@example.com", text: $model.identifier, keyboard: .emailAddress, contentType: .emailAddress, id: "hb-signup-identifier")
                Text("We'll send a link to confirm it. You can reset your password by email.").font(.footnote).foregroundColor(HB.soft)
            }
            HBAuthField(label: "Password", placeholder: "At least 8 characters", text: $model.signupPassword, secure: true, contentType: .newPassword, id: "hb-signup-password")
            DisclosureGroup {
                HBAuthField(label: "Invite code", placeholder: "ABCD-EFGH", text: $model.inviteCode, capitalize: false, id: "hb-signup-invite")
                    .padding(.top, 8)
            } label: { Text("Have an invite code?").font(.system(size: 16, weight: .semibold)).foregroundColor(.white) }
                .tint(HB.orange).accessibilityIdentifier("hb-signup-invite-toggle")
            HBAuthNote(error: model.error, info: model.info)
            HBPillButton(title: model.busy ? "Creating…" : "Create my budget") { hbHideKeyboard(); Task { await model.signup() } }.disabled(model.busy).accessibilityIdentifier("hb-signup-submit")
            if HBPasskeyService.isAvailable {
                HBAuthLink(title: "Use a passkey instead of a password") { hbHideKeyboard(); Task { await model.signup(passkeyOnly: true) } }.accessibilityIdentifier("hb-signup-passkey")
            }
            HStack { Rectangle().fill(Color.white.opacity(0.14)).frame(height: 1); Text("or").font(.footnote).foregroundColor(HB.soft); Rectangle().fill(Color.white.opacity(0.14)).frame(height: 1) }
            HBAppleButton(model: model)
            Text("By continuing you agree to the Terms and Privacy Policy at honeybun.me.").font(.footnote).foregroundColor(HB.soft).multilineTextAlignment(.center).frame(maxWidth: .infinity)
        }
    }

    // MARK: Forgot / recover / reset

    private var forgot: some View {
        HBAuthScaffold(title: "Forgot password?", subtitle: "Enter the email on your account and we'll send a reset link.", onBack: { model.go(.login) }) {
            HBAuthField(label: "Email", placeholder: "you@example.com", text: $model.forgotEmail, keyboard: .emailAddress, contentType: .emailAddress, id: "hb-forgot-email")
            HBAuthNote(error: model.error, info: model.info)
            HBPillButton(title: model.busy ? "Sending…" : "Send reset link") { hbHideKeyboard(); Task { await model.sendResetEmail() } }.disabled(model.busy).accessibilityIdentifier("hb-forgot-submit")
            HBAuthLink(title: "I have a reset link") { model.go(.reset) }.accessibilityIdentifier("hb-forgot-have-link")
            HBAuthLink(title: "No email on my account? Use my recovery code") { model.go(.recover) }.accessibilityIdentifier("hb-forgot-recover")
        }
    }

    private var recover: some View {
        HBAuthScaffold(title: "Use your recovery code", subtitle: "You got a code when you made a username account. It sets a new password and gives you a fresh code.", onBack: { model.go(.login) }) {
            HBAuthField(label: "Username", text: $model.recoverUser, contentType: .username, id: "hb-recover-user")
            HBAuthField(label: "Recovery code", placeholder: "ABCD-EFGH-JKMN", text: $model.recoverCode, id: "hb-recover-code")
            HBAuthField(label: "New password", placeholder: "At least 8 characters", text: $model.recoverPassword, secure: true, contentType: .newPassword, id: "hb-recover-password")
            HBAuthNote(error: model.error, info: model.info)
            HBPillButton(title: model.busy ? "Checking…" : "Set new password") { hbHideKeyboard(); Task { await model.recover() } }.disabled(model.busy).accessibilityIdentifier("hb-recover-submit")
        }
    }

    private var reset: some View {
        HBAuthScaffold(title: "Reset password", subtitle: "Paste the link from the email we sent (or just the code at the end of it), then choose a new password.", onBack: { model.go(.forgot) }) {
            HBAuthField(label: "Reset link", placeholder: "https://honeybun.me/reset/…", text: $model.resetLink, keyboard: .URL, id: "hb-reset-link")
            HBAuthField(label: "New password", placeholder: "At least 8 characters", text: $model.resetPassword, secure: true, contentType: .newPassword, id: "hb-reset-password")
            HBAuthField(label: "Type it again", text: $model.resetPassword2, secure: true, contentType: .newPassword, id: "hb-reset-password2")
            HBAuthNote(error: model.error, info: model.info)
            HBPillButton(title: model.busy ? "Saving…" : "Change password") { hbHideKeyboard(); Task { await model.reset() } }.disabled(model.busy).accessibilityIdentifier("hb-reset-submit")
        }
    }

    // MARK: recovery code (shown once) and email verification

    private func recoveryCode(_ code: String) -> some View {
        HBAuthScaffold(title: "Save your recovery code", subtitle: "This is the only way to get back in if you forget your password, because a username account has no email. It's shown once.") {
            VStack(spacing: 14) {
                Text(code).font(.system(size: 30, weight: .heavy, design: .monospaced)).foregroundColor(HB.orange).tracking(1).textSelection(.enabled)
                    .minimumScaleFactor(0.7).lineLimit(1).accessibilityIdentifier("hb-recovery-code")
                HBPillButton(title: model.copied ? "Copied" : "Copy code", symbol: model.copied ? "checkmark" : "doc.on.doc", filled: false) { UIPasteboard.general.string = code; model.copied = true }
                    .accessibilityIdentifier("hb-recovery-copy")
            }
            .padding(20).frame(maxWidth: .infinity).hbCard()
            Toggle(isOn: $model.savedCode) { Text("I saved it somewhere safe").font(.system(size: 17, weight: .semibold)).foregroundColor(.white) }
                .tint(HB.orange).accessibilityIdentifier("hb-recovery-saved")
            HBPillButton(title: "Continue") { Task { await model.continueAfterCodes() } }.disabled(!model.savedCode || model.busy).opacity(model.savedCode ? 1 : 0.45).accessibilityIdentifier("hb-recovery-continue")
            Text("You can make a new one any time in Account.").font(.footnote).foregroundColor(HB.soft)
        }
    }

    private var verifyEmail: some View {
        HBAuthScaffold(title: "Check your email", subtitle: "We sent a link to confirm your address. You can keep going now; confirm it whenever you like.") {
            VStack(spacing: 10) {
                Image("HBInboxTip").resizable().scaledToFit().frame(width: 130).accessibilityHidden(true)
                Text("Open the link in the email to confirm it's you. No email? Check your spam folder or send it again.").font(.system(size: 16)).foregroundColor(HB.soft).multilineTextAlignment(.center)
            }
            .padding(18).frame(maxWidth: .infinity).hbCard()
            HBAuthNote(error: model.error, info: model.info)
            HBPillButton(title: model.busy ? "Sending…" : "Send it again", filled: false) { Task { await model.resendVerification() } }.disabled(model.busy).accessibilityIdentifier("hb-verify-resend")
            HBPillButton(title: "Continue") { Task { await model.continueAfterCodes() } }.accessibilityIdentifier("hb-verify-continue")
        }
    }
}
