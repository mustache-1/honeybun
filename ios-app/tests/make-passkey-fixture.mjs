// Builds a real-shaped WebAuthn attestation object (what the iPhone returns when a passkey is made) so CI can prove the Swift code
// turns it into exactly what POST /api/passkeys wants. Run: node make-passkey-fixture.mjs  → fixtures/passkey.json
import { generateKeyPairSync, randomBytes, createHash } from "node:crypto";
import { writeFileSync } from "node:fs";
const b64u = (b) => Buffer.from(b).toString("base64url");
// --- tiny CBOR encoder (maps, ints, byte strings, text)
const head = (major, n) => n < 24 ? Buffer.from([(major << 5) | n]) : n < 256 ? Buffer.from([(major << 5) | 24, n]) : Buffer.from([(major << 5) | 25, n >> 8, n & 255]);
const cbor = (v) => {
  if (typeof v === "number") return v >= 0 ? head(0, v) : head(1, -1 - v);
  if (typeof v === "string") return Buffer.concat([head(3, Buffer.byteLength(v)), Buffer.from(v)]);
  if (Buffer.isBuffer(v)) return Buffer.concat([head(2, v.length), v]);
  if (v instanceof Map) return Buffer.concat([head(5, v.size), ...[...v].flatMap(([k, x]) => [cbor(k), cbor(x)])]);
  throw new Error("unsupported");
};
const ec = generateKeyPairSync("ec", { namedCurve: "P-256" });
const jwk = ec.publicKey.export({ format: "jwk" });
const x = Buffer.from(jwk.x, "base64url"), y = Buffer.from(jwk.y, "base64url");
const spki = ec.publicKey.export({ type: "spki", format: "der" });
const credId = randomBytes(32);
const cose = cbor(new Map([[1, 2], [3, -7], [-1, 1], [-2, x], [-3, y]]));
const rpIdHash = createHash("sha256").update("honeybun.me").digest();
const authData = Buffer.concat([rpIdHash, Buffer.from([0x45]), Buffer.from([0, 0, 0, 0]), Buffer.alloc(16), Buffer.from([credId.length >> 8, credId.length & 255]), credId, cose]);
const att = cbor(new Map([["fmt", "none"], ["attStmt", new Map()], ["authData", authData]]));
// an RSA-style COSE key (alg -257) the app must refuse
const coseRsa = cbor(new Map([[1, 3], [3, -257], [-1, Buffer.alloc(256, 1)], [-2, Buffer.from([1, 0, 1])]]));
const authRsa = Buffer.concat([rpIdHash, Buffer.from([0x45]), Buffer.from([0, 0, 0, 0]), Buffer.alloc(16), Buffer.from([0, 32]), credId, coseRsa]);
writeFileSync(new URL("./fixtures/passkey.json", import.meta.url), JSON.stringify({
  attestationObject: b64u(att), expectedSpki: b64u(spki), authData: b64u(authData), credentialId: b64u(credId), rsaAttestationObject: b64u(cbor(new Map([["fmt", "none"], ["attStmt", new Map()], ["authData", authRsa]]))),
}, null, 1));
console.log("wrote fixtures/passkey.json", att.length, "bytes");
