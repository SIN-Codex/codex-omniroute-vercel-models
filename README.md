# codex-omniroute-vercel-models

Configure [Codex](https://github.com/openai/codex) (CLI + ChatGPT.app) to run on
**Vercel AI Gateway** models — e.g. **Z.ai GLM 5.2** and **MiniMax M3** (vision) —
routed through your local **OmniRoute** instance, with a tiny transparent
**Responses→Chat bridge** in between.

```
 Codex  ──Responses API──▶  bridge (:4001)  ──Chat Completions──▶  OmniRoute (:20128)  ──▶  Vercel AI Gateway
 (glm-5.2 / minimax-m3)        (translate)                        (routes zai/ minimax/ …)
```

> Why the bridge? Codex ≥ 0.84 only speaks the **Responses API** (`wire_api =
> "responses"`). OmniRoute (and most OpenAI-compatible proxies) only speak
> **Chat Completions**. The bridge translates between them, so Codex can use
> any OmniRoute-backed model unchanged.

---

## What's in this repo

| Path | Purpose |
|------|---------|
| `codex/config.toml.example` | The Codex provider/model/catalog settings to merge into `~/.codex/config.toml` |
| `codex/model-catalog.json`   | Model catalog so `/model` in the TUI lists the Vercel models |
| `bridge/`                    | The Responses→Chat translation server (`src/`, `package.json`, `start.sh`) |
| `launchagent/com.user.codex-bridge.plist` | macOS LaunchAgent (autostart + keep-alive) |
| `scripts/install.sh`         | Sets up the bridge + LaunchAgent and prints the env/config to add |
| `docs/how-it-works.md`       | Architecture & troubleshooting deep-dive |

---

## Prerequisites

> ⚠️ **OmniRoute is a HARD REQUIREMENT in this setup.** It must be
> **installed and running locally** (`http://localhost:20128/v1`) for the
> whole chain to work — the bridge forwards to it. There is no way around it
> *in the default config*. (An optional bypass that talks to Vercel directly,
> removing the OmniRoute dependency, is described at the bottom.)
>
> OmniRoute is your own local model router (configured e.g. in
> `~/.config/opencode/opencode.json` under `providers.omniroute`, or via the
> `omniroute-config` skill). Make sure:
> - it is installed and **currently running** (the bridge connects to
>   `localhost:20128`),
> - the `vercel-ai-gateway` provider is enabled with models
>   `zai/glm-5.2`, `minimax/minimax-m3`, …,
> - you know your OmniRoute API key (used as `OMNIRUTE_API_KEY`).

1. **Codex CLI** ≥ 0.84 — `npm i -g @openai/codex` (or your package manager).
2. **OmniRoute** running locally on `http://localhost:20128/v1` with the
   `vercel-ai-gateway` provider configured (models `zai/glm-5.2`,
   `minimax/minimax-m3`, …). Your OmniRoute API key lives in
   `~/.config/opencode/opencode.json` under `providers.omniroute.options.apiKey`
   (or wherever you configured OmniRoute).
3. **Node.js 24** (the bridge uses `tsx --experimental-strip-types`).

---

## Quick start

```bash
git clone https://github.com/SIN-Codex/codex-omniroute-vercel-models.git
cd codex-omniroute-vercel-models
bash scripts/install.sh
```

`install.sh` will:

- `npm install` the bridge (needs `node_modules`).
- Copy `launchagent/com.user.codex-bridge.plist` to
  `~/Library/LaunchAgents/`, rewriting the `/PATH/TO/...` placeholders to this
  repo's real location, then `launchctl load` it (autostart on boot).
- Print the **two things you must do manually**:
  1. Merge `codex/config.toml.example` into `~/.codex/config.toml`.
  2. Export `OMNIRUTE_API_KEY` (your OmniRoute key) in `~/.zshrc` **and** via
     `launchctl setenv OMNIRUTE_API_KEY "<key>"` (so the ChatGPT.app GUI can read it).

### Manual setup (if you skip the script)

```bash
# 1) Bridge
cd bridge && npm install
# either run it directly:
PORT=4001 OPENAI_BASE_URL=http://localhost:20128/v1 ./start.sh
# or install the LaunchAgent (macOS):
#   edit launchagent/com.user.codex-bridge.plist → replace /PATH/TO/... with this dir
#   cp launchagent/com.user.codex-bridge.plist ~/Library/LaunchAgents/
#   launchctl load ~/Library/LaunchAgents/com.user.codex-bridge.plist

# 2) Codex config — merge codex/config.toml.example into ~/.codex/config.toml,
#    fix the model_catalog_json path, set model_provider + env_key.

# 3) OmniRoute key (the value from your OmniRoute config)
echo 'export OMNIRUTE_API_KEY="<your-omniroute-key>"' >> ~/.zshrc
launchctl setenv OMNIRUTE_API_KEY "<your-omniroute-key>"
```

---

## Using it

Start Codex as usual. GLM 5.2 is the default:

```bash
codex                          # TUI — default model = GLM 5.2
codex exec -m "vercel-ai-gateway/zai/glm-5.2" "..."   # explicit GLM
codex exec -m "vercel-ai-gateway/minimax/minimax-m3" "..."  # explicit MiniMax (vision)
```

Inside the TUI use **`/model`** to switch — both GLM 5.2 (Fast) and MiniMax M3
appear there (they come from `model-catalog.json`).

### Model picker in the ChatGPT.app GUI

> ⚠️ The ChatGPT.app **Desktop picker only shows OpenAI-allowlisted model
> slugs** (known Codex bug — see `docs/how-it-works.md`, issue #32119). Our
> `vercel-ai-gateway/...` slugs are not in that allowlist, so they will **not**
> appear in the GUI picker. Use the **CLI/TUI** (`/model`) to select them; the
> GUI still works if you set `model = "vercel-ai-gateway/zai/glm-5.2"` directly
> in `config.toml` (it then shows "Custom").

### Vision

MiniMax M3 is registered with `input_modalities: ["text","image"]`. For image
tasks, switch to it explicitly (`/model` → MiniMax M3). Codex does **not**
auto-route by modality — the model choice is always explicit.

---

## Adding more Vercel models

1. Find the slug in the Vercel AI Gateway catalog:
   `curl https://ai-gateway.vercel.sh/v1/models | jq '.data[].id'`
   Format: `vercel-ai-gateway/<provider>/<model>` (e.g. `zai/glm-5.2`,
   `minimax/minimax-m3`, `google/gemini-3-flash`).
2. Add an entry to `codex/model-catalog.json` (copy an existing block; set
   `slug`, `display_name`, and `input_modalities` for vision models).
3. Done — `/model` picks it up on next launch.

---

## Optional: bypass OmniRoute (direct Vercel AI Gateway)

If you do **not** want a local OmniRoute dependency, point the bridge straight
at Vercel AI Gateway instead:

1. In `bridge/start.sh` set:
   ```bash
   export OPENAI_BASE_URL="https://ai-gateway.vercel.sh/v1"
   ```
2. Use a **Vercel AI Gateway API key** as `OMNIRUTE_API_KEY` (a real Vercel
   AI Gateway key, not the OmniRoute one).
3. In `codex/model-catalog.json` change the slugs from
   `vercel-ai-gateway/zai/glm-5.2` → `zai/glm-5.2` and
   `vercel-ai-gateway/minimax/minimax-m3` → `minimax/minimax-m3`
   (raw Vercel slugs, no `vercel-ai-gateway/` prefix), and update
   `config.toml.example` + `model` accordingly.

Everything else (bridge, Codex config shape, LaunchAgent) stays identical.
With this variant OmniRoute is **not** required at all.

## Security note

No secrets are committed to this repo. The bridge is **credential-free**: it
forwards Codex's `Authorization` header verbatim to OmniRoute, so the only
secret is your **OmniRoute API key** in `OMNIRUTE_API_KEY` (kept in your shell
profile / `launchctl`, never in these files).

## License

MIT.
