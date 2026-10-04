import SwiftUI
import AuthenticationServices

// MARK: - Account & security (opens from Together → Household → Account & security)

@available(iOS 15.0, *)
struct HBAccountView: View {
    @ObservedObject var store: HBAppStore
    let onClose: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var passkeys: [HBPasskeyInfo] = []
    @State private var passkeysLoaded = false
    @State private var editingPasskey: String?
    @State private var passkeyName = ""
    @State private var removing: HBPasskeyInfo?
    @State private var error: String?
    @State private var info: String?
    @State private var busy = false
    @State private var confirmLogout = false
    @State private var confirmNewCode = false
    @State private var newCode: String?
    @State private var codeCopied = false
    @State private var showChangePassword = false
    @State private var showDelete = false
    @State private var verifyLink = ""
    @State private var showVerifyLink = false
    @State private var exportURL: URL?
    @State private var showShare = false

    private var user: HBUser? { store.account }
    /// the username part of username@u.honeybun.invalid, or the real email
    private var login: String {
        guard let e = user?.email else { return "" }
        return e.hasSuffix("@u.honeybun.invalid") ? String(e.dropLast("@u.honeybun.invalid".count)) : e
    }
    private var hasEmail: Bool { user?.has_email ?? false }

    var body: some View {
        HBSheetScaffold(title: "Account", onBack: { dismiss() }) {
            profileCard
            if hasEmail { emailCard }
            securityCard
            dataCard
            HBAuthNote(error: error, info: info)
            sessionCard
        }
        .task { await load() }
        #if DEBUG
        .onAppear { if (store.previewAuthScreen ?? "").hasPrefix("delete") { showDelete = true } }
        #endif
        .sheet(isPresented: $showChangePassword) { HBChangePasswordSheet() }
        .sheet(isPresented: $showDelete) { HBDeleteAccountSheet(store: store) }
        .sheet(isPresented: $showShare) { if let u = exportURL { HBActivityView(items: [u]) } }
        .confirmationDialog("Log out of Honeybun?", isPresented: $confirmLogout, titleVisibility: .visible) {
            Button("Log out", role: .destructive) { Task { await store.logout() } }
            Button("Stay", role: .cancel) {}
        } message: { Text("You can log back in with your username, a passkey or Apple.") }
        .confirmationDialog("Make a new recovery code?", isPresented: $confirmNewCode, titleVisibility: .visible) {
            Button("New code", role: .destructive) { makeCode() }
            Button("Keep my current code", role: .cancel) {}
        } message: { Text("Your old code stops working.") }
        .confirmationDialog("Remove this passkey?", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }), titleVisibility: .visible) {
            Button("Remove", role: .destructive) { if let p = removing { removePasskey(p) }; removing = nil }
            Button("Keep it", role: .cancel) { removing = nil }
        } message: { Text("You won't be able to log in with it any more. Your other ways of logging in still work.") }
    }

    // MARK: pieces

    private var profileCard: some View {
        HStack(spacing: 14) {
            if let m = store.member(store.myID) { HBMemberAvatar(member: m, size: 64) }
            VStack(alignment: .leading, spacing: 3) {
                Text(user?.name ?? "").font(.system(size: 21, weight: .bold)).foregroundColor(.white).accessibilityIdentifier("hb-account-name")
                Text(login).font(.system(size: 15)).foregroundColor(HB.soft).lineLimit(1)
                Text(signInMethod).font(.system(size: 13)).foregroundColor(HB.orange)
            }
            Spacer(minLength: 6)
            Button { store.sheet = .editMe } label: {
                Text("Edit").font(.system(size: 14, weight: .semibold)).foregroundColor(HB.orange).padding(.horizontal, 14).frame(height: 34).overlay(Capsule().stroke(HB.orange.opacity(0.55), lineWidth: 1))
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).hbCard()
    }
    private var signInMethod: String {
        if user?.apple == true { return "Signs in with Apple" }
        if user?.has_password == false { return "Signs in with a passkey" }
        return hasEmail ? "Email and password" : "Username and password"
    }

    private var emailCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Email").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
                Spacer()
                Label(user?.verified == true ? "Confirmed" : "Not confirmed", systemImage: user?.verified == true ? "checkmark.seal.fill" : "exclamationmark.circle")
                    .font(.system(size: 14, weight: .semibold)).foregroundColor(user?.verified == true ? HB.green : HB.orange).accessibilityIdentifier("hb-account-email-status")
            }
            if user?.verified != true {
                Text("Confirm your email so you can reset your password by email.").font(.footnote).foregroundColor(HB.soft)
                HBPillButton(title: busy ? "Sending…" : "Resend verification email", symbol: "envelope", filled: false) { resend() }.disabled(busy).accessibilityIdentifier("hb-account-resend")
                DisclosureGroup(isExpanded: $showVerifyLink) {
                    VStack(spacing: 10) {
                        HBAuthField(label: "Verification link", placeholder: "https://honeybun.me/verify/…", text: $verifyLink, keyboard: .URL, id: "hb-account-verify-link").padding(.top, 8)
                        HBPillButton(title: "Confirm email") { verify() }.disabled(busy)
                    }
                } label: { Text("I have the link").font(.system(size: 15, weight: .semibold)).foregroundColor(Color(red: 0.72, green: 0.68, blue: 0.9)) }.tint(HB.orange)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).hbCard()
    }

    private var securityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Security").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
            // passkeys
            VStack(alignment: .leading, spacing: 8) {
                Text("Passkeys").font(.system(size: 15, weight: .semibold)).foregroundColor(Color(red: 0.86, green: 0.82, blue: 0.95))
                if !passkeysLoaded { ProgressView().tint(HB.orange) }
                else if passkeys.isEmpty { Text("No passkeys yet. A passkey lets you log in with Face ID.").font(.footnote).foregroundColor(HB.soft) }
                ForEach(passkeys) { p in passkeyRow(p) }
                if HBPasskeyService.isAvailable { HBPillButton(title: busy ? "Adding…" : "Add a passkey", symbol: "plus", filled: false) { addPasskey() }.disabled(busy).accessibilityIdentifier("hb-account-add-passkey") }
            }
            Divider().background(HB.line)
            if user?.has_password != false {
                Button { showChangePassword = true } label: {
                    HStack { Text("Change password").foregroundColor(.white); Spacer(); Image(systemName: "chevron.right").foregroundColor(HB.soft) }.font(.system(size: 16, weight: .semibold)).frame(minHeight: 40)
                }.accessibilityIdentifier("hb-account-change-password")
            }
            if !hasEmail {
                Divider().background(HB.line)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recovery code").font(.system(size: 15, weight: .semibold)).foregroundColor(Color(red: 0.86, green: 0.82, blue: 0.95))
                    Text("Your username account has no email, so a recovery code is how you reset a forgotten password.").font(.footnote).foregroundColor(HB.soft)
                    if let code = newCode {
                        VStack(spacing: 10) {
                            Text(code).font(.system(size: 26, weight: .heavy, design: .monospaced)).foregroundColor(HB.orange).textSelection(.enabled).minimumScaleFactor(0.7).lineLimit(1).accessibilityIdentifier("hb-account-new-code")
                            HBPillButton(title: codeCopied ? "Copied" : "Copy code", symbol: codeCopied ? "checkmark" : "doc.on.doc", filled: false) { UIPasteboard.general.string = code; codeCopied = true }
                            Text("Save it now. It won't be shown again.").font(.footnote).foregroundColor(HB.red)
                        }
                        .padding(14).frame(maxWidth: .infinity).background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.05)))
                    } else {
                        HBPillButton(title: "Make a new recovery code", symbol: "key", filled: false) { confirmNewCode = true }.accessibilityIdentifier("hb-account-new-recovery")
                    }
                }
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).hbCard()
    }

    private func passkeyRow(_ p: HBPasskeyInfo) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "person.badge.key.fill").foregroundColor(HB.orange).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                if editingPasskey == p.id {
                    TextField("Name", text: $passkeyName).font(.system(size: 16)).foregroundColor(.white).submitLabel(.done).onSubmit { renamePasskey(p) }
                } else {
                    Text(p.name).font(.system(size: 16, weight: .semibold)).foregroundColor(.white)
                }
                Text(p.created_at.map { "Added " + Self.dayFmt.string(from: Date(timeIntervalSince1970: $0)) } ?? "").font(.system(size: 12)).foregroundColor(HB.soft)
            }
            Spacer()
            Button { editingPasskey = p.id; passkeyName = p.name } label: { Image(systemName: "pencil").foregroundColor(HB.soft).frame(width: 32, height: 32) }.accessibilityLabel("Rename passkey")
            Button { removing = p } label: { Image(systemName: "xmark").font(.system(size: 12, weight: .bold)).foregroundColor(HB.soft).frame(width: 32, height: 32) }.accessibilityLabel("Remove passkey")
        }
        .padding(.vertical, 4)
    }
    #if DEBUG
    static let previewPasskeys: [HBPasskeyInfo] = [HBPasskeyInfo(id: "p1", name: "Una's iPhone", created_at: Date().timeIntervalSince1970 - 5 * 86400, last_used: nil), HBPasskeyInfo(id: "p2", name: "iPad", created_at: Date().timeIntervalSince1970 - 40 * 86400, last_used: nil)]
    #else
    static let previewPasskeys: [HBPasskeyInfo] = []
    #endif
    private static let dayFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"; return f }()

    private var dataCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your data").font(.system(size: 18, weight: .bold)).foregroundColor(.white)
            Text("Download everything in your budget as a JSON file.").font(.footnote).foregroundColor(HB.soft)
            HBPillButton(title: busy ? "Preparing…" : "Export my data", symbol: "square.and.arrow.down", filled: false) { exportData() }.disabled(busy).accessibilityIdentifier("hb-account-export")
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).hbCard()
    }

    private var sessionCard: some View {
        VStack(spacing: 10) {
            HBPillButton(title: "Log out", symbol: "rectangle.portrait.and.arrow.right") { confirmLogout = true }.accessibilityIdentifier("hb-account-logout")
            Button { showDelete = true } label: {
                Text("Delete my account").font(.system(size: 16, weight: .semibold)).foregroundColor(HB.red).frame(maxWidth: .infinity, minHeight: 50)
                    .overlay(Capsule().stroke(HB.red.opacity(0.6), lineWidth: 1))
            }.accessibilityIdentifier("hb-account-delete")
            HBAuthLink(title: "Open classic Honeybun") { onClose() }
        }
    }

    // MARK: actions

    private func load() async {
        if store.isPreview { passkeysLoaded = true; passkeys = HBAccountView.previewPasskeys; return }
        if let me = try? await HBAPI.shared.me() { store.account = me.user }
        if let l = try? await HBAPI.shared.passkeys() { passkeys = l }
        passkeysLoaded = true
    }
    private func run(_ work: @escaping () async throws -> Void) {
        busy = true; error = nil; info = nil
        Task {
            do { try await work() } catch let e as HBPlatformAuthError { if let m = e.errorDescription { error = m } } catch { self.error = error.localizedDescription }
            busy = false
        }
    }
    private func resend() { run { try await HBAPI.shared.resendVerification(); info = "Sent. Check your inbox (and spam)." } }
    private func verify() {
        let t = HBAuthText.token(from: verifyLink)
        guard !t.isEmpty else { error = "Paste the link from your email."; return }
        run { try await HBAPI.shared.verifyEmail(token: t); verifyLink = ""; showVerifyLink = false; info = "Email confirmed ♡"; await load() }
    }
    private func addPasskey() {
        run {
            let o = try await HBAPI.shared.passkeyRegistrationOptions()
            let reg = try await HBPasskeyService.shared.register(o)
            try await HBAPI.shared.registerPasskey(reg, name: UIDevice.current.name)
            info = "Passkey added ♡"; await load()
        }
    }
    private func renamePasskey(_ p: HBPasskeyInfo) {
        let n = passkeyName.trimmingCharacters(in: .whitespaces); editingPasskey = nil
        guard !n.isEmpty, n != p.name else { return }
        run { try await HBAPI.shared.renamePasskey(id: p.id, name: n); await load() }
    }
    private func removePasskey(_ p: HBPasskeyInfo) { run { try await HBAPI.shared.deletePasskey(id: p.id); await load() } }
    private func makeCode() { run { newCode = try await HBAPI.shared.newRecoveryCode(); codeCopied = false } }
    private func exportData() {
        run {
            let data = try await HBAPI.shared.exportAccount()
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("honeybun-data.json")
            try data.write(to: url, options: .atomic)
            exportURL = url; showShare = true
        }
    }
}

