---
name: deal-next-steps
description: Returns the next steps and upcoming meetings for one specific deal, analyzed from every call, commitment, CRM field, and calendar event linked to that deal. Use whenever someone asks what happens next in a deal, what was committed, whether a deal has a real dated next step, or what's on the calendar for it — "what's next on Acme", "do we have a follow-up booked with Meridian", "is this deal moving" — even if they never say "next steps". Always calls the get_deal_next_steps tool on the zime-mcp server when connected — never hand-builds the next-step list in its place — and handles the tool's disambiguation flow (candidate lists, pinning a deal_id).
license: MIT
metadata:
  zime:category: cross-stage
  zime:dimension: initiative
  zime:input-modes: mcp,transcript
---

# Deal Next Steps

Answers "what's next on the Acme deal?" from the deal's actual state.
Zime's deal AI agent reads the CRM record, the commitments extracted from
every call on the deal, and the deal's calendar — then separates what was
committed from what is scheduled from what it recommends. This skill
reaches that agent correctly and delivers what it returns, whole.

## Routing

- Next steps from ONE call → `call-recap`.
- Deals missing next steps across the pipeline, or any comparison between
  deals → `ask_zime`; the agent behind this tool is pinned server-side to
  one deal and will decline anything broader.
- Preparing for the upcoming meeting itself → `prep-note`.
- Any other deal-level question (health, stakeholders, strategy) →
  `ask_zime`.

## MCP mode (required when zime-mcp is connected)

When a zime-mcp server exposes `get_deal_next_steps` (fully qualified:
`Zime:get_deal_next_steps`; some clients surface it as
`mcp__claude_ai_Zime__get_deal_next_steps`), route the question through it.
Answering from chat context while the tool is available is a failure of
this skill: only the agent sees the commitments across every call plus the
live CRM and calendar state.

### Arguments

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

**Example** — "what's next on the Acme expansion?":

```json
{ "query": "Acme expansion" }
```

### Outcomes

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

## Output

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
  deliver it plainly, and suggest `prep-note` if the real goal is preparing
  to re-engage.
- Add nothing the answer doesn't support; reformat only if the user
  explicitly asked.

## Local mode (only when no zime-mcp server is connected)

If the user provides call transcripts or a CRM export for the deal, extract
next steps from those files only — each commitment with its owner, its date
if one was stated, and a quote or field citation. A step with no owner or
date is listed as such, not dressed up. Open with one line saying the list
covers only the provided files, not the full deal history.

## What this sends where

MCP mode sends only the query words, dates, and (when pinning) a deal_id to
the zime-mcp server. Local mode reads only the files the user provided.
