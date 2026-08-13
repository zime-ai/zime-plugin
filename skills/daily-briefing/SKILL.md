---
name: daily-briefing
description: Assembles a morning briefing of what's on the rep's plate today — today's meetings, deals needing attention, and open action items or follow-ups due — by orchestrating one or more ask_zime calls and presenting the results grouped by section, not fully resolving every flagged item itself. Use whenever someone wants a rundown of their day or open plate — "what's on my plate today", "give me my morning briefing", "what do I need to look at before I start my day" — even if they never say "briefing" or "daily". Always calls the ask_zime tool on the zime-mcp server when connected, scoped to the facets asked for — never hand-builds the briefing from memory, and never invents a calendar-listing tool (zime-mcp has no get_todays_meetings or list_meetings; get_call resolves only one call, not a calendar, so even "what meetings do I have today" goes through ask_zime). Has no local fallback: without a connection there is no calendar or action-item data to read locally, so it says that plainly.
license: MIT
metadata:
  zime:category: cross-stage
  zime:dimension: initiative
  zime:input-modes: mcp
---

# Daily Briefing

Answers "what's on my plate today?" by pulling together three things a rep
starts the day needing: today's meetings, deals that need attention this
week, and action items or follow-ups that are due. No single zime-mcp tool
produces that combined view — this skill's job is to ask `ask_zime` for
each facet the user actually wants, then lay the answers out grouped and
skimmable. It is an orchestrator over `ask_zime`, not a wrapper over a
dedicated briefing tool, because none exists.

## Routing

- A bare "what meetings do I have today/this week", with nothing else
  asked for → `ask_zime` directly; no need to run the full three-section
  briefing for a single-facet question.
- A bare "what are my open action items", with nothing else asked for →
  `ask_zime` directly, same reasoning.
- A bare "which deals need attention" / pipeline-risk question, with
  nothing else asked for → `ask_zime` directly (or a pipeline-level skill
  if one is available).
- Once the briefing surfaces ONE upcoming meeting the user wants to get
  ready for → `call-prep`.
- Once the briefing flags ONE deal the user wants to dig into → `get-deal`
  for the record, `actions-commitments` for its committed/scheduled next
  steps, or `deal-strategy` for its objections or coaching — whichever
  matches what they actually asked next.
- Once the briefing surfaces ONE call that needs a recap or a follow-up
  email → `call-recap` or `follow-up`.
- This skill's own job stops at presenting the raw briefing content,
  grouped; it does not silently chain into five other tool calls trying to
  fully resolve every flagged item on the user's behalf — that chaining
  only happens on the user's explicit follow-up, via the hand-offs above.

## MCP mode (required when zime-mcp is connected)

When a zime-mcp server exposes `ask_zime` (fully qualified: `Zime:ask_zime`;
some clients surface it as `mcp__claude_ai_Zime__ask_zime`), route every
facet of the briefing through it. There is no calendar-listing tool and no
plural "get my meetings/deals/action-items" tool on zime-mcp — `ask_zime`
is not a fallback here, it is the only correct way to answer "what's on my
plate today", and hand-building any part of the briefing from memory while
it's available is a failure of this skill.

### Arguments

`ask_zime` takes one argument:

- `question` (required) — send it close to the user's own wording, keeping
  first-person phrasing like "my" intact; the tool identifies the asker and
  enforces access control server-side, so it needs "my meetings", not "the
  user's meetings". It has no memory of earlier turns, so each call must be
  fully self-contained.

Cover the three facets — meetings today, deals needing attention, action
items due — with either of two acceptable shapes, matching what the user
actually asked for:

1. **Separate, focused calls**, one per facet the user wants, when the
   request is broad ("what's on my plate today") or when a facet needs its
   own time window. Preferred when the facets don't share a single natural
   phrasing, so each question stays scoped to what it needs rather than
   over-fetching.
2. **One combined question**, when the user's own phrasing already spans
   the facets naturally ("give me my morning briefing — meetings, action
   items, and anything urgent on my deals").

Either way, ask for exactly the facets requested — don't add a fourth
question the user didn't ask for, and don't collapse three distinct asks
into one vague question that makes the agent guess what "everything" means.

**Example** — "what's on my plate today?", using three focused calls:

```json
{ "question": "what meetings do I have today" }
```

```json
{ "question": "what are my open action items" }
```

```json
{ "question": "which of my deals need attention this week" }
```

**Example** — a narrower ask ("just tell me what meetings I have with
Meridian Health today and anything overdue on Northwind Logistics"), using
one combined call because the user's own phrasing already spans both:

```json
{ "question": "what meetings do I have with Meridian Health today, and what's overdue on Northwind Logistics" }
```

### Outcomes

- **An answer** — plain text, already scoped and access-controlled
  server-side. Deliver it per Output below.
- **A decline** (out of scope, no access, no data for that facet) — say so
  plainly for that section rather than filling the gap from another call's
  answer or from memory.
- **An error** — `isError: true` with `{"error": "<CODE>"}`.
  `INTERNAL_ERROR` is usually transient: retry that one call once.
  `UNAUTHORIZED` means the Zime connection needs re-authorizing — say so
  for the whole briefing, since every facet depends on the same
  connection. If a call keeps failing, say plainly that section of the
  briefing couldn't be reached and still deliver the sections that
  succeeded — a partial briefing beats withholding all of it over one
  failed facet.

## Output

Present the briefing grouped by facet, skimmable in under a minute, each
section attributable to the `ask_zime` call that produced it:

- **Meetings today** — from the meetings call.
- **Deals needing attention** — from the deals call.
- **Action items due** — from the action-items call.

For each section, relay the answer's content in full — don't condense,
re-rank, or drop distinctions the agent drew (e.g. between a hard deadline
and a recommended follow-up). Add nothing a call's answer doesn't support.

A section with nothing to show is a real, deliverable finding, not an
error: "No open action items surfaced" or "No deals flagged for attention
this week" is exactly what a clear day looks like — state it plainly
instead of omitting the section or padding it with a plausible guess. If
one facet's call failed while the others succeeded, say that section
couldn't be reached and still show the rest.

## Local mode

There is no local fallback. A day's calendar, a workspace's live deal
state, and outstanding action items exist only inside Zime — there is no
file a user could hand this skill (no calendar export, no transcript) that
would substitute for actually asking the workspace what's on the plate
today. Without a zime-mcp connection, say so plainly rather than
fabricating a schedule, a deal list, or an action-item list from
conversation history.

## What this sends where

MCP mode sends only the question text — one call per facet, or one
combined question — to the zime-mcp server; nothing else leaves the
conversation. Local mode does not exist, so nothing is read from disk.
