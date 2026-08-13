---
name: competitive-intelligence
description: Answers cross-deal and cross-call questions about how the team is doing against a named competitor — mention frequency, win/loss framing, how reps are positioning, and what prospects have actually said. Use whenever someone asks about a specific competitor across calls or deals — "how are we doing against Borealis Systems", "why do we keep losing to Borealis Systems" — even if they never say "competitive intelligence". Always calls ask_zime for this cross-deal/cross-call analysis on zime-mcp when connected — never routes it to get_deal_objections, which is pinned to one deal and declines broader questions — then optionally drills into get_transcript (via get-meeting first if the call isn't identified) once one call is pinned, for the exact quoted wording. Falls back to searching only user-provided transcripts for mentions, stating plainly that no win/loss claim is possible from a handful of files, when no zime-mcp server is connected.
license: MIT
metadata:
  zime:category: cross-stage
  zime:dimension: initiative
  zime:input-modes: mcp,transcript
---

# Competitive Intelligence

Answers "how are we doing against Borealis Systems?" and "why do we keep
losing to Borealis Systems?" with the picture across *many* calls and deals
at once — mention frequency, how prospects frame the competitor, how reps
are positioning against it, and where deals were won or lost with it in
play. That analysis happens server-side, inside Zime's general-purpose
agent, over the call-derived signals it already extracts (competitor
mentions are explicitly one of them) and the coaching layer built for
exactly this ("why am I losing to this competitor", "what's working in won
deals"). This skill's job is to reach that agent with the competitor named
explicitly and relay what it returns, whole — then, only if the user wants
the exact words rather than a synthesis, drill into one identified call's
transcript.

## Routing

- A single deal's objections that happen to be competitive in nature, where
  the user wants deal-scoped objection handling (not cross-deal patterns) →
  `deal-strategy` (or `ask_zime` scoped explicitly to that one deal).
- A single call's full structured recap (not just the competitor angle) →
  `call-recap`.
- Broader win-rate or pipeline health with no named competitor → the
  question isn't competitive intelligence — route to `pipeline-review`.
- The exact quoted wording from one already-identified call → stay in this
  skill's `get_transcript` drill-down below; don't re-ask `ask_zime` for
  something it can only summarize, not quote verbatim.

## MCP mode (required when zime-mcp is connected)

### Primary: `ask_zime`

When a zime-mcp server exposes `ask_zime` (fully qualified: `Zime:ask_zime`;
some clients surface it as `mcp__claude_ai_Zime__ask_zime`), route any
cross-call or cross-deal competitor question through it. This is the
mandatory primary tool here — there is no `search_transcripts`,
`find_calls_mentioning`, or any other plural/search tool on zime-mcp, and
`ask_zime`'s own description explicitly lists "competitor mentions" under
call-derived signals and "why am I losing to this competitor" / "what's
working in won deals" under coaching and strategy. It is the only tool that
can search or aggregate across calls and deals for a competitor.

**Do not** route a competitor question to `get_deal_objections` just
because a competitor mention might be filed as an objection. That tool is
agent-backed but pinned server-side to exactly one deal and will decline
anything broader — "how are we doing against Borealis Systems across the
pipeline" is not a one-deal question, and sending it there is a routing
failure, not a valid alternative path.

#### Arguments

- `question` (required) — the user's own words, sent close to verbatim,
  with the competitor named explicitly. Never send a vague "that
  competitor" or "them" — if the competitor's name came from earlier in the
  conversation, resolve it into the actual name before calling; `ask_zime`
  has no memory of earlier turns. Preserve scope exactly as given: "my
  deals" stays "my deals", don't broaden it to the whole team's pipeline
  unless asked.

**Example** — "why do we keep losing to Borealis Systems?":

```json
{ "question": "why do we keep losing to Borealis Systems?" }
```

**Example** — "has Borealis Systems come up on any of my calls with Acme
this quarter?":

```json
{ "question": "has Borealis Systems come up on any of my calls with Acme this quarter?" }
```

##### Outcomes

`ask_zime` returns its answer as text, already scoped and access-controlled
server-side — deliver it per Output below. If it declines (out of scope, no
access, no data for the window asked), say so plainly rather than filling
the gap with a guessed mention count or a remembered impression of the
competitor.

### Drill-down: `get_transcript`

Once `ask_zime` (or the user) has narrowed things to one specific call
where the exact quoted wording about the competitor is wanted — not a
synthesized summary — pull that call's verbatim transcript. If the specific
call isn't already identified (only a company or rough timeframe is
known), resolve it first via `get-meeting` (`get_call`); don't guess a
`call_id`.

When zime-mcp exposes `get_transcript` (fully qualified:
`Zime:get_transcript`; some clients surface it as
`mcp__claude_ai_Zime__get_transcript`), call it with:

- `query` — company, attendee, or topic words identifying the call. Omit if
  `call_id` is already known.
- `call_id` — pin an exact call, from a prior `multiple_matches` response
  or already known in this conversation. Never invent one.
- `start_date` / `end_date` — YYYY-MM-DD, inclusive. Defaults to the last
  90 days.

**Example** — after `ask_zime` points to the Acme call where Borealis
Systems came up, pulling the exact wording:

```json
{ "query": "Acme", "start_date": "2026-07-01", "end_date": "2026-08-13" }
```

It returns `{"status": "resolved"|"multiple_matches"|"no_match", "data"?,
"candidates"?}`, or an error (`UNAUTHORIZED`/`FORBIDDEN`/
`INVALID_ARGUMENT`/`INTERNAL_ERROR`) — handle exactly as `get-transcript`
documents: show candidates on `multiple_matches` and ask which call, say so
plainly on `no_match`, retry once on `INTERNAL_ERROR`, never substitute a
remembered or invented quote.

## Output

Relay `ask_zime`'s full answer without truncation — every deal it names,
every framing pattern, every caveat, in the order given. This mirrors
`ask_zime`'s own guidance for using its result: the agent already decided
what matters and in what order, and condensing "mentioned in six deals,
lost three" down to "comes up sometimes" throws away the distinction a rep
or manager acts on.

- Don't drop caveats (e.g. "based on calls in the last 90 days") to make
  the answer shorter.
- Add nothing the answer doesn't state — no mention count, no win/loss
  number, no positioning tip the agent didn't give.
- When a `get_transcript` drill-down pulls an exact quote, present it as a
  direct quote attributed to its call and date — never blend it into the
  `ask_zime` synthesis as if the agent itself said those words. The two are
  different kinds of evidence and the user needs to know which is which.

## Local mode (only when no zime-mcp server is connected)

If the user provides call transcripts, search only those files for mentions
of the named competitor and quote them directly. State explicitly that this
covers only the provided files: no mention-frequency claim, no win/loss
pattern, and no positioning trend across the wider pipeline is possible from
a handful of transcripts — that analysis is what `ask_zime` does over the
full call history, and a local search can't reproduce it. No files and no
connection → say so rather than guessing at how the competitor is trending.

## What this sends where

MCP mode sends only the question text to `ask_zime`, and (for a drill-down)
only the query words, dates, and a `call_id` when pinning to
`get_transcript` — nothing else. Local mode reads only the files the user
provided.
