#!/usr/bin/env bash
# Liveness heartbeater: decisions-heartbeat.sh <hub> <session_tag> <watch_pid>
# Spawned (detached) by the SessionStart hook. Pings the hub every 60s while
# the watched agent process is alive; posts phase=ended when it disappears —
# crash-proof death detection that does not rely on SessionEnd firing.

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

while kill -0 "$WATCH_PID" 2>/dev/null; do
  curl -s -m 2 -X POST "${HUB}/api/sessions/${TAG}/register" \
    -H "Content-Type: application/json" -d '{}' > /dev/null 2>&1
  sleep 60
done

curl -s -m 2 -X POST "${HUB}/api/sessions/${TAG}/register" \
  -H "Content-Type: application/json" -d '{"phase": "ended"}' > /dev/null 2>&1
rm -f "$PIDFILE"
exit 0
