#!/usr/bin/env bash
HUB_URL="${DECISIONS_HUB_URL:-http://127.0.0.1:5808/mcp}"
HUB_URL="${HUB_URL%/mcp}"
if ! curl -s -m 1 "${HUB_URL}/health" > /dev/null 2>&1; then
  exit 0
fi
python3 "$HOME/.codex/decisions-hooks/codex_prompt_submit.py" "$HUB_URL"
