# Codex integration

Codex CLI (>= 0.153) integration for the Decisions Hub — the counterpart of the
Claude Code plugin, within Codex's constraints (no backgrounding: waits hold
the turn via await_decision; no sentinel).

Install:
1. Enrol the MCP server in `~/.codex/config.toml`:
   `[mcp_servers.decisions]` with `type = "http"`, `url = "http://127.0.0.1:5808/mcp"`,
   `tool_timeout_sec = 3900`.
2. Copy `codex_session_start.py` + `session-start.sh` to `~/.codex/decisions-hooks/`.
3. Merge `hooks.json` into `~/.codex/hooks.json` (adjust the absolute path).
4. In an interactive Codex session run `/hooks` and TRUST the hook.
5. Optionally install `AGENTS.md` guidance (../codex-agents fallback) for
   environments where hooks are unavailable.

The SessionStart hook: health-checks the hub, registers the session's terminal
(tty + term app -> app's open-terminal button/glow), injects routing guidance,
and reconciles unacknowledged answers + the project decision ledger.
