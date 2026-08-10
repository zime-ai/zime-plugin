---
name: call-recap
description: Produces a detailed, structured recap of one recorded sales call — overview, key decisions and commitments, risks and blockers, action items grouped by owner, and open questions, with speakers and timestamps. Use whenever someone asks what happened on a past recorded call — a recap, summary, debrief, notes, minutes, action items, or "catch me up on my call with X" — even if they never say the word "recap". Always calls the generate_call_recap tool on the zime-mcp server when connected — never hand-builds the recap in its place — and handles the tool's two-phase disambiguation (candidate lists, pinning a call_id). Falls back to recapping a user-provided transcript only when no zime-mcp server is available.
license: MIT
metadata:
  zime:category: cross-stage
  zime:dimension: initiative
  zime:input-modes: mcp,transcript
---

# Call Recap

Turns "what happened on my Northwind call?" into a complete, skimmable recap.
Zime's call AI agent produces it from the full transcript plus the call's
extracted signals (objections, commitments, action items) — data no chat
context can match. This skill's job is to reach that agent correctly and
deliver what it returns, whole.

## Routing

- Custom questions about a call ("did they mention pricing?") → `ask_zime`.
- Prep for an upcoming meeting → `prep-note`.
- Cross-call or company-wide patterns → `ask_zime`. The agent behind this
  tool is pinned server-side to one call and will decline anything broader,
  so routing wide questions here wastes the call.

## MCP mode (required when zime-mcp is connected)

When a zime-mcp server exposes `generate_call_recap` (fully qualified:
`Zime:generate_call_recap`; some clients surface it as
`mcp__claude_ai_Zime__generate_call_recap`), route the recap through it.
Hand-summarizing from memory or chat context while the tool is available is
a failure of this skill: the agent reads the verbatim transcript, and a
plausible summary that skips a commitment or misattributes an action item
is worse than no recap.

### Arguments

- `query` (required) — words identifying the call. The search matches call
  titles, deal names, and account names and needs roughly 75% of the words
  to hit, so a few distinctive words beat a sentence: "Northwind audit", not
  "the call I had with the Northwind folks about the audit".
- `start_date` / `end_date` — YYYY-MM-DD, inclusive. Convert every time
  hint here ("yesterday", "last Tuesday") and keep time words out of
  `query`. Default window: the user's own recorded calls, last 90 days.
- `call_id` — only to pin: after the tool returned a candidate list (pass
  the chosen candidate's `call_id`), or when the ID is already known from
  this conversation. Never invent one.

**Example** — "recap my call with Northwind from yesterday" (today 2026-08-10):

```json
{ "query": "Northwind", "start_date": "2026-08-09", "end_date": "2026-08-09" }
```

### Outcomes

- **A recap** — deliver it per Output below.
- **A candidate list** — JSON with `status` (`multiple_matches` or
  `no_match`), a `message`, and up to 5 `candidates` (call_id, title, date,
  account_name, deal_name), newest first. On `no_match` the candidates are
  the user's most recent recorded calls, offered as a fallback — present
  them as such, not as matches. Show title/date/account, ask which call the
  user means, then re-call with the chosen `call_id`. Exception: when the
  user asked for their "latest" or "most recent" call, take the first
  candidate and re-call without asking.
- **An error** — `{"error": "<CODE>"}`. `INTERNAL_ERROR` and `STREAM_ERROR`
  are usually transient: retry once. `UNAUTHORIZED` means the Zime
  connection needs re-authorizing — say so. `INVALID_DATE_RANGE` means the
  dates are malformed or reversed — fix and re-call. If it still fails, say
  plainly the recap service couldn't be reached and offer the local
  fallback. Never substitute a hand-written recap and present it as
  tool-backed.

## Output

The agent returns the recap already structured — overview, decisions and
commitments, risks and blockers, action items grouped by owner, questions
for the next touch — with speakers, timestamps, and clean formatting (bold
headings only). It is the finished deliverable, not raw material:

- Reproduce it in full — every section, item, timestamp, and caveat. A
  marker like "owner not clearly assigned" is a finding the agent made
  deliberately; keep it.
- Add nothing the recap doesn't support, and reformat only if the user
  explicitly asked for a different shape.
- Follow-up edits ("shorten it", "just the action items") work from the
  returned recap in conversation — no second tool call needed.

## Local mode (only when no zime-mcp server is connected)

If the user provides or pastes a transcript, build the recap from it with
the same section structure, and open with one line saying it was built from
the provided transcript only, without Zime's call insights. Every item
cites a quote or timestamp from that transcript. No transcript, no recap:
ask for one or for the Zime connection.

## What this sends where

MCP mode sends only the query words, dates, and (when pinning) a call_id to
the zime-mcp server; the transcript never leaves Zime. Local mode reads
only the file or text the user provided.
