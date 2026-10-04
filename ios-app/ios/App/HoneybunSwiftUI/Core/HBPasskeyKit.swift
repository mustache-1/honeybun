import Foundation
import CryptoKit

// The parts of passkeys and Sign in with Apple that need no UI, so CI can test them on macOS:
//  - base64url, as the backend sends and expects it
//  - turning the iPhone's attestation object (CBOR) into what POST /api/passkeys wants (authenticatorData + SPKI public key + alg)
//  - the Apple nonce: a random secret, whose SHA-256 goes to Apple, and which we send to the backend so it can check the match

enum HBBase64URL {
    static func encode(_ d: Data) -> String { d.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "") }
    static func decode(_ s: String) -> Data? {
        var t = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while t.count % 4 != 0 { t += "=" }
        return Data(base64Encoded: t)
    }
}

enum HBAppleNonce {
    /// a fresh random secret; keep it, send `sha256Hex(raw)` to Apple in the request, and send `raw` to the backend
    static func makeRaw() -> String { HBBase64URL.encode(Data((0..<32).map { _ in UInt8.random(in: 0...255) })) }
    static func sha256Hex(_ s: String) -> String { SHA256.hash(data: Data(s.utf8)).map { String(format: "%02x", $0) }.joined() }
}

struct HBPasskeyAssertion { let credentialID: Data; let clientDataJSON: Data; let authenticatorData: Data; let signature: Data }
struct HBPasskeyRegistration { let credentialID: Data; let clientDataJSON: Data; let attestationObject: Data }
struct HBPasskeyCeremony { let challenge: Data; let rpId: String }
struct HBPasskeyRegistrationOptions { let challenge: Data; let rpId: String; let userID: Data; let userName: String; let displayName: String }

enum HBPasskeyError: LocalizedError {
    case badAttestation, unsupportedKey
    var errorDescription: String? {
        switch self {
        case .badAttestation: return "Your iPhone returned a passkey Honeybun couldn't read. Try again."
        case .unsupportedKey: return "This passkey uses a key type Honeybun doesn't support."
        }
    }
}

// minimal CBOR reader (RFC 8949): enough for a WebAuthn attestation object and a COSE key
indirect enum HBCBOR {
    case int(Int), bytes(Data), text(String), array([HBCBOR]), map([(HBCBOR, HBCBOR)]), simple(Int)

    static func decode(_ data: Data) throws -> (HBCBOR, Int) {
        let b = [UInt8](data)
        var i = 0
        let v = try item(b, &i)
        return (v, i)
    }
    private static func uint(_ b: [UInt8], _ i: inout Int, _ info: Int) throws -> Int {
        switch info {
        case 0..<24: return info
        case 24: guard i + 1 <= b.count else { throw HBPasskeyError.badAttestation }; defer { i += 1 }; return Int(b[i])
        case 25: guard i + 2 <= b.count else { throw HBPasskeyError.badAttestation }; defer { i += 2 }; return Int(b[i]) << 8 | Int(b[i + 1])
        case 26: guard i + 4 <= b.count else { throw HBPasskeyError.badAttestation }; defer { i += 4 }; return (0..<4).reduce(0) { $0 << 8 | Int(b[i + $1]) }
        case 27: guard i + 8 <= b.count else { throw HBPasskeyError.badAttestation }; defer { i += 8 }; return (0..<8).reduce(0) { $0 << 8 | Int(b[i + $1]) }
        default: throw HBPasskeyError.badAttestation
        }
    }
    private static func item(_ b: [UInt8], _ i: inout Int) throws -> HBCBOR {
        guard i < b.count else { throw HBPasskeyError.badAttestation }
        let head = b[i]; i += 1
        let major = Int(head >> 5), info = Int(head & 31)
        switch major {
        case 0: return .int(try uint(b, &i, info))
        case 1: return .int(-1 - (try uint(b, &i, info)))
        case 2, 3:
            let n = try uint(b, &i, info)
            guard n >= 0, i + n <= b.count else { throw HBPasskeyError.badAttestation }
            let d = Data(b[i..<(i + n)]); i += n
            return major == 2 ? .bytes(d) : .text(String(decoding: d, as: UTF8.self))
        case 4:
            let n = try uint(b, &i, info); var out: [HBCBOR] = []
            guard n <= 4096 else { throw HBPasskeyError.badAttestation }
            for _ in 0..<n { out.append(try item(b, &i)) }
            return .array(out)
        case 5:
            let n = try uint(b, &i, info); var out: [(HBCBOR, HBCBOR)] = []
            guard n <= 4096 else { throw HBPasskeyError.badAttestation }
            for _ in 0..<n { let k = try item(b, &i); out.append((k, try item(b, &i))) }
            return .map(out)
        case 7: return .simple(info)
        default: throw HBPasskeyError.badAttestation
        }
    }
    func value(forText key: String) -> HBCBOR? { if case let .map(m) = self { return m.first { if case let .text(t) = $0.0 { return t == key }; return false }?.1 }; return nil }
    func value(forInt key: Int) -> HBCBOR? { if case let .map(m) = self { return m.first { if case let .int(k) = $0.0 { return k == key }; return false }?.1 }; return nil }
    var dataValue: Data? { if case let .bytes(d) = self { return d }; return nil }
    var intValue: Int? { if case let .int(n) = self { return n }; return nil }
}

enum HBPasskeyKit {
    /// what the backend wants for a new passkey: the authenticator data, the public key as SPKI (base64url) and the algorithm (-7 = ES256)
    static func parseAttestation(_ attestationObject: Data) throws -> (authData: Data, spki: Data, alg: Int) {
        let (obj, _) = try HBCBOR.decode(attestationObject)
        guard let authData = obj.value(forText: "authData")?.dataValue, authData.count > 55 else { throw HBPasskeyError.badAttestation }
        let a = [UInt8](authData)
        guard a[32] & 0x40 != 0 else { throw HBPasskeyError.badAttestation }          // "attested credential data included"
        let idLen = Int(a[53]) << 8 | Int(a[54])
        let keyStart = 55 + idLen
        guard keyStart < a.count else { throw HBPasskeyError.badAttestation }
        let (cose, _) = try HBCBOR.decode(Data(a[keyStart...]))
        guard cose.value(forInt: 1)?.intValue == 2, cose.value(forInt: 3)?.intValue == -7, cose.value(forInt: -1)?.intValue == 1,
              let x = cose.value(forInt: -2)?.dataValue, let y = cose.value(forInt: -3)?.dataValue, x.count == 32, y.count == 32 else { throw HBPasskeyError.unsupportedKey }
        // SubjectPublicKeyInfo for an uncompressed P-256 point
        let header: [UInt8] = [0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02, 0x01, 0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07, 0x03, 0x42, 0x00, 0x04]
        return (authData, Data(header) + x + y, -7)
    }
}
