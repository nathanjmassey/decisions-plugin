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
`request_decision` tool — the human answers in their Decisions app. The
`routing-decisions` skill has the full playbook (schema quality rules, modes, and the
background sleep/wake wait pattern) — consult it when routing a decision.

Essentials:
- `request_decision` returns immediately with a decision_id; never sit idle after it.
- `mode: "queued"` + safe default for reversible calls: proceed with the returned
  default now; the human ratifies later.
- `mode: "blocking"` only when you cannot proceed: do unblocked work first, then park
  a background wait (see skill) and end your turn — you will be woken on the answer.
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
