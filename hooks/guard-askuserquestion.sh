#!/usr/bin/env bash
# PreToolUse guard on AskUserQuestion: when the Decisions Hub is reachable,
# steer the model to request_decision instead. Fails open — hub down or
# guard disabled means native AskUserQuestion proceeds untouched.

if [ "${DECISIONS_GUARD:-on}" = "off" ]; then
  exit 0
fi

HUB_URL="${DECISIONS_HUB_URL:-http://127.0.0.1:5808}"
HUB_URL="${HUB_URL%/mcp}"

if ! curl -s -m 1 "${HUB_URL}/health" > /dev/null 2>&1; then
  exit 0
fi

python3 - <<'EOF'
import json

print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "deny",
        "permissionDecisionReason": (
            "The Decisions Hub is live on this machine — route this question through "
            "the `decisions` MCP server's request_decision tool instead of "
            "AskUserQuestion, then follow the routing-decisions skill: park a "
            "background wait, and end your turn restating the question with numbered "
            "options so the human can answer here in the session OR in the Decisions "
            "app (dual-channel). If they answer in-session, call resolve_decision to "
            "clear the app card; if it returns already_answered, the app answer "
            "stands."
        ),
    }
}))
EOF