// MARK: - change password (accounts that have one)

@available(iOS 15.0, *)
struct HBChangePasswordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var current = ""
    @State private var new1 = ""
    @State private var new2 = ""
    @State private var error: String?
    @State private var busy = false
    var body: some View {
        HBSheetScaffold(title: "Change password", onBack: { dismiss() }) {
            HBAuthField(label: "Current password", text: $current, secure: true, contentType: .password, id: "hb-pw-current")
            HBAuthField(label: "New password", placeholder: "At least 8 characters", text: $new1, secure: true, contentType: .newPassword, id: "hb-pw-new")
            HBAuthField(label: "Type it again", text: $new2, secure: true, contentType: .newPassword, id: "hb-pw-new2")
            Text("Your other devices will be logged out.").font(.footnote).foregroundColor(HB.soft)
            HBAuthNote(error: error, info: nil)
            HBPillButton(title: busy ? "Saving…" : "Change password") { save() }.disabled(busy).accessibilityIdentifier("hb-pw-save")
        }
    }
    private func save() {
        hbHideKeyboard(); error = nil
        guard HBAuthText.validPassword(new1) else { error = HBAuthText.passwordRule; return }
        guard new1 == new2 else { error = "The two passwords don't match."; return }
        busy = true
        Task { do { try await HBAPI.shared.changePassword(current: current, new: new1); dismiss() } catch { self.error = error.localizedDescription }; busy = false }
    }
}

