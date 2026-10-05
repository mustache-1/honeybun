import Foundation

// Runs the native sign-in client (HBAPI + HBAuthAPI + HBSession's cookie handling) against the in-process stand-in backend (HBMockServer "auth" seed),
// which follows the real backend's rules (see tests/auth-contract.mjs for the checks against the real worker). On macOS CI.
var failures = 0
func check(_ name: String, _ ok: Bool) { print((ok ? "PASS " : "FAIL ") + name); if !ok { failures += 1 } }
func both(_ a: Bool, _ b: Bool) -> Bool { a && b }   // arguments are evaluated in order, so `await` is allowed in them (unlike after &&)
func fixture(_ key: String) -> String { let d = (try! JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))) as! [String: Any]; return d[key] as! String }

func run() async {
    let api = HBAPI.shared
    func refused(_ work: () async throws -> Void) async -> String? { do { try await work(); return nil } catch { return (error as? HBAPIError)?.errorDescription ?? "\(error)" } }
    func me() async -> HBMeEnvelope? { try? await api.me() }
    func clearCookies() { for c in HTTPCookieStorage.shared.cookies(for: HBSession.url) ?? [] { HTTPCookieStorage.shared.deleteCookie(c) } }
    HBMockServer.install(seed: "auth")
    clearCookies()

    // ---- launch with no session
    let launchErr = await refused({ _ = try await api.me() })
    check("LAUNCH: no session cookie → /api/me says not signed in (the app shows native Welcome)", !HBSession.hasSessionCookie && launchErr == HBAPIError.notSignedIn.errorDescription)

    // ---- username sign-up
    var code: String? = nil
    do { code = try await api.signup({ var d = HBSignupDraft(); d.name = "Una"; d.id = .username("Una_01"); d.password = "Passw0rd!xyzzy"; return d }()) } catch { check("signup threw \(error)", false) }
    check("SIGN UP (username): a recovery code XXXX-XXXX-XXXX comes back and the session cookie was stored by the app itself", (code ?? "").count == 14 && HBSession.hasSessionCookie)
    check("SIGN UP: the cookie is the real backend's: __Host-hb, HttpOnly, Secure, Path=/", HBSession.sessionCookie.map { $0.name == "__Host-hb" && $0.isHTTPOnly && $0.isSecure && $0.path == "/" } ?? false)
    var env = await me()
    check("SIGN UP: /api/me knows the account (username stored lowercase, no real email, has a password, no budget yet → setup screen)", env?.user?.name == "Una" && env?.user?.email == "una_01@u.honeybun.invalid" && env?.user?.has_email == false && env?.user?.has_password == true && env?.nest_id == nil)

    // ---- the first budget
    check("SETUP: a wrong invite code is refused with the server's message", await refused({ try await api.joinBudget(code: "ZZZZ-9999") }) == "That invite code doesn't match any budget. Check it and try again.")
    check("SETUP: starting a budget works", await refused({ try await api.createBudget(name: "Our Hive", kind: "couple") }) == nil)
    env = await me()
    let snap = try? await api.nest(month: HBDay.monthKey())
    check("SETUP: /api/me now has a budget, and the snapshot says setup is not finished (the app shows onboarding)", env?.nest_id != nil && snap?.setup_done == false && snap?.me?.name == "Una")
    let finErr = await refused({ try await api.finishSetup() })
    let afterFin = try? await api.nest(month: HBDay.monthKey())
    check("ONBOARDING: finishing it marks setup done", finErr == nil && afterFin?.setup_done == true)

    // ---- logout and back in
    let outErr = await refused({ try await api.logout() })
    check("LOGOUT: succeeds and the cookie is gone from the app", outErr == nil && !HBSession.hasSessionCookie)
    check("LOGOUT: afterwards the API says signed out again", await refused({ _ = try await api.me() }) == HBAPIError.notSignedIn.errorDescription)
    check("LOGIN: the wrong password shows the backend's message (not \"you are signed out\")", await refused({ try await api.login(who: "una_01", password: "nope-nope") }) == "Wrong email, username or password.")
    let inErr = await refused({ try await api.login(who: "UNA_01", password: "Passw0rd!xyzzy") })
    check("LOGIN: with the USERNAME (any case) and password works, session cookie stored", inErr == nil && HBSession.hasSessionCookie)
    env = await me()
    check("LOGIN: back in with the same account and budget", env?.user?.name == "Una" && env?.nest_id != nil)
    // expired / invalid session
    clearCookies()
    check("EXPIRED SESSION: with the cookie gone every call says signed out (the app returns to native sign-in)", await refused({ _ = try await api.nest(month: HBDay.monthKey()) }) == HBAPIError.notSignedIn.errorDescription)

    // ---- sign-up rules
    func signup(_ n: String, _ id: HBSignupID, _ pw: String = "Passw0rd!xyzzy") async -> String? { await refused { var d = HBSignupDraft(); d.name = n; d.id = id; d.password = pw; _ = try await api.signup(d) } }
    clearCookies()
    check("SIGN UP: a taken username → \"That username is taken. Try another one.\"", await signup("Una2", .username("una_01")) == "That username is taken. Try another one.")
    check("SIGN UP: a bad username → the 3–20 characters rule", await signup("X", .username("a b")) == "Usernames are 3 to 20 letters, numbers, dots, dashes or underscores.")
    check("SIGN UP: a short password → \"Use a password with at least 8 characters.\"", await signup("X", .username("shortpw"), "short") == "Use a password with at least 8 characters.")
    check("SIGN UP: no name → \"Enter your name.\"", await signup("", .username("noname1")) == "Enter your name.")
    check("SIGN UP (email): no recovery code, a verification email instead; the account has a real email", await signup("Em", .email("em@example.com")) == nil)
    env = await me()
    check("SIGN UP (email): /api/me shows a real email that is not confirmed yet", env?.user?.has_email == true && env?.user?.verified == false && env?.user?.email == "em@example.com")
    check("EMAIL: resend verification works while signed in", await refused({ try await api.resendVerification() }) == nil)
    check("EMAIL: a bad verification link → the server's message", await refused({ try await api.verifyEmail(token: "nope") }) == "This link has expired or was already used. You can send a new one from Settings.")
    let verErr = await refused({ try await api.verifyEmail(token: "valid-verify-token") })
    let verMe = await me()
    check("EMAIL: a good verification link confirms the address", verErr == nil && verMe?.user?.verified == true)
    check("EMAIL: recovery codes are refused for email accounts", await refused({ _ = try await api.newRecoveryCode() }) == "Accounts with an email reset their password by email.")
    _ = try? await api.logout(); clearCookies()

    // ---- forgot / reset / recover
    let fgBad = await refused({ try await api.forgotPassword(email: "nope") })
    let fgGood = await refused({ try await api.forgotPassword(email: "em@example.com") })
    check("FORGOT: a non-email is rejected, a good email is accepted", fgBad == "Enter a valid email address." && fgGood == nil)
    check("RESET: pasted link → the token is the part after /reset/ (query ignored)", HBAuthText.token(from: "https://honeybun.me/reset/abc123_-XYZ?utm=x") == "abc123_-XYZ" && HBAuthText.token(from: "  abc123  ") == "abc123" && HBAuthText.token(from: "honeybun.me/verify/tok#frag") == "tok")
    check("RESET: a bad token → the server's message", await refused({ try await api.resetPassword(token: "bad", password: "NewPassw0rd!aa") }) == "This reset link has expired or was already used. Ask for a new one.")
    check("RESET: a short new password is refused", await refused({ try await api.resetPassword(token: "valid-reset-token", password: "short") }) == "Use a password with at least 8 characters.")
    let rsErr = await refused({ try await api.resetPassword(token: "valid-reset-token", password: "NewPassw0rd!aa") })
    check("RESET: a good token signs you in with the new password", rsErr == nil && HBSession.hasSessionCookie)
    _ = try? await api.logout(); clearCookies()
    check("RECOVER: a wrong code → \"That username and recovery code don't match.\"", await refused({ _ = try await api.recoverPassword(username: "una_01", code: "AAAA-BBBB-CCCC", password: "BrandNewPw!123") }) == "That username and recovery code don't match.")
    // sign a fresh username account to have a known code
    var rc: String? = nil
    do { rc = try await api.signup({ var d = HBSignupDraft(); d.name = "Rec"; d.id = .username("recover1"); d.password = "Passw0rd!xyzzy"; return d }()) } catch {}
    _ = try? await api.logout(); clearCookies()
    var newRC: String? = nil
    do { newRC = try await api.recoverPassword(username: "recover1", code: (rc ?? "").lowercased(), password: "BrandNewPw!123") } catch { check("recover threw \(error)", false) }
    check("RECOVER: the right code (any case) sets the new password, returns a NEW code and signs you in", (newRC ?? "").count == 14 && newRC != rc && HBSession.hasSessionCookie)
    check("RECOVER: the old code no longer works", await refused({ _ = try await api.recoverPassword(username: "recover1", code: rc ?? "", password: "AnotherPw!12345") }) == "That username and recovery code don't match.")
    check("RECOVERY CODE: signed in, a new one can be generated for a username account", ((try? await api.newRecoveryCode()) ?? "").count == 14)
    let pwBad = await refused({ try await api.changePassword(current: "wrong", new: "Another!Pass123") })
    let pwGood = await refused({ try await api.changePassword(current: "BrandNewPw!123", new: "Another!Pass123") })
    check("PASSWORD: change needs the right current password", pwBad == "Your current password is wrong." && pwGood == nil)

    // ---- Sign in with Apple (the app's side: nonce + request body)
    _ = try? await api.logout(); clearCookies()
    let raw = HBAppleNonce.makeRaw()
    check("APPLE: the nonce is a fresh random secret, and Apple gets only its SHA-256 (64 hex characters)", raw.count >= 40 && raw != HBAppleNonce.makeRaw() && HBAppleNonce.sha256Hex(raw).count == 64 && HBAppleNonce.sha256Hex("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    let tok = "mock.001234.abcd.0001." + HBAppleNonce.sha256Hex(raw)
    let apErr = await refused({ _ = try await api.appleSignIn(identityToken: "mock.001234abcd." + HBAppleNonce.sha256Hex(raw), rawNonce: raw, name: "Alex") })
    check("APPLE: the backend accepts the token when the raw nonce matches its hash, makes the account and starts the same session cookie", apErr == nil && HBSession.hasSessionCookie)
    env = await me()
    check("APPLE: /api/me → name from Apple, no password, apple:true (the app shows Account → \"Signs in with Apple\" and DELETE confirmation)", env?.user?.name == "Alex" && env?.user?.apple == true && env?.user?.has_password == false)
    _ = tok
    _ = try? await api.logout(); clearCookies()
    check("APPLE: a token whose nonce doesn't match is refused", await refused({ _ = try await api.appleSignIn(identityToken: "mock.001234abcd." + HBAppleNonce.sha256Hex("someone-elses-nonce"), rawNonce: raw, name: nil) }) == "Apple sign-in failed. Try again.")
    let ap2 = await refused({ _ = try await api.appleSignIn(identityToken: "mock.001234abcd." + HBAppleNonce.sha256Hex(raw), rawNonce: raw, name: nil) })
    let ap2Me = await me()
    check("APPLE: signing in again with the same Apple ID → the same account", ap2 == nil && ap2Me?.user?.name == "Alex")
    let delPw = await refused({ try await api.deleteAccount(password: "x", confirm: nil, appleAuthorizationCode: nil) })
    let delOk = await refused({ try await api.deleteAccount(password: nil, confirm: "DELETE", appleAuthorizationCode: "code") })
    check("APPLE: an account with no password is deleted by typing DELETE (no password to guess)", delPw == "Type DELETE to confirm." && delOk == nil)
    let afterDel = await refused({ _ = try await api.me() })
    check("DELETE: the app's session is gone afterwards", !HBSession.hasSessionCookie && afterDel != nil)
    clearCookies()

    // ---- passkeys
    var d = HBSignupDraft(); d.name = "Key"; d.id = .username("keyuser"); d.password = "Passw0rd!xyzzy"
    _ = try? await api.signup(d)
    let att = Data(HBBase64URL.decode(fixture("attestationObject"))!)
    let reg = HBPasskeyRegistration(credentialID: HBBase64URL.decode(fixture("credentialId"))!, clientDataJSON: Data("{\"type\":\"webauthn.create\"}".utf8), attestationObject: att)
    let o = try? await api.passkeyRegistrationOptions()
    check("PASSKEY: registration options give a challenge, honeybun.me as the relying party and the account's user handle", o != nil && o?.rpId == "honeybun.me" && (o?.challenge.count ?? 0) > 0 && (o?.userID.count ?? 0) > 0)
    check("PASSKEY: the iPhone's attestation object becomes what the backend wants and registers", await refused({ try await api.registerPasskey(reg, name: "Una's iPhone") }) == nil)
    var list = (try? await api.passkeys()) ?? []
    check("PASSKEY: it is listed with its name", list.count == 1 && list[0].name == "Una's iPhone" && list[0].id == fixture("credentialId"))
    check("PASSKEY: registering the same one again is refused", await refused({ try await api.registerPasskey(reg, name: "again") }) != nil)
    let rnErr = await refused({ try await api.renamePasskey(id: list[0].id, name: "Work phone") })
    let rnList = (try? await api.passkeys()) ?? []
    check("PASSKEY: rename works", rnErr == nil && rnList.first?.name == "Work phone")
    _ = try? await api.logout(); clearCookies()
    let ceremony = try? await api.passkeyLoginOptions()
    check("PASSKEY LOGIN: options need no account (challenge + rpId)", ceremony?.rpId == "honeybun.me" && (ceremony?.challenge.count ?? 0) > 0)
    let assertion = HBPasskeyAssertion(credentialID: HBBase64URL.decode(fixture("credentialId"))!, clientDataJSON: Data("{}".utf8), authenticatorData: Data(repeating: 1, count: 37), signature: Data(repeating: 2, count: 70))
    let pkErr = await refused({ try await api.passkeyLogin(assertion) })
    check("PASSKEY LOGIN: a registered passkey starts the same session cookie", pkErr == nil && HBSession.hasSessionCookie)
    list = (try? await api.passkeys()) ?? []
    let rmErr = await refused({ try await api.deletePasskey(id: list[0].id) })
    let rmList = (try? await api.passkeys()) ?? []
    check("PASSKEY: remove works", rmErr == nil && rmList.isEmpty)
    _ = try? await api.logout(); clearCookies()
    check("PASSKEY LOGIN: an unknown passkey → the \"add it in Settings\" message", (await refused({ try await api.passkeyLogin(assertion) }))?.contains("isn't registered") == true)

    // ---- passkey parsing (the iPhone's CBOR → the backend's format)
    let parsed = try? HBPasskeyKit.parseAttestation(att)
    check("PASSKEY KIT: the attestation object is parsed into authenticatorData + P-256 SPKI + alg -7, exactly as the backend expects", parsed.map { HBBase64URL.encode($0.spki) == fixture("expectedSpki") && HBBase64URL.encode($0.authData) == fixture("authData") && $0.alg == -7 } ?? false)
    check("PASSKEY KIT: an RSA key is refused with a clear error", { do { _ = try HBPasskeyKit.parseAttestation(HBBase64URL.decode(fixture("rsaAttestationObject"))!); return false } catch { return (error as? HBPasskeyError).map { "\($0)" } == "unsupportedKey" } }())
    check("PASSKEY KIT: a truncated attestation object is refused, never crashes", { do { _ = try HBPasskeyKit.parseAttestation(att.prefix(40)); return false } catch { return true } }())
    check("BASE64URL: round-trips with no padding and url-safe characters", HBBase64URL.decode(HBBase64URL.encode(Data([0xfb, 0xff, 0xfe, 0x00]))) == Data([0xfb, 0xff, 0xfe, 0x00]) && !HBBase64URL.encode(Data([0xfb, 0xff])).contains("+") && !HBBase64URL.encode(Data([1])).contains("="))

    // ---- invite-code sign-up
    clearCookies()
    d = HBSignupDraft(); d.name = "Joiner"; d.id = .username("joiner1"); d.password = "Passw0rd!xyzzy"
    _ = try? await api.signup(d)
    let jnErr = await refused({ try await api.joinBudget(code: HBAuthText.inviteCode("honey-123")) })
    let jnSnap = try? await api.nest(month: HBDay.monthKey())
    check("INVITE: signing up then joining with a typed code (dash and case ignored) puts you in the shared budget, setup already done", HBAuthText.inviteCode("honey-123") == "HONEY123" && jnErr == nil && jnSnap?.setup_done == true)
    check("SIGN UP: client-side checks (name, identifier, password length) give the website's messages", { var d = HBSignupDraft(); d.id = .username("x"); d.password = "short"; return HBAuthText.signupProblem(d) == "Enter your name." }()
          && { var d = HBSignupDraft(); d.name = "A"; d.id = .username(" "); return HBAuthText.signupProblem(d) == "Pick a username." }()
          && { var d = HBSignupDraft(); d.name = "A"; d.id = .email(""); return HBAuthText.signupProblem(d) == "Enter your email." }()
          && { var d = HBSignupDraft(); d.name = "A"; d.id = .username("ab"); d.password = "short"; return HBAuthText.signupProblem(d) == HBAuthText.passwordRule }()
          && { var d = HBSignupDraft(); d.name = "A"; d.id = .username("ab"); d.passkeyOnly = true; return HBAuthText.signupProblem(d) == nil }())
    check("SIGN UP: the request body is the backend's: name, lowercase username, password, lang — or `passkey: true` instead of a password", { var d = HBSignupDraft(); d.name = "Una"; d.id = .username("Una_01 "); d.password = "pw123456"
        let j = d.json; var p = d; p.passkeyOnly = true; let k = p.json
        return (j["username"] as? String) == "una_01" && (j["password"] as? String) == "pw123456" && (j["email"] == nil) && (k["passkey"] as? Bool) == true && k["password"] == nil }())

    // Settings: email reminders, the test notification, and that logging out leaves nothing behind
    var dp = HBSignupDraft(); dp.name = "Pip"; dp.id = .username("pip_01"); dp.password = "Passw0rd!xyzzy"
    _ = try? await api.signup(dp)
    let me0 = await me()
    check("SETTINGS: /api/me carries the email reminder switches (all on to begin with)", me0?.user?.mail?.bills == true && me0?.user?.mail?.streak == true && me0?.user?.mail?.weekly == true)
    let flipErr = await refused { try await api.setMailReminder("mail_streak", on: false) }
    let me1 = await me()
    check("SETTINGS: switching Streak reminder off is saved (the others stay on)", flipErr == nil && me1?.user?.mail?.streak == false && me1?.user?.mail?.bills == true)
    let msg0 = (try? await api.sendTestPush()) ?? "threw"
    check("SETTINGS: the test notification says so when no phone is registered", msg0.contains("No phone"))
    _ = try? await api.send("/api/push/apns", method: "POST", body: ["token": "abcd"])
    let msg1 = (try? await api.sendTestPush()) ?? "threw"
    _ = try? await api.send("/api/push/apns", method: "DELETE", body: ["token": "abcd"])
    let msg2 = (try? await api.sendTestPush()) ?? "threw"
    check("SETTINGS: a registered phone gets the test; removing its token (what log out does) stops it", msg1 == "Sent!" && msg2.contains("No phone"))
    // referral links: Universal Link → remembered → sent with the native sign-up → the referrer is credited
    let rdef = UserDefaults(suiteName: "hb-test-ref")!; rdef.removePersistentDomain(forName: "hb-test-ref")
    check("REFERRAL: honeybun.me/r/CODE is a referral link (4–16 letters/numbers, any case → upper); other paths and other sites are not",
          HBReferral.code(from: URL(string: "https://honeybun.me/r/abc234x")!) == "ABC234X" && HBReferral.code(from: URL(string: "https://honeybun.me/r/ab")!) == nil && HBReferral.code(from: URL(string: "https://honeybun.me/r/")!) == nil
          && HBReferral.code(from: URL(string: "https://honeybun.me/privacy.html")!) == nil && HBReferral.code(from: URL(string: "https://evil.example/r/ABC234X")!) == nil)
    check("REFERRAL: HBDeepLink knows it too, and it does not disturb the other links", HBDeepLink.parse(URL(string: "https://honeybun.me/r/ABC234X")!) == .referral("ABC234X") && HBDeepLink.parse(URL(string: "https://honeybun.me/join/ABCD-EFGH")!) == .join("ABCD-EFGH"))
    let t0 = Date(timeIntervalSince1970: 1_790_000_000)
    check("REFERRAL: nothing is remembered to begin with", HBReferral.pending(now: t0, rdef) == nil)
    HBReferral.remember("abc234x", now: t0, rdef)
    check("REFERRAL: the code is remembered for 60 days (59 days later it is still there, 61 days later it is gone)", HBReferral.pending(now: t0.addingTimeInterval(59 * 86400), rdef) == "ABC234X" && HBReferral.pending(now: t0.addingTimeInterval(61 * 86400), rdef) == nil)
    HBReferral.clear(rdef)
    check("REFERRAL: it is cleared once used", HBReferral.pending(now: t0, rdef) == nil)
    HBReferral.remember("no", now: t0, rdef)
    check("REFERRAL: a too-short code is never remembered", HBReferral.pending(now: t0, rdef) == nil)
    var dRef = HBSignupDraft(); dRef.name = "Referrer"; dRef.id = .username("ref_r1"); dRef.password = "Passw0rd!xyzzy"
    _ = try? await api.signup(dRef)
    let refInfo = try? await api.referrals()
    let myCode = refInfo?.code ?? ""
    _ = try? await api.logout(); clearCookies()
    HBReferral.remember(myCode)                                             // the friend taps the Universal Link …
    var dFriend = HBSignupDraft(); dFriend.name = "Friend"; dFriend.id = .username("ref_f1"); dFriend.password = "Passw0rd!xyzzy"
    dFriend.ref = HBReferral.pending()                                      // … the sign-up screen sends the remembered code …
    check("REFERRAL: the sign-up body carries `ref` only when there is a code; a normal sign-up has none", (dFriend.json["ref"] as? String) == myCode.uppercased() && HBSignupDraft().json["ref"] == nil)
    _ = try? await api.signup(dFriend)
    HBReferral.clear()
    _ = try? await api.logout(); clearCookies()
    _ = try? await api.login(who: "ref_r1", password: "Passw0rd!xyzzy")
    let after = try? await api.referrals()
    check("REFERRAL: link → sign-up → the referrer's list (the existing /api/referrals) shows the friend as pending; the code is cleared after use",
          after?.people.count == 1 && after?.people.first?.name == "Friend" && after?.people.first?.status == "pending" && HBReferral.pending() == nil)
    _ = try? await api.logout(); clearCookies()
    var dNo = HBSignupDraft(); dNo.name = "Plain"; dNo.id = .username("ref_n1"); dNo.password = "Passw0rd!xyzzy"
    _ = try? await api.signup(dNo)
    _ = try? await api.logout(); clearCookies()
    _ = try? await api.login(who: "ref_r1", password: "Passw0rd!xyzzy")
    check("REFERRAL: a normal sign-up (no link) adds nobody to the referrer", (try? await api.referrals())?.people.count == 1)
    _ = try? await api.logout(); clearCookies()
    check("DEVICE: every request carries a stable x-hb-device id for this phone (22 letters/numbers/-/_), the same one each time", HBDevice.isValid(HBDevice.id()) && HBDevice.id() == HBDevice.id() && HBDevice.id().count == 22)

    // the widget / Siri token follows the session (Account A → logout → Account B)
    var tokenReloads = 0
    HBDeviceToken.onChange = { tokenReloads += 1 }
    Honeybun.token = nil
    var dA = HBSignupDraft(); dA.name = "Alice"; dA.id = .username("alice_w1"); dA.password = "Passw0rd!xyzzy"
    _ = try? await api.signup(dA)
    await HBDeviceToken.ensure()
    let tokA = Honeybun.token ?? ""
    let sumA = try? await HoneybunAPI.summary()
    check("TOKEN: signing in as A makes this phone a widget/Siri token, and it shows A's budget only", tokA.hasPrefix("hb_app_") && sumA?.name == "Alice Hive" && tokenReloads == 1)
    await HBDeviceToken.ensure()
    check("TOKEN: signing in again keeps the same token (no new one is made while the phone has one)", Honeybun.token == tokA && tokenReloads == 1)
    await HBDeviceToken.revokeOnServer()
    _ = try? await api.logout(); clearCookies()
    HBDeviceToken.clearLocal()
    var staleErr = ""
    do { _ = try await HoneybunAPI.summary() } catch { staleErr = "\(error)" }
    check("TOKEN: after A logs out the phone has no token, so the widget/Siri ask for nothing and get 'not signed in'; the widget is told to redraw", Honeybun.token == nil && staleErr == "notSignedIn" && tokenReloads == 2)
    Honeybun.token = tokA        // even if a stale copy of A's token were put back on the phone…
    var revokedErr = ""
    do { _ = try await HoneybunAPI.summary() } catch { revokedErr = "\(error)" }
    check("TOKEN: …the server already revoked it at log out, so it shows nothing of A (not signed in)", revokedErr == "notSignedIn")
    Honeybun.token = nil
    var dB = HBSignupDraft(); dB.name = "Bob"; dB.id = .username("bob_w1"); dB.password = "Passw0rd!xyzzy"
    _ = try? await api.signup(dB)
    await HBDeviceToken.ensure()
    let sumB = try? await HoneybunAPI.summary()
    check("TOKEN: B signs in on the same phone → a new token that shows B's budget only, never A's", (Honeybun.token ?? "").hasPrefix("hb_app_") && Honeybun.token != tokA && sumB?.name == "Bob Hive" && !(sumB?.name.contains("Alice") ?? true))
    _ = try? await api.logout(); clearCookies(); Honeybun.token = nil

    _ = try? await api.login(who: "pip_01", password: "Passw0rd!xyzzy")      // back to the Settings account for the shortcut key checks
    // Apple Pay auto-logging key
    let keyA = (try? await api.makeShortcutKey()) ?? ""
    let meK = await me()
    check("SHORTCUT: making a key returns it once (hb_…) and the account then shows auto-logging as on", keyA.hasPrefix("hb_") && keyA.count > 10 && meK?.user?.shortcut != nil && meK?.user?.shortcut?.uses == 0)
    let keyB = (try? await api.makeShortcutKey()) ?? ""
    check("SHORTCUT: a new key replaces the old one (a different value)", keyB.hasPrefix("hb_") && keyB != keyA)
    try? await api.revokeShortcutKey()
    let meOff = await me()
    check("SHORTCUT: turning it off removes it from the account", meOff?.user?.shortcut == nil)
    _ = try? await api.logout(); clearCookies()
    let afterOut = await refused { _ = try await api.me() }
    check("LOG OUT: the session cookie is gone and the next request is told to log in", !HBSession.hasSessionCookie && afterOut == HBAPIError.notSignedIn.errorDescription)

    // links that open the app (Universal Links): only honeybun.me/verify|reset|join/<value>
    func link(_ s: String) -> HBDeepLink? { URL(string: s).flatMap(HBDeepLink.parse) }
    check("LINKS: /verify/<token>, /reset/<token> and /join/<code> on honeybun.me are recognised",
          link("https://honeybun.me/verify/abc123") == .verify("abc123") && link("https://honeybun.me/reset/tok_en-9") == .reset("tok_en-9") && link("https://honeybun.me/join/ABCD-EFGH") == .join("ABCD-EFGH"))
    check("LINKS: other pages and other sites are not taken over by the app",
          link("https://honeybun.me/") == nil && link("https://honeybun.me/privacy") == nil && link("https://honeybun.me/verify/") == nil && link("https://honeybun.me/verify/a/b") == nil
          && link("https://evil.example/reset/abc") == nil && link("https://honeybun.me.evil.example/reset/abc") == nil)
    check("LINKS: a pasted reset link still gives the same token the deep link carries", HBAuthText.token(from: "https://honeybun.me/reset/tok_en-9") == "tok_en-9")
}

let done = DispatchSemaphore(value: 0)
Task { await run(); done.signal() }
if done.wait(timeout: .now() + 90) == .timedOut { print("FAIL timed out"); exit(1) }
print(failures == 0 ? "ALL AUTH FLOW CHECKS PASSED" : "\(failures) FAILED")
exit(failures == 0 ? 0 : 1)
