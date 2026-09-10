#!/usr/bin/env bash
# Notification hook: report involuntary blocks. permission_prompt = the
# session is stuck on a local permission dialog — invisible to the hub
# unless we say so. Other notification types are ignored.

HUB_URL="${DECISIONS_HUB_URL:-http://127.0.0.1:5808/mcp}"
HUB_URL="${HUB_URL%/mcp}"

INPUT="$(cat)"
read -r SESSION_ID NTYPE <<< "$(echo "$INPUT" | python3 -c '
import json, sys
d = json.load(sys.stdin)
print(d.get("session_id", ""), d.get("notification_type") or d.get("type") or "")
' 2>/dev/null)"

[ -z "$SESSION_ID" ] && exit 0
[ "$NTYPE" = "permission_prompt" ] || exit 0

curl -s -m 2 -X POST "${HUB_URL}/api/sessions/${SESSION_ID}/register" \
  -H "Content-Type: application/json" \
  -d '{"phase": "blocked", "agent": "Claude Code"}' > /dev/null 2>&1

exit 0