// MARK: - delete account

@available(iOS 15.0, *)
struct HBDeleteAccountSheet: View {
    @ObservedObject var store: HBAppStore
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var typed = ""
    @State private var reauthed = false
    @State private var appleCode: String?
    @State private var appleNonce = ""
    @State private var error: String?
    @State private var busy = false
    @State private var confirm = false

    private var passwordless: Bool { store.account?.has_password == false }

    var body: some View {
        HBSheetScaffold(title: "Delete account", onBack: { dismiss() }) {
            VStack(alignment: .leading, spacing: 8) {
                Text("This can't be undone.").font(.system(size: 18, weight: .bold)).foregroundColor(HB.red)
                Text("Your login is deleted and your private entries go with it. If you're the only person in your budget, the whole budget is deleted too. If other people are in it, it stays for them.").font(.system(size: 15)).foregroundColor(HB.soft)
            }
            .padding(16).frame(maxWidth: .infinity, alignment: .leading).hbCard()
            if passwordless { passwordlessSteps } else {
                HBAuthField(label: "Your password", text: $password, secure: true, contentType: .password, id: "hb-delete-password")
            }
            HBAuthNote(error: error, info: nil)
            Button { hbHideKeyboard(); confirm = true } label: {
                Text(busy ? "Deleting…" : "Delete my account").font(.system(size: 18, weight: .bold)).foregroundColor(.white).frame(maxWidth: .infinity, minHeight: 54).background(Capsule().fill(HB.red.opacity(canDelete ? 0.9 : 0.35)))
            }
            .disabled(!canDelete || busy).accessibilityIdentifier("hb-delete-submit")
        }
        .confirmationDialog("Delete your Honeybun account?", isPresented: $confirm, titleVisibility: .visible) {
            Button("Delete forever", role: .destructive) { delete() }
            Button("Keep my account", role: .cancel) {}
        }
    }

