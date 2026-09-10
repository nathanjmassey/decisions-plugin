#!/usr/bin/env bash
# Fire-and-forget lifecycle-phase heartbeat: phase.sh <phase>
# Wired to UserPromptSubmit (working), Stop (idle), SessionEnd (ended).
# The register endpoint doubles as heartbeat (bumps last_seen).

PHASE="$1"
HUB_URL="${DECISIONS_HUB_URL:-http://127.0.0.1:5808/mcp}"
HUB_URL="${HUB_URL%/mcp}"

INPUT="$(cat)"
SESSION_ID="$(echo "$INPUT" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("session_id",""))' 2>/dev/null)"
[ -z "$SESSION_ID" ] && exit 0

curl -s -m 2 -X POST "${HUB_URL}/api/sessions/${SESSION_ID}/register" \
  -H "Content-Type: application/json" \
  -d "{\"phase\": \"${PHASE}\"}" > /dev/null 2>&1

exit 0
