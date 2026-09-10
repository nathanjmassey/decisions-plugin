#!/usr/bin/env bash
# Liveness heartbeater: decisions-heartbeat.sh <hub> <session_tag> <watch_pid>
# Spawned (detached) by the SessionStart hook. Checks the watched agent
# process every 2s (kill -0 is a syscall — free) so death is reported as
# phase=ended within seconds, crash-proof and independent of SessionEnd.
# Posts a heartbeat register every 10th check (~20s) to keep last_seen fresh
# without network chatter.

HUB="$1"
TAG="$2"
WATCH_PID="$3"

[ -z "$HUB" ] || [ -z "$TAG" ] || [ -z "$WATCH_PID" ] && exit 0

# One heartbeater per session tag.
PIDFILE="/tmp/decisions-heartbeat-${TAG}.pid"
if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  exit 0
fi
echo $$ > "$PIDFILE"

TICK=0
while kill -0 "$WATCH_PID" 2>/dev/null; do
  if [ $((TICK % 10)) -eq 0 ]; then
    curl -s -m 2 -X POST "${HUB}/api/sessions/${TAG}/register" \
      -H "Content-Type: application/json" -d '{}' > /dev/null 2>&1
  fi
  TICK=$((TICK + 1))
  sleep 2
done

curl -s -m 2 -X POST "${HUB}/api/sessions/${TAG}/register" \
  -H "Content-Type: application/json" -d '{"phase": "ended"}' > /dev/null 2>&1
rm -f "$PIDFILE"
exit 0
