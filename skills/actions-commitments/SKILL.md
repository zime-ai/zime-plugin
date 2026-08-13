---
name: actions-commitments
description: Handles two related jobs — next steps for ONE specific deal (what was promised, what's scheduled, what the agent recommends, kept separate), and personal or cross-deal action items with no single deal named. Use for what happens next in a deal or what was committed — "what's next on Acme", "do we have a follow-up booked with Swisscom" — or outstanding work spanning calls and deals — "what are my action items", "what did we commit to across my deals" — even if they never say "next steps". Always calls get_deal_next_steps for the single-deal half and ask_zime for the personal/cross-deal half on zime-mcp when connected — never hand-builds either list — and handles get_deal_next_steps's disambiguation (candidate lists, pinning a deal_id). Falls back to extracting next steps from a transcript/CRM export for the single-deal half only; no local equivalent exists for the cross-deal half.
license: MIT
metadata:
  zime:category: cross-stage
  zime:dimension: initiative
  zime:input-modes: mcp,transcript
---

# Actions & Commitments

Two related jobs, one skill:

1. **One deal's next steps** — "what's next on Acme?" Zime's deal AI agent
   reads the CRM record, the commitments extracted from every call on the
   deal, and the deal's calendar, then separates what was committed from
   what is scheduled from what it recommends.
2. **Personal or cross-deal action items** — "what are my action items this
   week?" Zime's general-purpose agent reads across calls, deals, and the
   asking rep's own activity — no single deal is named or implied.

## Decision rule

This is the routing logic for the whole skill, and it comes before
anything else:

- The ask names **one specific deal** ("on Acme", "the Swisscom renewal") →
  call `get_deal_next_steps`.
- The ask is **personal, cross-deal, or names no single deal** ("my action
  items", "across my deals", "from last week's calls", "what's
  outstanding") → call `ask_zime` instead.

`get_deal_next_steps`'s own agent is pinned server-side to one deal and
will decline anything broader — sending a cross-deal ask to it wastes a
turn and returns a refusal, not an answer. Conversely, sending a
single-deal ask to `ask_zime` works but skips the deal agent's dedicated
committed/scheduled/recommended breakdown, so route single-deal asks to
`get_deal_next_steps` first.

## Routing

- Objections or coaching/strategy for this one deal → `deal-strategy`.
- Plain CRM facts only (stage, amount, owner, close date) for this one deal,
  no next-step analysis → `get-deal`.
- Preparing for the upcoming meeting itself (what to say, what to watch
  for), not tracking what was already committed → `call-prep`.
- "What's on my plate today" or a broader daily briefing across meetings,
  deals, and tasks → `daily-briefing`.
- Next steps from one specific call rather than a whole deal → `call-recap`.

## MCP mode (required when zime-mcp is connected)

Route through whichever tool the decision rule above selects. Answering
from chat context while the tool is available is a failure of this skill:
only the agent sees the commitments across every call plus the live CRM,
calendar, and activity state.

### Single-deal half: `get_deal_next_steps`

Fully qualified: `Zime:get_deal_next_steps`; some clients surface it as
`mcp__claude_ai_Zime__get_deal_next_steps`.

**Arguments**

- `query` (required) — words identifying the deal: deal, company, or
  account name. The search matches deal and account names and needs roughly
  75% of the words to hit, so a few distinctive words beat a sentence:
  "Acme expansion", not "that expansion deal we have going with Acme".
- `start_date` / `end_date` — YYYY-MM-DD, inclusive. Convert time hints
  here and keep time words out of `query`. The window scopes which deals
  are searched by recent call activity (default last 90 days) — it does not
  filter the answer's content.
- `deal_id` — only to pin: after the tool returned a candidate list (pass
  the chosen candidate's `deal_id`), or when the ID is already known from
  this conversation. Never invent one.

**Example** — "do we have a follow-up booked with Northwind?":

```json
{ "query": "Northwind" }
```

**Outcomes**

- **An answer** — deliver it per Output below.
- **A candidate list** — JSON with `status` (`multiple_matches` or
  `no_match`), a `message`, and up to 5 `candidates` (deal_id, deal_name,
  account_name, stage, last_call_date), one per deal, ordered by most
  recent call activity. On `no_match` the candidates are the deals with the
  user's most recent call activity, offered as a fallback — present them as
  such. Show name/account/stage/last-call date, ask which deal the user
  means, then re-call with the chosen `deal_id`.
- **An error** — `{"error": "<CODE>"}`. `INTERNAL_ERROR` and `STREAM_ERROR`
  are usually transient: retry once. `UNAUTHORIZED` means the Zime
  connection needs re-authorizing — say so. `INVALID_DATE_RANGE` means the
  dates are malformed or reversed — fix and re-call. If it still fails, say
  plainly the deal-analysis service couldn't be reached. Never substitute a
  from-memory next-step list.

### Personal/cross-deal half: `ask_zime`

Fully qualified: `Zime:ask_zime`; some clients surface it as
`mcp__claude_ai_Zime__ask_zime`. Its own description lists "Action items &
next steps — across calls, deals, or a person's own activity" explicitly
in scope, and enforces access control server-side.

**Argument**

- `question` (required) — send it close to verbatim, preserving first-person
  phrasing like "my" (ask_zime knows who is asking). It has no memory of
  earlier turns, so resolve pronouns and references ("that deal", "those
  calls") into the actual entity before calling.

**Example** — "what are my action items from this week?":

```json
{ "question": "What are my action items from this week?" }
```

**Example** — "what did we commit to across the Meridian and Halcyon deals?":

```json
{ "question": "What did we commit to across the Meridian and Halcyon deals?" }
```

## Output

### Single-deal half

The agent leads with a quick bottom line, then separates three things that
must stay separate — **committed next steps** (promised in calls, with
owner and date when stated), **scheduled meetings** (actually on the
calendar), and **recommended next actions** (the agent's suggestion,
labeled as such):

- Reproduce the answer in full and keep those groupings intact — collapsing
  a recommendation into a commitment misleads the rep.
- Keep who-committed-it and when-it's-due attached to each step; a marker
  like "owner not clearly assigned" or "timeline not specified" is a
  deliberate finding, not a gap to paper over.
- "No dated next step on record" is exactly the answer a manager needs —
  deliver it plainly, and suggest `call-prep` if the real goal is preparing
  to re-engage.
- Add nothing the answer doesn't support; reformat only if the user
  explicitly asked.

### Personal/cross-deal half

Relay `ask_zime`'s full answer without truncation, per its own guidance on
using the result — it already scoped and organized the action items across
whatever calls, deals, or activity the question spanned; summarizing it
down risks dropping an item the rep is actually on the hook for. Add
nothing the answer doesn't support; reformat only if the user explicitly
asked.

## Local mode (only when no zime-mcp server is connected)

**Single-deal half** — if the user provides call transcripts or a CRM
export for the deal, extract next steps from those files only: each
commitment with its owner, its date if one was stated, and a quote or
field citation. A step with no owner or date is listed as such, not dressed
up. Open with one line saying the list covers only the provided files, not
the full deal history.

**Personal/cross-deal half** — there is no local equivalent. This half
depends on Zime's cross-call, cross-deal access-controlled index of a
person's own activity, which no set of files a user could paste in
reproduces faithfully. Say so plainly rather than assembling a partial
answer from whatever transcripts happen to be at hand.

## What this sends where

MCP mode sends only the query words, dates, and (when pinning) a deal_id
to `get_deal_next_steps`, or the question text to `ask_zime` — nothing
else. Local mode reads only the files the user provided, and only for the
single-deal half.
