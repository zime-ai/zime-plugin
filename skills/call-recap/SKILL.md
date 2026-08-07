---
name: call-recap
description: Produces a detailed, structured recap of one recorded sales call — overview, key decisions and commitments, risks and blockers, action items grouped by owner, and questions for the next touch. Always calls the generate_call_recap tool on the zime-mcp server when connected — never hand-builds the recap in its place — and handles the tool's disambiguation flow (candidate lists, pinning a call_id). Falls back to recapping a user-provided transcript only when no zime-mcp server is available. Use when someone asks what happened on a past recorded call.
license: MIT
metadata:
  zime:category: cross-stage
  zime:dimension: initiative
  zime:input-modes: mcp,transcript
---

# Call Recap

Turns "what happened on my Northwind call?" into a structured, skimmable
recap. The recap itself is produced by Zime's call AI agent from the full
transcript — this skill's job is to reach that agent correctly and render
what it returns.

## When to use this

- A rep or manager wants a recap of one specific recorded call.
- Someone missed a call and needs to catch up on it.
- A recap is the input to something else (CRM notes, a handoff, a summary
  for a leader).

Not for: custom questions about a call ("did they mention pricing?" →
`ask_zime`), prep for an *upcoming* meeting (→ `prep_note`), or
cross-call patterns (→ `ask_zime`).

## MCP mode (REQUIRED when zime-mcp is connected)

**Tool-first, not tool-optional.** If a zime-mcp server exposes
`generate_call_recap` (via the claude.ai connector it appears as
`mcp__claude_ai_Zime__generate_call_recap`), you MUST route the recap
through it. The agent behind it reads the full transcript and call
insights — hand-summarizing from memory or chat context while the tool is
available is a failure of this skill.

Build the arguments carefully — this tool has a two-phase contract:

1. **`query`** — words identifying the call: company, attendee, or topic
   ("Northwind audit prep"). **Never put time words in the query.** Convert
   every time hint — "yesterday", "last Tuesday", "this morning" — into
   `start_date` / `end_date` (YYYY-MM-DD, inclusive). No time hint means
   the tool searches the user's own recorded calls over the last 90 days.
2. **`call_id`** — set ONLY when pinning: after the tool returned a
   candidate list (pass the chosen candidate's `call_id`), or when the ID
   is already known from this conversation. Never invent one.

Handle each outcome:

- **A recap** — render it as returned (see Output below).
- **`multiple_matches` / `no_match` with candidates** — the candidates
  are newest-first. Show them to the user (title, date, deal/account) and
  ask which call they mean — EXCEPT when the user asked for their
  "latest" or "most recent" call: pick the first candidate and call again
  with its `call_id` without asking.
- **An error code** — retry once. If it still fails: `UNAUTHORIZED` means
  the Zime connection needs re-authorizing — say so; anything else, say
  plainly the recap service couldn't be reached. Never substitute a
  hand-written recap and present it as tool-backed.

## Local mode (fallback, ONLY when no zime-mcp server is connected)

If the user provides a transcript file or pastes one, build the recap
from it — same section structure as below — and open with one line saying
it was built from the provided transcript only, without Zime's call
insights. Every item cites a quote or timestamp from that transcript. No
transcript, no recap: ask for one or for the Zime connection.

## Output

The agent returns the recap already structured in this order — preserve
it, don't re-summarize it away:

1. Overview (5–6 sentences)
2. Key decisions / commitments (who said it + timestamp)
3. Risks & blockers (who raised it + severity + timestamp)
4. Action items (grouped under a bold owner sub-header, due date if
   mentioned + timestamp)
5. Questions to clarify on the next touch (3–5 bullets)

The tool's answer is the source of truth — do not add claims it doesn't
support and do not drop decisions, risks, or action items it returned.
Bold stays on headings and owner names only.

## What this sends where

MCP mode sends only the query words, dates, and (when pinning) a call_id
to the zime-mcp server; the transcript never leaves Zime. Local mode
reads only the file or text the user provided.
