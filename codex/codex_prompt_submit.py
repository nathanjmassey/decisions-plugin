#!/usr/bin/env python3
"""Codex UserPromptSubmit hook: per-turn reconcile for the Decisions Hub.

Codex cannot be woken while idle, so answers that land after a turn ends
would otherwise sit unseen. This hook runs on every user prompt and injects
any answered-but-unacknowledged decisions for this session/project, so the
session catches up the moment it is next active.
"""
import json
import os
import sys
import urllib.parse
import urllib.request

hub = sys.argv[1]

try:
    hook_input = json.loads(sys.stdin.read() or "{}")
except Exception:
    hook_input = {}

session_tag = hook_input.get("session_id") or ""
if session_tag and not str(session_tag).startswith("codex"):
    session_tag = f"codex-{session_tag}"
cwd = hook_input.get("cwd") or os.environ.get("PWD") or ""


# Phase heartbeat: a user prompt means the agent is about to work.
try:
    _payload = json.dumps({"phase": "working"}).encode()
    _req = urllib.request.Request(
        f"{hub}/api/sessions/{urllib.parse.quote(str(session_tag))}/register",
        data=_payload, headers={"Content-Type": "application/json"}, method="POST",
    )
    urllib.request.urlopen(_req, timeout=2).read()
except Exception:
    pass


def fetch(params: dict) -> list:
    try:
        qs = urllib.parse.urlencode(params)
        with urllib.request.urlopen(f"{hub}/api/decisions/unacknowledged?{qs}", timeout=2) as r:
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


# Session-tagged answers first; fall back to project scope.
unacked = fetch({"session_tag": session_tag}) if session_tag else []
if not unacked and cwd:
    unacked = fetch({"project": cwd})

if not unacked:
    sys.exit(0)

lines = "\n".join(
    f'- {d.get("id")}: "{d.get("question")}" -> {answer_text(d)}' for d in unacked
)
context = f"""## Decisions Hub — the human answered while you were idle
{lines}
Apply each answer to the relevant work now (if it matches the default you
proceeded on, simply confirm; if it differs, adapt and say so). Acknowledge
each by calling `decision_status` with its id."""

print(json.dumps({
    "hookSpecificOutput": {
        "hookEventName": "UserPromptSubmit",
        "additionalContext": context,
    }
}))
