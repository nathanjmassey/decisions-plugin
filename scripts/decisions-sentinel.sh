#!/usr/bin/env bash
# Decisions sentinel — ONE durable wake channel per agent session.
#
# Long-polls the hub's session wake endpoint in an internal loop: timeouts
# and connection errors reconnect silently; the script only EXITS when a
# real wake event arrives (a decision of this session answered out of
# session). That exit fires the harness's background-task notification and
# wakes the agent. Run via the Bash tool with run_in_background: true.
#
# Usage: decisions-sentinel.sh <hub_base_url> <session_tag> [project_dir]

HUB="${1:?usage: decisions-sentinel.sh <hub_base_url> <session_tag> [project_dir]}"
TAG="${2:?session tag required}"
PROJECT="${3:-}"

while :; do
  RESP="$(curl -s -G --max-time 3700 "${HUB}/api/sessions/${TAG}/wake" \
    --data-urlencode "timeout_seconds=3600" \
    --data-urlencode "project=${PROJECT}" 2>/dev/null)"
  case "$RESP" in
    *'"event":"answered"'*)
      echo "DECISIONS WAKE: the human answered decision(s) for this session:"
      echo "$RESP"
      echo "Fetch each with decision_status (this acknowledges it), apply the answer, then re-arm this sentinel."
      exit 0
      ;;
    *)
      sleep 3
      ;;
  esac
done
