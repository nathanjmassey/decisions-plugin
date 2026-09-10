#!/usr/bin/env bash
# Codex SessionStart hook wrapper — Decisions Hub integration.
HUB_URL="${DECISIONS_HUB_URL:-http://127.0.0.1:5808/mcp}"
HUB_URL="${HUB_URL%/mcp}"

# Hub down -> stay silent; native behaviour applies.
if ! curl -s -m 1 "${HUB_URL}/health" > /dev/null 2>&1; then
  exit 0
fi

INPUT="$(cat)"

# Hooks may run without a controlling tty — walk up the process tree.
find_tty() {
  local pid="$1" t
  for _ in 1 2 3; do
    [ -z "$pid" ] && break
    t="$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ')"
    if [ -n "$t" ] && [ "$t" != "??" ]; then echo "$t"; return; fi
    pid="$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')"
  done
}
SESSION_TTY="$(find_tty $$)"

# Liveness heartbeater: watch the codex process; 60s pings + phase=ended on death.
find_codex_pid() {
  local pid="$PPID" cmd
  for _ in 1 2 3 4; do
    [ -z "$pid" ] || [ "$pid" = "0" ] && break
    cmd="$(ps -o comm= -p "$pid" 2>/dev/null)"
    case "$cmd" in *codex*) echo "$pid"; return;; esac
    pid="$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')"
  done
}
SESSION_ID="$(echo "$INPUT" | python3 -c 'import json,sys; sid=json.load(sys.stdin).get("session_id",""); print(f"codex-{sid}" if sid and not str(sid).startswith("codex") else sid)' 2>/dev/null)"
CODEX_PID="$(find_codex_pid)"
if [ -n "$SESSION_ID" ] && [ -n "$CODEX_PID" ]; then
  nohup bash "$HOME/.codex/decisions-hooks/decisions-heartbeat.sh" \
    "$HUB_URL" "$SESSION_ID" "$CODEX_PID" > /dev/null 2>&1 &
fi

echo "$INPUT" | DECISIONS_TTY="$SESSION_TTY" DECISIONS_TERM_APP="${TERM_PROGRAM:-}" \
  python3 "$HOME/.codex/decisions-hooks/codex_session_start.py" "$HUB_URL"
