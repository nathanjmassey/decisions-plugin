# Decisions plugin for Claude Code

Routes Claude Code's questions to a human through the [Decisions Hub](https://github.com/nathanjmassey/decisions-hub): instead of blocking a terminal with `AskUserQuestion`, the agent files a decision-grade brief that the human answers in the Decisions app on their own schedule. The session sleeps at zero cost and wakes the moment the answer lands.

## What it bundles

| Component | Purpose |
|---|---|
| MCP server config | Enrols the `decisions` hub server (`DECISIONS_HUB_URL`, default `http://127.0.0.1:5808/mcp`) |
| SessionStart hook | Injects routing guidance into every session — only when the hub is reachable |
| `routing-decisions` skill | The full playbook: modes, brief quality, the background sleep/wake wait |
| AskUserQuestion guard | PreToolUse hook that steers questions to the hub when it is live; fails open when it is not |

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
