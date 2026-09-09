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
  default. The tool returns the default immediately (`answered_by: "default"`);
  proceed with it. Then ALSO arm the background await from section 3 step 2 on the
  decision_id (`run_in_background: true`) — the human may ratify your default or
  OVERRIDE it, and the wake is how you find out. If the delivered answer differs
  from the default you proceeded on, adapt your work to the human's choice at the
  next sensible point and say you did. At each stage boundary, if any queued
  decision is still unanswered, carry on — the default stands until told otherwise.
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
- `mode`, `reversibility`, `urgency` (`now` / `soon` / `whenever`).
- For queued mode: `default.option` (and optionally `default.apply_at`, epoch ms).

The tool ALWAYS returns immediately with a `decision_id`. It never waits.

## 3. Blocking mode: the dual-channel sleep/wake wait

The human may be watching this session, or away from it — serve both. After
`request_decision`:

1. Do any work NOT blocked on the answer first.
2. When only the answer remains, run this with the Bash tool and
   `run_in_background: true` (substitute the real decision_id; hub base URL is
   `$DECISIONS_HUB_URL` minus the `/mcp` suffix, default `http://127.0.0.1:5808`):

   ```bash
   curl -s --max-time 3700 "http://127.0.0.1:5808/api/decisions/<decision_id>/await?timeout_seconds=3600"
   ```

3. End your turn by RESTATING the question with its numbered options (and your
   recommendation) in your final message, noting they can answer here or in the
   Decisions app. This message is the in-session answer surface — make it
   self-contained.
4. Whichever channel answers first wins:
   - **App**: the background task completes and wakes you with
     `{"state": "answered", "answer": {..., "answered_via": "app"}}`. Proceed.
   - **In-session**: the human replies in chat. Immediately call
     `resolve_decision` with the decision_id and their `option_label` (or
     `free_text` for an answer outside the options) — this clears the pending
     card from the app so the queue never holds stale decisions. If it returns
     `already_answered`, they beat you to it in the app: respect that standing
     answer, not the chat reply, and say so.
   If the background curl returns `state: "pending"` (1h elapsed), re-arm it.

If your harness has no background shell, call the `await_decision` MCP tool with a
long `timeout_seconds` (up to 21600) instead and let the harness hold or background
it. `await_decision` with `timeout_seconds: 0`, or `decision_status`, gives an
instant non-waiting check between other work.

## 4. Small autonomous decisions

For minor reversible choices you make yourself without asking, call
`log_autodecision` (question, choice, context) so the human can audit them later.
Do not route trivia to the queue — the queue is for decisions that deserve a human.

## 5. Failure behaviour

If the decisions server is unreachable, fall back to your native behaviour
(AskUserQuestion / asking in-conversation). The hub is an enhancement layer, never a
new point of failure.
