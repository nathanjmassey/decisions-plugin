# Decisions plugin for Claude Code

Routes Claude Code's questions to a human through the [Decisions Hub](https://github.com/nathanjmassey/decisions-hub): instead of blocking a terminal with `AskUserQuestion`, the agent files a decision-grade brief that the human answers in the Decisions app on their own schedule. The session sleeps at zero cost and wakes the moment the answer lands.

## What it bundles

| Component | Purpose |
|---|---|
| MCP server config | Enrols the `decisions` hub server (`DECISIONS_HUB_URL`, default `http://127.0.0.1:5808/mcp`) |
| SessionStart hook | Injects routing guidance + session identity, and reconciles answers that landed while no session was listening — only when the hub is reachable |
| `routing-decisions` skill | The full playbook: modes, brief quality, the session sentinel wake channel |
| Session sentinel script | One durable background long-poll per session — reconnects internally, exits only on a real wake |
| AskUserQuestion guard | PreToolUse hook that steers questions to the hub when it is live; fails open when it is not |

## How a routed decision behaves

- `request_decision` returns instantly; the agent keeps working on anything not blocked on the answer.
- The agent arms one **session sentinel** (a background long-poll on the hub's session wake endpoint) that survives timeouts and reconnects by itself — it completes only when the human answers, waking the sleeping session. The session sleeps at zero token cost.
- **Dual-channel:** answer in the Decisions app (the sentinel wakes the session) or reply in the chat (the agent records it via `resolve_decision`, clearing the app card). First answer wins.
- **Queued mode:** the agent proceeds on a safe default immediately; a later human override in the app rides the same sentinel wake and the agent adapts.
- **Never lost:** answers are redelivered until an agent acknowledges them. A crashed terminal or a `/clear` is fine — the next session in that project receives unacknowledged answers (and a compact decision ledger) at startup via the SessionStart hook.

## Install

```
claude plugin marketplace add nathanjmassey/decisions-plugin
claude plugin install decisions@decisions-marketplace
```

Or agent-led: tell your existing Claude Code session to run the two commands above.

A running Decisions Hub is required for the plugin to do anything; without one, every component stands down and Claude Code behaves natively.

## Configuration

Environment variables (set in your shell profile or `settings.json` `env`):

- `DECISIONS_HUB_URL` — hub base URL (default `http://127.0.0.1:5808/mcp`); point at a remote hub for distributed setups
- `DECISIONS_GUARD=off` — disable the AskUserQuestion guard while keeping enrolment and guidance
