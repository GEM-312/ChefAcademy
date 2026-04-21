# ChefAcademy API Worker

Cloudflare Worker that acts as a secure proxy between the iOS app and external APIs (Anthropic Claude, USDA FoodData Central). API keys live here as server-side secrets and never ship in the app binary.

## First-time deploy (Phase 1)

From this directory (`cloudflare-worker/`):

```bash
npm install
npx wrangler deploy
```

After deploy, Wrangler prints your Worker URL — something like:

```
https://chefacademy-api.pollak.workers.dev
```

Test it:

```bash
curl https://chefacademy-api.pollak.workers.dev/health
```

You should get back:

```json
{"status":"ok","worker":"chefacademy-api","time":"2026-04-21T..."}
```

If that works, Phase 1 is done — tell Claude and we move to Phase 2 (adding `/chat` + secret).

## Day-to-day commands

- `npm run deploy` — push current code to Cloudflare
- `npm run tail` — stream live logs from the deployed Worker
- `npm run dev` — run the Worker locally on `http://localhost:8787` for testing

## Adding secrets (Phase 2+)

Never commit keys. Add them via Wrangler — they're stored encrypted on Cloudflare's side:

```bash
npx wrangler secret put ANTHROPIC_API_KEY
# paste key when prompted, hit enter
```

To rotate a key later: run the same command with a new value. To remove: `npx wrangler secret delete <NAME>`.
