// ChefAcademy API — Cloudflare Worker
//
// Secure proxy between the iOS app and external APIs (Anthropic Claude,
// USDA FoodData Central). API keys live here as server-side secrets —
// they never ship in the iOS app binary.
//
// Endpoints:
//   GET  /health           → smoke test, no auth
//   POST /chat             → proxies to Anthropic Messages API
//   GET  /usda/:fdcId      → proxies to USDA FoodData Central (Phase 2c)
//
// Auth (Phase 2): all non-/health routes require X-Proxy-Token header.
// This is a temporary shared-secret speed bump. Phase 3 replaces it with
// Apple App Attest for cryptographic proof the request came from our app.

export interface Env {
  ANTHROPIC_API_KEY: string;
  PROXY_TOKEN: string;
  USDA_API_KEY?: string;
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

// MARK: - Helpers

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}
