#!/bin/bash
# LaunchAgent / manual wrapper for the Codex -> OmniRoute Responses bridge.
#
# What it does:
#   - Starts the bridge that translates Codex's Responses-API traffic into
#     OpenAI Chat-Completions and forwards it to OmniRoute (localhost:20128),
#     which routes to the Vercel AI Gateway (Z.ai GLM, MiniMax, ...).
#   - The bridge is credential-free: it forwards the caller's Authorization
#     header verbatim, so Codex supplies the OmniRoute key via OMNIRUTE_API_KEY.
#
# No secrets are stored here. Adjust OPENAI_BASE_URL only if your OmniRoute
# listens elsewhere.
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

export PATH="/opt/homebrew/opt/node@24/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export OPENAI_BASE_URL="${OPENAI_BASE_URL:-http://localhost:20128/v1}"
export PORT="${PORT:-4001}"
export LOG_LEVEL="${LOG_LEVEL:-info}"

cd "$SCRIPT_DIR"
exec ./node_modules/.bin/tsx --experimental-strip-types src/index.ts
