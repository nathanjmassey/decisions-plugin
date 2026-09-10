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
echo "$INPUT" | python3 "${CLAUDE_PLUGIN_ROOT}/hooks/session_start.py" "$HUB_URL" "$SENTINEL"
