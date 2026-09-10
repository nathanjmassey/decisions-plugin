#!/usr/bin/env python3
"""SessionStart context builder for the Decisions plugin.

Reads the hook input (session_id, cwd) from stdin, queries the hub for
unacknowledged answers and the project's decision ledger, and emits the
routing guidance with this session's identity and sentinel command baked in.
"""
import json
import sys
import urllib.parse
import urllib.request

hub = sys.argv[1]
sentinel = sys.argv[2]

try:
    hook_input = json.load(sys.stdin)
except Exception:
    hook_input = {}

session_tag = hook_input.get("session_id") or "unknown-session"
cwd = hook_input.get("cwd") or ""


def fetch(path: str, params: dict) -> list:
    try:
        qs = urllib.parse.urlencode(params)
        with urllib.request.urlopen(f"{hub}{path}?{qs}", timeout=2) as r:
            return json.load(r)
    except Exception:
        return []


def answer_text(d: dict) -> str:
    ans = d.get("answer") or {}
    label = ans.get("answer")
    free = ans.get("free_text")
    steps = ans.get("selected_steps") or []
    if d.get("kind") == "review":
        parts = [f"verdict: {label}"]
        if steps:
            parts.append("steps: " + "; ".join(steps))
        if free:
            parts.append(free)
        return " — ".join(parts)
    if label == "__free_text__" and free:
        return free
    if label and free:
        return f"{label} (note: {free})"
    return label or "(unknown)"


# Register this session's terminal reference so the app can focus it.
try:
    import os
    payload = json.dumps({
        "project": cwd,
        "tty": os.environ.get("DECISIONS_TTY") or None,
        "term_app": os.environ.get("DECISIONS_TERM_APP") or None,
        "phase": "running",
        "agent": "Claude Code",
    }).encode()
    req = urllib.request.Request(
        f"{hub}/api/sessions/{urllib.parse.quote(session_tag)}/register",
        data=payload, headers={"Content-Type": "application/json"}, method="POST",
    )
    urllib.request.urlopen(req, timeout=2).read()
except Exception:
    pass

unacked = fetch("/api/decisions/unacknowledged", {"project": cwd}) if cwd else []
ledger = fetch("/api/decisions/ledger", {"project": cwd}) if cwd else []
# Ledger minus anything already surfaced as unacknowledged
unacked_ids = {d.get("id") for d in unacked}
ledger = [d for d in ledger if d.get("id") not in unacked_ids][:10]

sentinel_cmd = f'bash "{sentinel}" "{hub}" "{session_tag}" "{cwd}"'

context = f"""## Decision routing (Decisions Hub — live at {hub})

When you need a human decision, approval, or choice, use the `decisions` MCP server's
`request_decision` tool — the human answers in their Decisions app OR by replying in
this session (dual-channel). The `routing-decisions` skill has the full playbook —
consult it when routing a decision.

Your session identity for the hub:
- On EVERY `request_decision`, include `source: {{"agent": "Claude Code", "session_tag": "{session_tag}", "project": "{cwd}"}}`.
- After filing your first decision, arm the SENTINEL (one per session) via the Bash
  tool with `run_in_background: true`:
  `{sentinel_cmd}`
  It sleeps until the human answers any of this session's decisions in the app, then
  completes — waking you. When woken: fetch each listed decision with
  `decision_status` (this acknowledges it), apply the answer, and RE-ARM the
  sentinel with the same command if any of your decisions are still pending or you
  file more. Do not run per-decision polls or re-arm loops — the sentinel is the
  wake channel for everything, including queued-mode overrides.

Essentials:
- Autonomy in the prompt covers EXECUTION, not preferences. When you make a
  taste, product-feel, scope, or structure call the human will live with (what
  a thing looks like, how it is named, how hard it is, what gets included or
  cut), file it as a `mode: "queued"` decision with your choice as the default
  and keep working. "Use your judgment" means pick the default — it never means
  bypass the hub. A session that finishes real product work having filed zero
  decisions almost certainly mis-classified several of these.
- Log genuinely small internal choices (implementation details the human would
  not care to override) with `log_autodecision` — the audit trail is part of
  the contract, not optional.
- `request_decision` returns immediately with a decision_id; never sit idle after it.
- `mode: "queued"` + safe default for reversible calls: proceed with the returned
  default now; if the human later overrides it in the app, the sentinel wakes you —
  adapt to their choice at the next sensible point and say so.
- `mode: "blocking"`: do unblocked work first, ensure the sentinel is armed, and END
  YOUR TURN by restating the question with its numbered options in your final
  message so the human can also answer right here in the session.
- If the human answers IN-SESSION, immediately call `resolve_decision` with the
  decision_id and their choice so the app card clears. If it returns
  already_answered, they answered in the app first — respect that answer.
- Never rely on defaults for `reversibility: "hard_to_reverse"` decisions.
- Always fill context.title (a short human-readable topic for this session's work,
  e.g. "Focus timer" — it becomes the card headline in the app; NEVER omit it),
  recommendation.option, recommendation.reasoning, context.goal, context.progress,
  context.trigger — plain English, consequences not implementation.
- Grade `urgency` by consideration needed, not time: now = consider carefully,
  soon = think over, whenever = quick confirm.

Checkpoints:
- NEVER end a turn silently waiting for the human's go-ahead (a check-in, a
  phase gate, "say continue when ready"). That wait is a BLOCKING decision —
  file it: question = what you are waiting for, options = [{{"label":
  "Continue"}}] plus any real alternatives, mode "blocking". Arm the sentinel
  and end your turn. The human's tap in the app wakes you — they should never
  have to type in this chat just to unblock you.

Completion reviews:
- When you FINISH a body of work that produced a deliverable (feature, artefact,
  PR, document), file `request_review`: summary, original_ask, deliverables
  (label + ref the human can open), caveats, and 2-3 proposed next_steps. Same
  `source` fields as decisions. Then arm the sentinel and end your turn — the
  review card IS your handover; do not just stop silently.
- The verdict wakes you like a decision answer: `accept` = work ratified, wrap
  up and finish; `feedback` = apply the corrections in free_text, then file a
  fresh request_review; `next_steps` = continue with the selected_steps (plus
  any free_text direction)."""

if unacked:
    lines = "\n".join(
        f'- {d.get("id")}: "{d.get("question")}" -> {answer_text(d)}' for d in unacked
    )
    context += f"""

## Decisions answered while no session was listening — act on these NOW
{lines}
Apply each answer to the relevant work (or note it for when you touch that area),
and acknowledge each by calling `decision_status` with its id."""

if ledger:
    lines = "\n".join(
        f'- "{d.get("question")}" -> {answer_text(d)}' for d in ledger
    )
    context += f"""

## Decision ledger for this project (already applied — context only)
{lines}"""

print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": context,
    }
}))
