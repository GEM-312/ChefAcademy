// ChefAcademy API — Cloudflare Worker
//
// Secure proxy between the iOS app and external APIs (Anthropic Claude,
// USDA FoodData Central, ElevenLabs TTS). API keys live here as
// server-side secrets — they never ship in the iOS app binary.
//
// Endpoints:
//   GET  /health             → smoke test, no auth
//   GET  /attest/challenge   → mint a one-time nonce for App Attest (no auth)
//   POST /attest/register    → verify attestation + persist device pubkey (no auth — attestation IS the auth)
//   POST /chat               → proxies to Anthropic Messages API
//   GET  /usda/:fdcId        → proxies to USDA FoodData Central
//   POST /tts/:voiceId       → proxies to ElevenLabs Text-to-Speech (returns audio/mpeg)
//
// Auth roadmap:
//   Phase 2:  all protected routes required X-Proxy-Token header.
//   Phase 3a: App Attest scaffolding live, protected routes still on proxy token.
//   Phase 3b: protected routes accepted App Attest assertion OR proxy token.
//   Phase 3c (this commit): proxy token removed. App Attest assertion is required.
//                          Old IPAs that only know the proxy token now 401.

import {
  issueChallenge,
  consumeChallenge,
  registerDevice,
  verifyAndUpdate,
  base64Decode,
} from "./attest";

export interface Env {
  ANTHROPIC_API_KEY: string;
  USDA_API_KEY: string;
  ELEVENLABS_API_KEY: string;

  // App Attest config — public values (set in [vars] in wrangler.toml)
  BUNDLE_ID: string;
  TEAM_ID:   string;

  // App Attest storage — KV namespace (set in [[kv_namespaces]] in wrangler.toml)
  APP_ATTEST_KV: KVNamespace;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === "/health") {
      return json({
        status: "ok",
        worker: "chefacademy-api",
        time: new Date().toISOString(),
      });
    }

    // App Attest endpoints don't use the proxy token: the challenge is
    // public (random bytes), and `register` is authenticated by the
    // attestation itself (Apple's signature is the proof of authenticity).
    if (url.pathname === "/attest/challenge" && request.method === "GET") {
      return handleAttestChallenge(env);
    }

    if (url.pathname === "/attest/register" && request.method === "POST") {
      return handleAttestRegister(request, env);
    }

    // Protected routes. We read the request body BEFORE auth because the
    // assertion is bound to the body bytes (so we have to hash them on
    // the server too). Once consumed, the body is passed through to the
    // handler instead of being read a second time (Workers can't re-read
    // a body — it's a streaming consumer).

    if (url.pathname === "/chat" && request.method === "POST") {
      const bodyText  = await request.text();
      const authError = await requireAuth(request, env, bodyText);
      if (authError) return authError;
      return handleChat(bodyText, env);
    }

    if (url.pathname.startsWith("/usda/") && request.method === "GET") {
      // GET requests have no body — pass an empty string to bind against.
      const authError = await requireAuth(request, env, "");
      if (authError) return authError;
      const fdcId = url.pathname.slice("/usda/".length);
      return handleUSDA(fdcId, env);
    }

    if (url.pathname.startsWith("/tts/") && request.method === "POST") {
      const bodyText  = await request.text();
      const authError = await requireAuth(request, env, bodyText);
      if (authError) return authError;
      const voiceId = url.pathname.slice("/tts/".length);
      return handleTTS(voiceId, bodyText, env);
    }

    return json({ error: "not_found", path: url.pathname }, 404);
  },
};

// MARK: - /attest/challenge

async function handleAttestChallenge(env: Env): Promise<Response> {
  const result = await issueChallenge(env.APP_ATTEST_KV);
  return json(result);
}

// MARK: - /attest/register