    private var canDelete: Bool { passwordless ? (reauthed && typed == "DELETE") : !password.isEmpty }

    @ViewBuilder private var passwordlessSteps: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(reauthed ? "Confirmed ✓" : "First, confirm it's you").font(.system(size: 17, weight: .bold)).foregroundColor(reauthed ? HB.green : .white)
            if !reauthed {
                Text("This account has no password, so confirm with a quick sign-in.").font(.footnote).foregroundColor(HB.soft)
                if store.account?.apple == true {
                    SignInWithAppleButton(.continue, onRequest: { r in appleNonce = HBAppleNonce.makeRaw(); r.requestedScopes = []; r.nonce = HBAppleNonce.sha256Hex(appleNonce) },
                                          onCompletion: { res in Task { await finishApple(res) } })
                        .signInWithAppleButtonStyle(.white).frame(height: 50).clipShape(Capsule()).accessibilityIdentifier("hb-delete-apple")
                }
                if HBPasskeyService.isAvailable { HBPillButton(title: "Confirm with Passkey", symbol: "person.badge.key.fill", filled: false) { reauthPasskey() }.accessibilityIdentifier("hb-delete-passkey") }
            } else {
                HBAuthField(label: "Type DELETE to confirm", placeholder: "DELETE", text: $typed, id: "hb-delete-typed")
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).hbCard()
    }

    private func finishApple(_ res: Result<ASAuthorization, Error>) async {
        guard case let .success(auth) = res, let cred = auth.credential as? ASAuthorizationAppleIDCredential, let apple = HBAppleCredential(cred, rawNonce: appleNonce) else { return }
        busy = true; error = nil
        do {
            _ = try await HBAPI.shared.appleSignIn(identityToken: apple.identityToken, rawNonce: apple.rawNonce, name: nil)   // a fresh session: the backend only deletes right after a login
            await HBSession.didSignIn()
            appleCode = apple.authorizationCode; reauthed = true
        } catch { self.error = error.localizedDescription }
        busy = false
    }
    private func reauthPasskey() {
        busy = true; error = nil
        Task {
            do {
                let c = try await HBAPI.shared.passkeyLoginOptions()
                let a = try await HBPasskeyService.shared.assertion(c)
                try await HBAPI.shared.passkeyLogin(a)
                await HBSession.didSignIn()
                reauthed = true
            } catch let e as HBPlatformAuthError { if let m = e.errorDescription { error = m } } catch { self.error = error.localizedDescription }
            busy = false
        }
    }
    private func delete() {
        busy = true; error = nil
        Task {
            do {
                if passwordless { try await HBAPI.shared.deleteAccount(password: nil, confirm: typed, appleAuthorizationCode: appleCode) }
                else { try await HBAPI.shared.deleteAccount(password: password, confirm: nil, appleAuthorizationCode: nil) }
                await store.accountDeleted()
            } catch { self.error = error.localizedDescription }
            busy = false
        }
    }
}
