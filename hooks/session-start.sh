#!/usr/bin/env bash
# Inject Decisions Hub routing guidance into every session.
# Output format: SessionStart hookSpecificOutput.additionalContext.

HUB_URL="${DECISIONS_HUB_URL:-http://127.0.0.1:5808/mcp}"
HUB_URL="${HUB_URL%/mcp}"

# If the hub is down, stay silent — native behaviour applies.
if ! curl -s -m 1 "${HUB_URL}/health" > /dev/null 2>&1; then
  exit 0
fi

# Hook input (session_id, cwd) arrives on stdin — forward it to the builder.
INPUT="$(cat)"
SENTINEL="${CLAUDE_PLUGIN_ROOT}/scripts/decisions-sentinel.sh"
# Controlling terminal + terminal app, so the Decisions app can bring this
# session's window forward. ps TT works even though hook stdin is a pipe.
SESSION_TTY="$(ps -o tty= -p $$ | tr -d ' ')"
[ "$SESSION_TTY" = "??" ] && SESSION_TTY=""
echo "$INPUT" | DECISIONS_TTY="$SESSION_TTY" DECISIONS_TERM_APP="${TERM_PROGRAM:-}" \
  python3 "${CLAUDE_PLUGIN_ROOT}/hooks/session_start.py" "$HUB_URL" "$SENTINEL"
