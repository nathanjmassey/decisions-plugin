#!/usr/bin/env python3
"""Codex SessionStart hook for the Decisions Hub.

Ports the Claude Code plugin's session-start builder to Codex: registers the
session's terminal, reconciles unacknowledged answers + project ledger, and
injects Codex-adapted routing guidance (hold-the-turn awaits — Codex cannot
background tool calls, so there is no sentinel).
Output schema matches Codex's SessionStartHookSpecificOutputWire
(hookSpecificOutput.additionalContext).
"""
import json
import os
import random
import string
import sys
import urllib.parse
import urllib.request

hub = sys.argv[1]

raw = sys.stdin.read()
try:
    hook_input = json.loads(raw) if raw.strip() else {}
except Exception:
    hook_input = {}

# Debug capture: first interactive runs teach us the real input schema.
try:
    with open(os.path.expanduser("~/.codex/decisions-hooks/last-input.json"), "w") as f:
        f.write(raw or "{}")
except Exception:
    pass

session_tag = (
    hook_input.get("session_id")
    or hook_input.get("sessionId")
    or hook_input.get("thread_id")
    or hook_input.get("conversation_id")
    or ("codex-" + "".join(random.choices(string.ascii_lowercase + string.digits, k=8)))
)
if not str(session_tag).startswith("codex"):
    session_tag = f"codex-{session_tag}"
cwd = hook_input.get("cwd") or os.environ.get("PWD") or ""


def fetch(path: str, params: dict) -> list:
    try:
        qs = urllib.parse.urlencode(params)
        with urllib.request.urlopen(f"{hub}{path}?{qs}", timeout=2) as r:
            return json.load(r)
    except Exception:
        return []


# Register the terminal reference (tty/term app passed via env by the shell wrapper)
try:
    payload = json.dumps({
        "project": cwd or None,
        "tty": os.environ.get("DECISIONS_TTY") or None,
        "term_app": os.environ.get("DECISIONS_TERM_APP") or None,
    }).encode()
    req = urllib.request.Request(
        f"{hub}/api/sessions/{urllib.parse.quote(str(session_tag))}/register",
        data=payload, headers={"Content-Type": "application/json"}, method="POST",
    )
    urllib.request.urlopen(req, timeout=2).read()
except Exception:
    pass


def answer_text(d: dict) -> str:
    ans = d.get("answer") or {}
    label = ans.get("answer")
    free = ans.get("free_text")
    if label == "__free_text__" and free:
        return free
    if label and free:
        return f"{label} (note: {free})"
    return label or "(unknown)"


unacked = fetch("/api/decisions/unacknowledged", {"project": cwd}) if cwd else []
ledger = fetch("/api/decisions/ledger", {"project": cwd}) if cwd else []
unacked_ids = {d.get("id") for d in unacked}
ledger = [d for d in ledger if d.get("id") not in unacked_ids][:10]

context = f"""## Decision routing (Decisions Hub — live at {hub})

When you need a human decision, approval, or choice, use the `decisions` MCP
server's `request_decision` tool — the human answers in their Decisions app or
by replying here (dual-channel). If the hub becomes unreachable, fall back to
asking in-conversation.

Your session identity (already registered with the hub by this hook):
- On EVERY `request_decision`, include
  `source: {{"agent": "Codex", "session_tag": "{session_tag}", "project": "{cwd}"}}`.

Essentials:
- Autonomy in the prompt covers EXECUTION, not preferences. Taste, product-feel,
  scope, or structure calls the human will live with (appearance, naming,
  difficulty, what to include or cut) are filed as `mode: "queued"` decisions
  with your choice as `default.option` — proceed immediately and keep working.
  "Use your judgment" means pick the default, never bypass the hub. A session
  that finishes real product work having filed zero decisions almost certainly
  mis-classified several of these.
- Log small internal choices with `log_autodecision` — the audit trail is part
  of the contract.
- `mode: "blocking"` only when you genuinely cannot proceed. Never rely on a
  default for `reversibility: "hard_to_reverse"`.
- Always fill options[] (label + one-line consequence), recommendation.option +
  reasoning, context.title (short topic — it becomes the card headline),
  context.goal / progress / trigger, reversibility, urgency. Plain English —
  the human may read it on their phone with zero session context.

Waiting (you cannot background tool calls):
1. Do ALL work not blocked on the answer first.
2. When only the answer remains, call `await_decision` with
   `timeout_seconds: 3600` and let the call hold your turn — the hub completes
   it the moment the human answers. If it returns pending, call it again.
3. Before a long wait, make your last message restate the question and its
   numbered options so the human can also answer right here.
4. If the human answers in-conversation, immediately call `resolve_decision`
   with their choice (clears the app card; `already_answered` means the app won
   — respect that answer).
5. Before finishing a work phase, `decision_status` each queued decision you
   proceeded on; if the human overrode your default, adapt and say so."""

if unacked:
    lines = "\n".join(
        f'- {d.get("id")}: "{d.get("question")}" -> {answer_text(d)}' for d in unacked
    )
    context += f"""

## Decisions answered while no session was listening — act on these NOW
{lines}
Apply each answer to the relevant work and acknowledge each by calling
`decision_status` with its id."""

if ledger:
    lines = "\n".join(f'- "{d.get("question")}" -> {answer_text(d)}' for d in ledger)
    context += f"""

## Decision ledger for this project (already applied — context only)
{lines}"""

print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": context,
    }
}))
