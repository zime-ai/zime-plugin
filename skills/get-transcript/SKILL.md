---
name: get-transcript
description: Gets the FULL verbatim transcript for ONE call/meeting. Use whenever someone wants the actual words said on a specific call — "what exactly did they say about pricing on the Acme call", "pull the transcript from my Northwind demo", "did they use the word 'competitor' on that call" — even if they never say "transcript". Always calls the get_transcript tool on the zime-mcp server when connected — never hand-answers from memory or chat context in its place — and handles the tool's disambiguation flow (multiple_matches candidates, pinning a call_id). Has no local fallback of its own: the transcript only exists inside Zime, so without a connection the skill says so rather than inventing one.
license: MIT
metadata:
  zime:category: cross-stage
  zime:dimension: initiative
  zime:input-modes: mcp
---

# Get Transcript

Answers "what exactly did they say about pricing on the Acme call?" with
the actual verbatim transcript — not a summary, not a recap, the raw
speaker-by-speaker record. Use this only when the user needs the words
themselves; anything that wants synthesis or structure belongs to a
sibling skill.

## Routing

- A structured recap (decisions, action items, risks), not the raw text →
  `call-recap`.
- Just the call's metadata (title, date, attendees) → `get-meeting`.
- A specific question answerable from the call's extracted signals
  (objections, competitor mentions) rather than the raw text → `ask_zime`.
- Cross-call search ("find calls where pricing came up") → `ask_zime`;
  this tool returns one call's transcript, not a search across many.

## MCP mode (required when zime-mcp is connected)

When a zime-mcp server exposes `get_transcript` (fully qualified:
`Zime:get_transcript`; some clients surface it as
`mcp__claude_ai_Zime__get_transcript`), route the request through it.
Answering from memory or chat context while the tool is available is a
failure of this skill — only the tool has the verbatim record, and a
remembered paraphrase is not a transcript.

### Arguments

- `query` — words identifying the call: company, attendee, or topic. Put
  time hints in `start_date`/`end_date`, not in the query. Omit `query` if
  you already have `call_id` (e.g. from a prior `get-meeting` result).
- `call_id` — pin an exact call (from a prior `multiple_matches` response,
  or already known from this conversation). Never invent one.
- `start_date` / `end_date` — YYYY-MM-DD, inclusive. Defaults to the last
  90 days.

**Example** — "pull the transcript from my Acme call":

```json
{ "query": "Acme" }
```

### Outcomes

The tool returns one of three shapes:

- `{"status": "resolved", "data": {...}}` — the full transcript. Deliver
  per Output below.
- `{"status": "multiple_matches", "candidates": [...]}` — more than one
  call matched. Show the candidates, ask the user which one they mean, then
  re-call with the chosen `call_id`. Never guess among them.
- `{"status": "no_match"}` — no call matched; say so plainly rather than
  substituting a similarly-named call.
- An error — `isError: true` with `{"error": "<CODE>"}`. `INTERNAL_ERROR`
  is usually transient: retry once. `UNAUTHORIZED` or `FORBIDDEN` means the
  Zime connection needs re-authorizing or lacks access — say so.
  `INVALID_ARGUMENT` means the arguments were malformed — fix and re-call.
  If it still fails, say plainly the transcript service couldn't be
  reached. Never substitute a remembered or invented quote for a real one.

## Output

Relay the transcript content as returned — every quote attributed to the
speaker and timestamp the tool gives it. If the user asked a narrower
question ("what did they say about pricing"), answer from the returned
transcript only, quoting directly rather than paraphrasing from memory;
don't drop the rest of the transcript from context if a follow-up needs it.

## Local mode

There is no local fallback: the transcript lives only inside Zime, and
this skill will not fabricate one from a title or a remembered
conversation. Without a zime-mcp connection, say so plainly. If the user
separately pastes or uploads a transcript file themselves, that's not this
skill's territory — read it directly in conversation, or use `call-recap`'s
local mode if a structured recap is what's wanted.

## What this sends where

MCP mode sends only the query words, dates, and (when pinning) a call_id
to the zime-mcp server.
