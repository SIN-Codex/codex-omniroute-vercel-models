#!/bin/bash
# Install helper for codex-omniroute-vercel-models.
# Sets up the bridge + LaunchAgent and prints the manual steps you must do
# (Codex config merge + OMNIRUTE_API_KEY). Safe to re-run.
set -e

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BRIDGE_DIR="$REPO_DIR/bridge"
PLIST_SRC="$REPO_DIR/launchagent/com.user.codex-bridge.plist"
PLIST_DST="$HOME/Library/LaunchAgents/com.user.codex-bridge.plist"

echo "==> Repo: $REPO_DIR"

# 1) Bridge deps
echo "==> Installing bridge deps (npm install in bridge/)..."
( cd "$BRIDGE_DIR" && npm install )

# 2) LaunchAgent — rewrite /PATH/TO/... placeholders to this repo
echo "==> Installing LaunchAgent..."
mkdir -p "$HOME/Library/LaunchAgents"
sed "s#/PATH/TO/codex-omniroute-vercel-models#$REPO_DIR#g" "$PLIST_SRC" > "$PLIST_DST"
launchctl unload "$PLIST_DST" 2>/dev/null || true
launchctl load "$PLIST_DST"
sleep 2
echo "    bridge status: $(launchctl list | grep -c com.user.codex-bridge) loaded"

# 3) Remind about config + key
echo
echo "==================================================================="
echo "  MANUAL STEPS REMAINING"
echo "==================================================================="
echo
echo "1) Merge this into ~/.codex/config.toml (fix the catalog path):"
echo "   ----"
sed 's#/PATH/TO/codex-omniroute-vercel-models#'"$REPO_DIR"'#g' "$REPO_DIR/codex/config.toml.example"
echo "   ----"
echo
echo "2) Set your OmniRoute API key (from ~/.config/opencode/opencode.json"
echo "   -> providers.omniroute.options.apiKey):"
echo "     echo 'export OMNIRUTE_API_KEY=\"<your-omniroute-key>\"' >> ~/.zshrc"
echo "     launchctl setenv OMNIRUTE_API_KEY \"<your-omniroute-key>\""
echo
echo "3) Verify:"
echo "     codex exec -m \"vercel-ai-gateway/zai/glm-5.2\" \"say hi in one word\""
echo "==================================================================="
