---
name: deal-next-steps
description: Returns the next steps and upcoming meetings for one specific deal, analyzed from the deal's calls, commitments, and CRM state. Always calls the get_deal_next_steps tool on the zime-mcp server when connected — never hand-builds the next-step list in its place — and handles the tool's disambiguation flow (candidate lists, pinning a deal_id). Use when someone asks what happens next in a deal, what was committed, or what's on the calendar for it.
license: MIT
metadata:
  zime:category: cross-stage
  zime:dimension: initiative
  zime:input-modes: mcp,transcript
---

# Deal Next Steps

Answers "what's next on the Acme deal?" from the deal's actual
commitments — calls, promised actions, and scheduled meetings — via
Zime's deal AI agent. This skill reaches that agent correctly and renders
what it returns.

## When to use this

- A rep resuming a deal after time away and needing the committed path
  forward.
- A manager checking whether a deal has a real, dated next step or is
  drifting.
- Before a pipeline review, pulling the forward motion on a specific
  deal.

Not for: next steps from ONE call (→ `generate_call_recap`), deals
missing next steps across the pipeline (→ `ask_zime`), prep for the
upcoming meeting itself (→ `prep_note`), or any other deal-level
question (→ `ask_zime`).

## MCP mode (REQUIRED when zime-mcp is connected)

**Tool-first, not tool-optional.** If a zime-mcp server exposes
`get_deal_next_steps` (via the claude.ai connector:
`mcp__claude_ai_Zime__get_deal_next_steps`), you MUST route the question
through it. The deal agent sees commitments across every call plus CRM
and calendar state — answering from chat context while the tool is
available is a failure of this skill.

Arguments — two-phase contract:

1. **`query`** — words identifying the deal: deal, company, or account
   name. **No time words in the query** — convert time hints to
   `start_date` / `end_date` (YYYY-MM-DD). The window scopes which deals
   are searched by recent call activity (default last 90 days).
2. **`deal_id`** — only to pin: after the tool returned a candidate list
   (pass the chosen candidate's `deal_id`), or when the ID is already
   known from this conversation. Never invent one.

Handle each outcome:

- **An answer** — render it (see Output below).
- **Candidates (`multiple_matches` / `no_match`)** — deals ordered by
  most recent call activity. Show name, account, stage, and last-call
  date; ask which deal the user means, then re-call with the chosen
  `deal_id`.
- **An error code** — retry once; then say plainly the deal-analysis
  service couldn't be reached (`UNAUTHORIZED` → the Zime connection needs
  re-authorizing). Never substitute a from-memory next-step list.

## Local mode (fallback, ONLY when no zime-mcp server is connected)

If the user provides call transcripts or a CRM export for the deal,
extract next steps from those files only — each commitment with who owns
it, the date if one was stated, and a quote or field citation. A step
with no owner or no date is listed as such, not dressed up. Open with one
line saying the list covers only the provided files, not the full deal
history.

## Output

The agent's answer is the source of truth — keep every step, owner, and
date it returned; add none it doesn't support. Presentation guidance:

- Dated, mutually-owned commitments first; vague intentions ("circle
  back") last and labeled as vague.
- Keep who-committed-it and when-it's-due attached to each step.
- If nothing concrete comes back, say so plainly — "no dated next step on
  record" is exactly the finding a manager needs — and suggest
  `prep_note` if the real goal is preparing to re-engage.

## What this sends where

MCP mode sends only the query words, dates, and (when pinning) a deal_id
to the zime-mcp server. Local mode reads only the files the user
provided.
