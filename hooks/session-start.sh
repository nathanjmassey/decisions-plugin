#!/usr/bin/env bash
# Inject Decisions Hub routing guidance into every session.
# Output format: SessionStart hookSpecificOutput.additionalContext.

HUB_URL="${DECISIONS_HUB_URL:-http://127.0.0.1:5808}"
HUB_URL="${HUB_URL%/mcp}"

# If the hub is down, stay silent — native behaviour applies.
if ! curl -s -m 1 "${HUB_URL}/health" > /dev/null 2>&1; then
  exit 0
fi

python3 - "$HUB_URL" <<'EOF'
import json, sys

hub = sys.argv[1]
context = f"""## Decision routing (Decisions Hub — live at {hub})

When you need a human decision, approval, or choice, use the `decisions` MCP server's
`request_decision` tool — the human answers in their Decisions app OR by replying in
this session (dual-channel). The `routing-decisions` skill has the full playbook —
consult it when routing a decision.

Essentials:
- `request_decision` returns immediately with a decision_id; never sit idle after it.
- `mode: "queued"` + safe default for reversible calls: proceed with the returned
  default now, AND arm the same background await on it (see skill) — the human may
  ratify or OVERRIDE later. When the wake delivers an answer that differs from the
  default you proceeded on, adapt to the human's choice at the next sensible point
  and say so.
- `mode: "blocking"`: do unblocked work first, then park a background wait (see
  skill), and END YOUR TURN by restating the question with its numbered options in
  your final message so the human can also answer right here in the session.
- If the human answers IN-SESSION, immediately call `resolve_decision` with the
  decision_id and their choice so the app card clears. If it returns
  already_answered, they answered in the app first — respect that answer.
- Never rely on defaults for `reversibility: "hard_to_reverse"` decisions.
- Always fill recommendation.option, recommendation.reasoning, context.goal,
  context.progress, context.trigger — plain English, consequences not implementation."""

print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": context,
    }
}))
EOF
