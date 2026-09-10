#!/usr/bin/env bash
# Codex SessionStart hook wrapper — Decisions Hub integration.
HUB_URL="${DECISIONS_HUB_URL:-http://127.0.0.1:5808/mcp}"
HUB_URL="${HUB_URL%/mcp}"

# Hub down -> stay silent; native behaviour applies.
if ! curl -s -m 1 "${HUB_URL}/health" > /dev/null 2>&1; then
  exit 0
fi

SESSION_TTY="$(ps -o tty= -p $$ | tr -d ' ')"
[ "$SESSION_TTY" = "??" ] && SESSION_TTY=""

DECISIONS_TTY="$SESSION_TTY" DECISIONS_TERM_APP="${TERM_PROGRAM:-}" \
  python3 "$HOME/.codex/decisions-hooks/codex_session_start.py" "$HUB_URL"
