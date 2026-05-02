// App Attest verification helpers.
//
// We expose three pieces of work to the Worker handlers:
//   1. issueChallenge   — generate a one-time nonce, store in KV (5min TTL)
//   2. consumeChallenge — atomically verify + delete a previously-issued nonce
//   3. registerDevice   — verify an attestation, persist the device's pubkey
//   4. verifyAndUpdate  — verify an assertion, bump the stored counter
//
// The actual cryptographic work (CBOR parsing, X.509 chain validation
// against Apple's CA, signature verification, Secure Enclave AAGUID
// checking) is handled by the `node-app-attest` library — that's why
// `nodejs_compat` is enabled in wrangler.toml.

import { verifyAttestation, verifyAssertion } from "node-app-attest";

// --- Constants -------------------------------------------------------

const CHALLENGE_TTL_SECONDS = 300;            // 5 minutes — challenges expire fast
const CHALLENGE_KEY_PREFIX = "challenge:";
const DEVICE_KEY_PREFIX    = "device:";

// --- Types -----------------------------------------------------------

export interface DeviceRecord {
  publicKey: string;       // PEM-encoded EC public key from attestation
  counter: number;         // Last seen signCount; must increase monotonically
  attestedAt: string;      // ISO timestamp of registration
}

interface ChallengeRecord {
  createdAt: number;       // Unix ms — for debugging only; expiry is enforced by KV TTL
}

// --- Challenge issuance / consumption --------------------------------

export async function issueChallenge(
  kv: KVNamespace,
): Promise<{ challenge: string; expiresAt: number }> {
  // 32 random bytes encoded as base64url. Kept in the URL-safe alphabet
  // because the iOS client also base64url-encodes it when computing the
  // SHA-256 clientDataHash.
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  const challenge = base64UrlEncode(bytes);

  const now       = Date.now();
  const expiresAt = now + CHALLENGE_TTL_SECONDS * 1000;
  const record: ChallengeRecord = { createdAt: now };

  await kv.put(
    CHALLENGE_KEY_PREFIX + challenge,
    JSON.stringify(record),
    { expirationTtl: CHALLENGE_TTL_SECONDS },
  );
  return { challenge, expiresAt };
}

/// Returns true if the challenge existed (and was just consumed).
/// Returns false if it was already used, expired, or never issued.
/// Replay protection: each challenge can only be consumed once.
export async function consumeChallenge(
  kv: KVNamespace,
  challenge: string,
): Promise<boolean> {
  const key    = CHALLENGE_KEY_PREFIX + challenge;
  const record = await kv.get(key);
  if (!record) return false;
  await kv.delete(key);
  return true;
}

// --- Device registration --------------------------------------------

export async function registerDevice(args: {
  kv: KVNamespace;
  attestation: Buffer;          // raw CBOR from DCAppAttestService.attestKey
  challenge: string;            // base64url string the device signed
  keyId: string;                // base64 string returned by DCAppAttestService.generateKey
  bundleIdentifier: string;
  teamIdentifier: string;
  allowDevelopmentEnvironment: boolean;
}): Promise<{ keyId: string; publicKey: string }> {
  // node-app-attest runs all 9 of Apple's required validation steps
  // (cert chain, AAGUID, RP ID hash, public key match, etc.). It
  // throws on any failure; we let that surface to the handler.
  const result = verifyAttestation({
    attestation:                  args.attestation,
    challenge:                    args.challenge,
    keyId:                        args.keyId,
    bundleIdentifier:             args.bundleIdentifier,
    teamIdentifier:               args.teamIdentifier,
    allowDevelopmentEnvironment:  args.allowDevelopmentEnvironment,
  });

  const record: DeviceRecord = {
    publicKey:  result.publicKey,
    counter:    0,
    attestedAt: new Date().toISOString(),
  };
  // No TTL — device record is permanent until explicitly revoked.
  await args.kv.put(DEVICE_KEY_PREFIX + args.keyId, JSON.stringify(record));

  return result;
}

// --- Device lookup + assertion verification (used by Phase 3b) -------

export async function getDevice(
  kv: KVNamespace,
  keyId: string,
): Promise<DeviceRecord | null> {
  const raw = await kv.get(DEVICE_KEY_PREFIX + keyId);
  return raw ? (JSON.parse(raw) as DeviceRecord) : null;
}

export async function verifyAndUpdate(args: {
  kv: KVNamespace;
  keyId: string;
  assertion: Buffer;
  payload: Buffer;             // SHA-256 of the request body the iOS app signed
  bundleIdentifier: string;
  teamIdentifier: string;
}): Promise<void> {
  const device = await getDevice(args.kv, args.keyId);
  if (!device) throw new Error("device_not_registered");

  const result = verifyAssertion({
    assertion:        args.assertion,
    payload:          args.payload,
    publicKey:        device.publicKey,
    bundleIdentifier: args.bundleIdentifier,
    teamIdentifier:   args.teamIdentifier,
    signCount:        device.counter,
  });

  // Persist the new counter so the next request must use a higher one.
  // Replay attacks reuse old assertions → caught by signCount check.
  device.counter = result.signCount;
  await args.kv.put(DEVICE_KEY_PREFIX + args.keyId, JSON.stringify(device));
}

// --- Encoding helpers ------------------------------------------------

function base64UrlEncode(bytes: Uint8Array): string {
  let binary = "";
  for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export function base64Decode(b64: string): Buffer {
  const padded = b64 + "=".repeat((4 - (b64.length % 4)) % 4);
  return Buffer.from(padded, "base64");
}
