// ChefAcademy API — Cloudflare Worker
//
// Secure proxy between the iOS app and external APIs (Anthropic Claude,
// USDA FoodData Central, ElevenLabs TTS). API keys live here as
// server-side secrets — they never ship in the iOS app binary.
//
// Endpoints:
//   GET  /health           → smoke test, no auth
//   POST /chat             → proxies to Anthropic Messages API
//   GET  /usda/:fdcId      → proxies to USDA FoodData Central
//   POST /tts/:voiceId     → proxies to ElevenLabs Text-to-Speech (returns audio/mpeg)
//
// Auth (Phase 2): all non-/health routes require X-Proxy-Token header.
// This is a temporary shared-secret speed bump. Phase 3 replaces it with
// Apple App Attest for cryptographic proof the request came from our app.

export interface Env {
  ANTHROPIC_API_KEY: string;
  PROXY_TOKEN: string;
  USDA_API_KEY: string;
  ELEVENLABS_API_KEY: string;
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

    const authError = checkProxyToken(request, env);
    if (authError) return authError;

    if (url.pathname === "/chat" && request.method === "POST") {
      return handleChat(request, env);
    }

    if (url.pathname.startsWith("/usda/") && request.method === "GET") {
      const fdcId = url.pathname.slice("/usda/".length);
      return handleUSDA(fdcId, env);
    }

    if (url.pathname.startsWith("/tts/") && request.method === "POST") {
      const voiceId = url.pathname.slice("/tts/".length);
      return handleTTS(voiceId, request, env);
    }

    return json({ error: "not_found", path: url.pathname }, 404);
  },
};

// MARK: - Auth

function checkProxyToken(request: Request, env: Env): Response | null {
  const token = request.headers.get("X-Proxy-Token");
  if (!token || token !== env.PROXY_TOKEN) {
    return json({ error: "unauthorized" }, 401);
  }
  return null;
}

// MARK: - /chat → Anthropic

async function handleChat(request: Request, env: Env): Promise<Response> {
  if (!env.ANTHROPIC_API_KEY) {
    return json({ error: "anthropic_key_not_configured" }, 500);
  }

  let body: unknown;
  try {
    body = await request.json();
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

async function handleTTS(voiceId: string, request: Request, env: Env): Promise<Response> {
  if (!env.ELEVENLABS_API_KEY) {
    return json({ error: "elevenlabs_key_not_configured" }, 500);
  }

  // ElevenLabs voice IDs are alphanumeric. Reject anything else.
  if (!/^[A-Za-z0-9]+$/.test(voiceId)) {
    return json({ error: "invalid_voice_id" }, 400);
  }

  const bodyText = await request.text();

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
