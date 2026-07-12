# How it works & troubleshooting

## Architecture

```
┌────────────┐   Responses API (wire_api=responses)   ┌──────────────┐
│   Codex    │ ───────────────────────────────────────▶│   bridge     │ :4001
│ (CLI/TUI/  │                                        │ (translate)  │
│  ChatGPT)  │ ◀───────────────────────────────────────│              │
└────────────┘   Responses-shaped SSE / JSON           └──────┬───────┘
                                                              │ Chat Completions
                                                              │ (model passed through,
                                                              │  Authorization forwarded)
                                                              ▼
                                                   ┌──────────────────┐
                                                   │    OmniRoute     │ :20128
                                                   │  routes provider/ │
                                                   │  model → Vercel   │
                                                   │  AI Gateway       │
                                                   └────────┬─────────┘
                                                            │ https://ai-gateway.vercel.sh/v1
                                                            ▼
                                                   ┌──────────────────┐
                                                   │  Vercel AI       │
                                                   │  Gateway: zai/   │
                                                   │  glm-5.2,        │
                                                   │  minimax/m3 …    │
                                                   └──────────────────┘
```

### Why a bridge is needed

Codex ≥ 0.84 removed the `chat` `wire_api`; it now **only** emits the
Responses API (`/v1/responses`). OmniRoute (and most OpenAI-compatible
proxies) only implement `/v1/chat/completions`. The bridge is a pure
translator:

- `POST /v1/responses` → converts the Responses request into a Chat
  Completions request, calls OmniRoute, then re-serializes the response back
  into the Responses SSE/JSON shape Codex expects.
- `GET /v1/models` → pass-through to OmniRoute (only used for Codex's
  preflight; the real model list comes from `model_catalog.json`).
- **No key of its own** — it forwards the caller's `Authorization` header
  verbatim. Codex supplies `OMNIRUTE_API_KEY` (your OmniRoute key).

### Known fix in the bridge

Vercel AI Gateway **rejects `reasoning: null`** (strict schema), whereas
AgentRouter tolerated it. `src/translate.ts` therefore only sets
`chat.reasoning` when it is a non-null object. If you see
`Invalid input: expected object, received null (param: reasoning)`, this is
the fix — do not remove it.

## Model slug format

OmniRoute's Vercel AI Gateway provider uses
`vercel-ai-gateway/<provider>/<model>`:

| Model            | Slug                                      |
|------------------|-------------------------------------------|
| GLM 5.2          | `vercel-ai-gateway/zai/glm-5.2`           |
| GLM 5.2 Fast     | `vercel-ai-gateway/zai/glm-5.2-fast`      |
| MiniMax M3       | `vercel-ai-gateway/minimax/minimax-m3`    |

List all available slugs:
`curl https://ai-gateway.vercel.sh/v1/models | jq '.data[].id'`

## Troubleshooting

| Symptom | Cause / Fix |
|---------|-------------|
| `Missing environment variable: OMNIRUTE_API_KEY` | Your shell/terminal started before the var was set. `source ~/.zshrc` or open a new terminal. The ChatGPT.app GUI needs `launchctl setenv OMNIRUTE_API_KEY ...`. |
| `401` from bridge `/v1/models` | Expected without auth — the bridge forwards Codex's key; a bare `curl` has none. Normal. |
| `Invalid input: expected object, received null (param: reasoning)` | Bridge `translate.ts` fix missing — ensure `req.reasoning` is only set when non-null. |
| `404` from bridge | You hit `/v1/chat/completions` — the bridge only serves `/v1/responses`. Use Codex, not raw chat calls. |
| Model not in ChatGPT.app GUI picker | **Known Codex bug (#32119):** the Desktop picker only shows OpenAI-allowlisted slugs. Our `vercel-ai-gateway/...` slugs don't appear there. Use the CLI/TUI `/model`, or set `model=` in `config.toml` (shows "Custom"). |
| `connection refused :4001` | Bridge not running. `launchctl load ~/Library/LaunchAgents/com.user.codex-bridge.plist` (or run `bridge/start.sh`). |
| `connection refused :20128` | OmniRoute not running. Start your OmniRoute instance. |
| Vision/none: `No browser is available` | The browser backend is a ChatGPT.app desktop feature; it's not registered in a headless `codex exec` CLI session. Model-side tool calls still work (the model emitted the call correctly). Use the desktop app for live browser use. |

## Config files reference

- `~/.codex/config.toml` — `model`, `model_provider`, `model_catalog_json`,
  and the `[model_providers.openai-chat-completions]` block pointing at
  `http://localhost:4001/v1` with `env_key = "OMNIRUTE_API_KEY"`.
- `~/.codex/model-catalog.json` (or this repo's `codex/model-catalog.json`) —
  the catalog consumed by `/model`.
- `bridge/start.sh` — sets `OPENAI_BASE_URL` (OmniRoute) + `PORT`, runs `tsx`.
- `launchagent/com.user.codex-bridge.plist` — macOS autostart.
