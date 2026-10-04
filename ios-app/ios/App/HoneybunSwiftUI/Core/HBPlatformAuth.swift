import Foundation
import UIKit
import AuthenticationServices

// Passkeys through Apple's AuthenticationServices. The relying party is honeybun.me, so the same passkeys work on the website and in the app
// (the site serves /.well-known/apple-app-site-association and the app has the webcredentials:honeybun.me entitlement).
// iPhone-only behaviour: it can't be exercised in CI, only on a real device (or a simulator signed in to iCloud).
enum HBPlatformAuthError: LocalizedError {
    case cancelled, unavailable, failed(String)
    var errorDescription: String? {
        switch self {
        case .cancelled: return nil
        case .unavailable: return "Passkeys need iOS 16 or later."
        case let .failed(m): return m
        }
    }
}

@MainActor final class HBPasskeyService: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    static let shared = HBPasskeyService()
    private var assertionCont: CheckedContinuation<HBPasskeyAssertion, Error>?
    private var registrationCont: CheckedContinuation<HBPasskeyRegistration, Error>?
    private var controller: ASAuthorizationController?

    static var isAvailable: Bool { if #available(iOS 16.0, *) { return true } else { return false } }

    /// "Log in with Passkey": the iPhone shows its passkey sheet (Face ID / Touch ID) and signs the server's challenge
    func assertion(_ c: HBPasskeyCeremony) async throws -> HBPasskeyAssertion {
        guard #available(iOS 16.0, *) else { throw HBPlatformAuthError.unavailable }
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: c.rpId)
        let request = provider.createCredentialAssertionRequest(challenge: c.challenge)
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<HBPasskeyAssertion, Error>) in
            self.assertionCont = cont
            self.run(request)
        }
    }

    /// "Add a passkey": makes a new passkey for this account on the iPhone
    func register(_ o: HBPasskeyRegistrationOptions) async throws -> HBPasskeyRegistration {
        guard #available(iOS 16.0, *) else { throw HBPlatformAuthError.unavailable }
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(relyingPartyIdentifier: o.rpId)
        let request = provider.createCredentialRegistrationRequest(challenge: o.challenge, name: o.userName, userID: o.userID)
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<HBPasskeyRegistration, Error>) in
            self.registrationCont = cont
            self.run(request)
        }
    }

    private func run(_ request: ASAuthorizationRequest) {
        let c = ASAuthorizationController(authorizationRequests: [request])
        c.delegate = self
        c.presentationContextProvider = self
        controller = c
        c.performRequests()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if #available(iOS 16.0, *) {
            if let a = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion {
                assertionCont?.resume(returning: HBPasskeyAssertion(credentialID: a.credentialID, clientDataJSON: a.rawClientDataJSON, authenticatorData: a.rawAuthenticatorData, signature: a.signature))
                assertionCont = nil; return
            }
            if let r = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialRegistration, let att = r.rawAttestationObject {
                registrationCont?.resume(returning: HBPasskeyRegistration(credentialID: r.credentialID, clientDataJSON: r.rawClientDataJSON, attestationObject: att))
                registrationCont = nil; return
            }
        }
        fail(HBPlatformAuthError.failed("Your iPhone returned something Honeybun didn't expect. Try again."))
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        if let e = error as? ASAuthorizationError, e.code == .canceled { fail(HBPlatformAuthError.cancelled) }
        else if let e = error as? ASAuthorizationError, e.code == .notInteractive || e.code == .failed || e.code == .invalidResponse || e.code == .unknown {
            fail(HBPlatformAuthError.failed("Passkeys didn't work here. Make sure you're signed in to iCloud with passkeys on, then try again. (\(e.code.rawValue))"))
        } else { fail(error) }
    }
    private func fail(_ e: Error) {
        assertionCont?.resume(throwing: e); assertionCont = nil
        registrationCont?.resume(throwing: e); registrationCont = nil
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap { $0.windows }
        return windows.first { $0.isKeyWindow } ?? windows.first ?? ASPresentationAnchor()
    }
}

/// What the Apple button gives back, ready for the backend.
struct HBAppleCredential {
    let identityToken: String
    let rawNonce: String
    let fullName: String?
    let authorizationCode: String?

    init?(_ c: ASAuthorizationAppleIDCredential, rawNonce: String) {
        guard let t = c.identityToken, let token = String(data: t, encoding: .utf8) else { return nil }
        self.identityToken = token
        self.rawNonce = rawNonce
        let parts = [c.fullName?.givenName, c.fullName?.familyName].compactMap { $0 }.filter { !$0.isEmpty }
        self.fullName = parts.isEmpty ? nil : parts.joined(separator: " ")
        self.authorizationCode = c.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
    }
}