async function handleAttestRegister(request: Request, env: Env): Promise<Response> {
  let body: { keyId?: string; attestation?: string; challenge?: string };
  try {
    body = await request.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  if (!body.keyId || !body.attestation || !body.challenge) {
    return json({ error: "missing_fields" }, 400);
  }

  // Single-use challenge — prevents an attacker from replaying a captured
  // attestation against our endpoint with a stolen keyId.
  const consumed = await consumeChallenge(env.APP_ATTEST_KV, body.challenge);
  if (!consumed) {
    return json({ error: "challenge_not_found_or_expired" }, 400);
  }

  try {
    await registerDevice({
      kv:                          env.APP_ATTEST_KV,
      attestation:                 base64Decode(body.attestation),
      challenge:                   body.challenge,
      keyId:                       body.keyId,
      bundleIdentifier:            env.BUNDLE_ID,
      teamIdentifier:              env.TEAM_ID,
      // Accept both prod attestations (App Store / TestFlight builds) and
      // development-CA attestations (Xcode device builds). Same Worker
      // serves both audiences, so we don't gate on environment here.
      allowDevelopmentEnvironment: true,
    });
  } catch (err) {
    console.error("[attest/register] verification failed:", err);
    return json({ error: "attestation_invalid", detail: String(err) }, 401);
  }

  return json({ ok: true });
}

// MARK: - Auth
//
// App Attest only. Every protected request MUST come with the three
// assertion headers and a valid signature; otherwise 401.
//
// Flow:
//   1. Atomically consume the X-AppAttest-Challenge nonce (replay defense)
//   2. Reconstruct the bytes iOS signed: challenge_utf8 ‖ SHA256(body)
//   3. Hand off to verifyAndUpdate, which checks the signature against the
//      device's stored public key and bumps the monotonic counter

async function requireAuth(
  request: Request,
  env: Env,
  bodyText: string,
): Promise<Response | null> {
  const keyId       = request.headers.get("X-AppAttest-KeyID");
  const challenge   = request.headers.get("X-AppAttest-Challenge");
  const assertion64 = request.headers.get("X-AppAttest-Assertion");

  if (!keyId || !challenge || !assertion64) {
    return json({ error: "missing_assertion_headers" }, 401);
  }

  try {
    const consumed = await consumeChallenge(env.APP_ATTEST_KV, challenge);
    if (!consumed) {
      return json({ error: "challenge_not_found_or_expired" }, 401);
    }

    // Mirror the iOS client's clientData construction exactly.
    // Any drift here = signature mismatch = 401.
    const challengeBytes = Buffer.from(challenge, "utf8");
    const bodyHashBuf    = await sha256Buffer(bodyText);
    const payload        = Buffer.concat([challengeBytes, bodyHashBuf]);

    await verifyAndUpdate({
      kv:               env.APP_ATTEST_KV,
      keyId,
      assertion:        base64Decode(assertion64),
      payload,
      bundleIdentifier: env.BUNDLE_ID,
      teamIdentifier:   env.TEAM_ID,
    });
    return null;
  } catch (err) {
    console.error("[auth] assertion failed:", err);
    return json({ error: "assertion_invalid", detail: String(err) }, 401);
  }
}

async function sha256Buffer(input: string): Promise<Buffer> {
  const data = new TextEncoder().encode(input);
  const hash = await crypto.subtle.digest("SHA-256", data);
  return Buffer.from(hash);
}

// MARK: - /chat → Anthropic

async function handleChat(bodyText: string, env: Env): Promise<Response> {
  if (!env.ANTHROPIC_API_KEY) {
    return json({ error: "anthropic_key_not_configured" }, 500);
  }

  // Body has already been read for auth. Parse here without re-reading.
  let body: unknown;
  try {
    body = JSON.parse(bodyText);
  } catch {
    return json({ error: "invalid_json" }, 400);
  }

  const anthropicResponse = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-api-key": env.ANTHROPIC_API_KEY,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify(body),
  });

  // Pass the response through as-is (status, body, content-type).
  // The iOS client already knows how to parse Anthropic's response shape.
  return new Response(anthropicResponse.body, {
    status: anthropicResponse.status,
    headers: { "content-type": "application/json" },
  });
}

// MARK: - /usda/:fdcId → FoodData Central

async function handleUSDA(fdcId: string, env: Env): Promise<Response> {
  if (!env.USDA_API_KEY) {
    return json({ error: "usda_key_not_configured" }, 500);
  }

  // Defense in depth: only digits allowed. Stops path-traversal-style
  // shenanigans like "/usda/../something" reaching the upstream API.
  if (!/^\d+$/.test(fdcId)) {
    return json({ error: "invalid_fdc_id" }, 400);
  }

  const upstream = `https://api.nal.usda.gov/fdc/v1/food/${fdcId}?api_key=${env.USDA_API_KEY}`;
  const response = await fetch(upstream);

  return new Response(response.body, {
    status: response.status,
    headers: { "content-type": "application/json" },
  });
}

// MARK: - /tts/:voiceId → ElevenLabs

async function handleTTS(voiceId: string, bodyText: string, env: Env): Promise<Response> {
  if (!env.ELEVENLABS_API_KEY) {
    return json({ error: "elevenlabs_key_not_configured" }, 500);
  }

  // ElevenLabs voice IDs are alphanumeric. Reject anything else.
  if (!/^[A-Za-z0-9]+$/.test(voiceId)) {
    return json({ error: "invalid_voice_id" }, 400);
  }

  // Body has already been read for auth — use the passed-in string.

  const upstream = `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`;
  const response = await fetch(upstream, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "xi-api-key": env.ELEVENLABS_API_KEY,
      "accept": "audio/mpeg",
    },
    body: bodyText,
  });

  // Forward the audio bytes (or JSON error) straight through with the
  // upstream content-type so the iOS client sees the same response shape
  // it would get from ElevenLabs directly.
  const contentType = response.headers.get("content-type") ?? "application/octet-stream";
  return new Response(response.body, {
    status: response.status,
    headers: { "content-type": contentType },
  });
}

// MARK: - Helpers

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}
