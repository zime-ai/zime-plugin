---
name: pipeline-review
description: Reviews pipeline health across MANY deals at once — deals at risk, stalled deals, deals with no dated next step, forecast commentary, and deal-to-deal comparisons. Use whenever a rep or manager asks about their pipeline as a whole — "what's at risk in my pipeline", "what's stuck this quarter", "how's my forecast looking", "which deals have no next step" — even if they never say "pipeline" or "aggregate". Always calls the ask_zime tool on the zime-mcp server for the aggregate question itself — never builds a pipeline view by calling get_deal in a loop over guessed deal names, which wastes calls, bypasses the tool's own server-side access control, and produces an incomplete, self-assembled view where a single properly-scoped ask_zime call already does the aggregation correctly. Falls back to building a narrower review from a user-provided multi-deal CRM export only when no zime-mcp server is available, and says so explicitly.
license: MIT
metadata:
  zime:category: cross-stage
  zime:dimension: initiative
  zime:input-modes: mcp,csv
---

# Pipeline Review

Answers "what's at risk in my pipeline" and "what's stuck this quarter" with
a view across *many* deals at once — not one deal pinned and inspected, but
the aggregate picture: which deals are stalled, which have no dated next
step, how the forecast is trending, how deals compare to each other. That
aggregation happens server-side, inside Zime's general-purpose agent, with
its own access control over which deals a given user can see. This skill's
only job is to reach that agent with the question intact and relay what it
returns, whole.

## Routing

- A SINGLE named deal's stage/amount/owner/close date → `get-deal`. This
  skill is for many deals at once; a lookup on one deal belongs there.
- A SINGLE deal's objections, pushback, or "how do I win this" coaching →
  `deal-strategy` (or `ask_zime` directly, scoped to that one deal).
- A SINGLE deal's commitments / next steps → `actions-commitments`.
- "What's on my plate today" (calls, tasks, and deals due today, not a
  pipeline-wide health review) → `daily-briefing`.
- The pipeline review flags one deal by name (e.g. "Acme expansion has had
  no next step in 60 days") and the user wants to drill into just that deal
  → `get_deal` for the record, or route to `get-deal` / `deal-strategy` /
  `actions-commitments` for that one deal specifically. Don't re-run the
  whole pipeline review to answer a single-deal follow-up.

## MCP mode (required when zime-mcp is connected)

When a zime-mcp server exposes `ask_zime` (fully qualified: `Zime:ask_zime`;
some clients surface it as `mcp__claude_ai_Zime__ask_zime`), route the
aggregate question through it. This is the mandatory primary tool for this
skill — there is no `list_deals`, `get_pipeline`, or any other plural/
aggregation tool on zime-mcp, and `ask_zime` is explicitly the tool built to
answer pipeline-wide and multi-deal questions with correct, server-side
access control.

**Never** try to assemble a pipeline view by calling `get_deal` once per
guessed deal name to stitch together an aggregate answer yourself. That
approach:

- wastes calls guessing at deal names the user never gave you,
- can't apply access control the way the server-side agent does,
- and produces an incomplete, self-assembled view — a stitched-together
  handful of individually-fetched records is not the same analysis as one
  call that reasons over the whole pipeline at once.

If `ask_zime` is available, use it for the aggregate question. Full stop.

### Arguments

- `question` (required) — the user's own words, sent close to verbatim.
  Preserve scope exactly as given: "my pipeline" stays "my pipeline" (don't
  broaden it to "the team's pipeline" or narrow it to "my deals this
  quarter" unless the user said quarter). Resolve pronouns and vague
  references into the actual entity before calling — `ask_zime` has no
  memory of earlier turns, so "how's it looking" needs to become "how's my
  pipeline looking" (or whatever it actually refers to) before you send it.

**Example** — "what's stuck in my pipeline this quarter?":

```json
{ "question": "what's stuck in my pipeline this quarter?" }
```

**Example** — "which of my deals have no next step booked?":

```json
{ "question": "which of my deals have no next step booked?" }
```

### Outcomes

`ask_zime` returns its answer as text, already scoped and access-controlled
server-side — deliver it per Output below. If it declines (out of scope, no
access, no data for the requested window), say so plainly rather than
filling the gap with a guessed list of deals or a remembered pipeline state.

### Drilling into one flagged deal

Once the review (or the user) names a specific deal to dig into, that's a
single-deal question — use `get_deal` (fully qualified `Zime:get_deal`),
not another `ask_zime` pipeline call. `get_deal`'s own arguments:

- `query` — deal or account name, e.g. "Acme expansion".
- `deal_id` — pin an exact deal, only from a prior `multiple_matches`
  response or when already known. Never invent one.
- `account_name` — narrow by account when the deal name alone is ambiguous.
- `start_date` / `end_date` — YYYY-MM-DD, inclusive.

**Example** — after `ask_zime` flags "Acme expansion" as stalled, and the
user asks "what stage is that in":

```json
{ "query": "Acme expansion" }
```

It returns `{"status": "resolved"|"multiple_matches"|"no_match", "data"?,
"candidates"?}`, or an error (`UNAUTHORIZED`/`FORBIDDEN`/
`INVALID_ARGUMENT`/`INTERNAL_ERROR`) — handle exactly as `get-deal`
documents (show candidates on `multiple_matches`, say so plainly on
`no_match`, retry once on `INTERNAL_ERROR`). Don't re-derive the same facts
from the pipeline-review answer instead of calling it — the review's
mention of a deal is a pointer, not a substitute for the live record.

## Output

Relay `ask_zime`'s full aggregate answer without truncation — every
section, every deal-to-deal comparison, every caveat it stated, in the order
it gave them. This mirrors every other agent-backed skill in this plugin:
the agent already did the analysis and already decided what matters and in
what order; condensing or truncating it here throws away distinctions
(which deals are at risk versus merely slow, which caveats qualify the
forecast) that the rep or manager acts on differently.

- Don't summarize a multi-deal breakdown down to "a few deals look risky"
  when the answer named them individually with reasons.
- Don't drop caveats ("forecast excludes deals with no close date set") to
  make the answer shorter.
- Add nothing the answer doesn't state — no additional deal, no severity
  label, no recommendation the agent didn't give.
- A drill-down `get_deal` result gets its own short answer per `get-deal`'s
  Output contract (relay the record's fields as returned) — don't fold it
  back into a re-run of the pipeline summary.

## Local mode (only when no zime-mcp server is connected)

If the user provides a CRM export covering multiple deals, build a
narrower review from that file only — deals at risk, stalled deals, missing
next steps, judged only from the fields and dates the export actually
contains. Open with one line saying the review covers only the deals and
fields in the provided file, not the live, access-controlled pipeline view
`ask_zime` would produce. No file and no connection → say so rather than
guessing at which deals are at risk or stalled.

## What this sends where

MCP mode sends only the question text to `ask_zime`, and (for a drill-down)
only the query words, dates, account name, and a `deal_id` when pinning to
`get_deal` — nothing else. Local mode reads only the file the user
provided.
