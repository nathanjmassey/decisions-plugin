---
name: routing-decisions
description: Route a decision, approval, or choice to the human via the Decisions Hub (request_decision on the decisions MCP server) instead of AskUserQuestion. Covers blocking vs queued modes, defaults and reversibility, brief-quality rules, and the background sleep/wake wait pattern. Use whenever you need human input while working.
---

# Routing decisions to the human

The Decisions Hub queues your questions; the human answers them in the Decisions app
on their own schedule. Your job: send a decision-grade brief, then either proceed on a
default (queued) or sleep until the answer lands (blocking). Never poll in a loop,
never sit idle in the foreground.

## 1. Choose the mode

- **queued** — the decision is reversible and you can safely proceed on a sensible
  default. This is the REQUIRED mode for taste/product-feel/scope calls the human
  will live with (appearance, naming, difficulty, structure, what to include or
  cut) — even under a maximally autonomous prompt. Autonomy governs execution;
  preferences stay routed. "Use your judgment" = pick the default, not skip the hub. The tool returns the default immediately (`answered_by: "default"`);
  proceed with it. Make sure the session sentinel is armed (section 3) — the human
  may ratify your default or OVERRIDE it in the app, and the sentinel wake is how
  you find out. If a delivered answer differs from the default you proceeded on,
  adapt your work to the human's choice at the next sensible point and say you did.
  At each stage boundary, if any queued decision is still unanswered, carry on —
  the default stands until told otherwise.
- **blocking** — you genuinely cannot proceed without the answer. Use sparingly.

Never rely on a default for `reversibility: "hard_to_reverse"` — those must be
answered by a human, always.

## 2. Send a decision-grade brief

Call `request_decision` with ALL of:

- `question` — one clear sentence.
- `options[]` — label + one-line description including the consequence of picking it.
- `recommendation.option` + `recommendation.reasoning` — your call and why. Always
  recommend; the human ratifies faster than they deliberate.
- `context.title`, `context.goal`, `context.progress`, `context.trigger` — plain
  English, consequences not implementation. The human may be on their phone hours
  from now with zero session context.
- `mode`, `reversibility`, `urgency` (`now` / `soon` / `whenever`) — urgency grades how much CONSIDERATION the human should give, not time
pressure: `now` = consider carefully (major forks, costly to revisit),
`soon` = think over (real choice, moderate stakes), `whenever` = quick
confirm (a nod suffices).
- For queued mode: `default.option` (and optionally `default.apply_at`, epoch ms).
- `source` with `agent`, `session_tag` (your session id — given in your session
  context), and `project` (your working directory). This is what routes wakes and
  reconciliation back to you; never omit it.

The tool ALWAYS returns immediately with a `decision_id`. It never waits.

## 3. The sentinel: one wake channel for the whole session

The human may be watching this session, or away from it — serve both. The wake
mechanism is a single SENTINEL background task per session (not per decision):
your session context gives the exact command (the plugin's
`scripts/decisions-sentinel.sh` with hub URL, your session_tag, and project).

1. After filing your FIRST decision, arm the sentinel via the Bash tool with
   `run_in_background: true`. It long-polls the hub's session wake endpoint,
   silently reconnecting on timeouts and errors, and only completes when the
   human answers one of this session's decisions in the app — which wakes you.
2. For **blocking** decisions: do any work NOT blocked on the answer first, then
   END YOUR TURN by restating the question with its numbered options (and your
   recommendation) in your final message, noting they can answer here or in the
   Decisions app. This message is the in-session answer surface — make it
   self-contained. Your session now sleeps at zero cost until a channel fires.
3. Whichever channel answers first wins:
   - **App**: the sentinel completes, printing the answered decision ids. Call
     `decision_status` for each (this ACKNOWLEDGES it — stops redelivery), apply
     the answer, then RE-ARM the sentinel with the same command if any of your
     decisions are still pending — or leave it re-armed anyway; it costs nothing
     and catches late queued-mode overrides.
   - **In-session**: the human replies in chat. Immediately call
     `resolve_decision` with the decision_id and their `option_label` (or
     `free_text`) — this clears the app card and does NOT trigger a sentinel
     wake. If it returns `already_answered`, they beat you to it in the app:
     respect that standing answer, not the chat reply, and say so.
4. The sentinel's wake output includes answers you missed while disconnected
   (at-least-once delivery) — the hub redelivers any unacknowledged answer, so a
   crashed or expired wait never loses a decision.

If your harness has no background shell, call the `await_decision` MCP tool with a
long `timeout_seconds` (up to 21600) on the specific decision instead and let the
harness hold or background it. `await_decision` with `timeout_seconds: 0`, or
`decision_status`, gives an instant non-waiting check between other work.

## 4. Small autonomous decisions

For minor reversible choices you make yourself without asking, call
`log_autodecision` (question, choice, context) so the human can audit them later.
This is not optional — a working session that logs nothing has left the human
blind to every call it made. Do not route trivia to the queue — the queue is for
decisions that deserve a human; the log is for everything else.

## 5. Failure behaviour

If the decisions server is unreachable, fall back to your native behaviour
(AskUserQuestion / asking in-conversation). The hub is an enhancement layer, never a
new point of failure.
