---
name: get-meeting
description: Looks up ONE meeting/call's metadata — title, date, attendees, linked deal. Use whenever someone wants the facts about a single named meeting or call — "when was my last call with Acme", "who was on the Northwind demo", "what deal is that call linked to" — even if they never say "meeting" or "call". Always calls the get_call tool on the zime-mcp server when connected — never hand-answers from memory or chat context in its place — and handles the tool's disambiguation flow (multiple_matches candidates, pinning a call_id). Falls back to reading metadata out of a user-provided transcript or calendar invite only when no zime-mcp server is available.
license: MIT
metadata:
  zime:category: cross-stage
  zime:dimension: initiative
  zime:input-modes: mcp,transcript
---

# Get Meeting

Answers "when was my last call with Acme, and who was on it?" with the one
call record's metadata — nothing synthesized, nothing inferred. Zime
models meetings as "calls": this skill's job is title, date, attendees, and
linked deal — for what was actually SAID, use `get-transcript` or
`call-recap` instead.

## Routing

- The full transcript of this meeting → `get-transcript`.
- A structured recap (decisions, action items, risks) of this meeting →
  `call-recap`.
- Preparing for an UPCOMING, not-yet-happened meeting → `call-prep`.
- "What meetings do I have today/this week" (a calendar listing, not one
  named meeting) → `ask_zime` or `daily-briefing`.

## MCP mode (required when zime-mcp is connected)

When a zime-mcp server exposes `get_call` (fully qualified: `Zime:get_call`;
some clients surface it as `mcp__claude_ai_Zime__get_call`), route the
lookup through it. Answering from memory or chat context while the tool is
available is a failure of this skill — the tool reads the live record, and
a remembered date/attendee list can be stale or wrong.

### Arguments

- `query` — words identifying the call: company, attendee, or topic. Put
  time hints in `start_date`/`end_date`, not in the query. Omit `query` if
  you already have `call_id`.
- `call_id` — pin an exact call (from a prior `multiple_matches` response,
  or already known from this conversation). Never invent one.
- `start_date` / `end_date` — YYYY-MM-DD, inclusive. Defaults to the last
  90 days.

**Example** — "when was my last call with Acme?":

```json
{ "query": "Acme" }
```

### Outcomes

The tool returns one of three shapes:

- `{"status": "resolved", "data": {...}}` — the call's metadata (title,
  date, attendees, linked deal, and whatever other fields it carries).
  Deliver per Output below.
- `{"status": "multiple_matches", "candidates": [...]}` — more than one
  call matched. Show the candidates, ask the user which one they mean, then
  re-call with the chosen `call_id`. Never guess among them.
- `{"status": "no_match"}` — no call matched; say so plainly rather than
  substituting a similarly-named call.
- An error — `isError: true` with `{"error": "<CODE>"}`. `INTERNAL_ERROR`
  is usually transient: retry once. `UNAUTHORIZED` or `FORBIDDEN` means the
  Zime connection needs re-authorizing or lacks access — say so.
  `INVALID_ARGUMENT` means the arguments were malformed — fix and re-call.
  If it still fails, say plainly the meeting-lookup service couldn't be
  reached and offer the local fallback. Never substitute a remembered or
  guessed record.

## Output

Relay the record's fields as returned — don't add, infer, or round
anything it doesn't state. A field the record doesn't carry (e.g. no linked
deal) is presented as absent, not filled in with a plausible guess.

## Local mode (only when no zime-mcp server is connected)

If the user provides a transcript or calendar invite, read the metadata
(title, date, attendees) out of that file only and say the answer is
limited to it, not the live record. No file and no connection → say so
rather than guessing at the meeting's date or attendees.

## What this sends where

MCP mode sends only the query words, dates, and (when pinning) a call_id
to the zime-mcp server. Local mode reads only the file the user provided.
