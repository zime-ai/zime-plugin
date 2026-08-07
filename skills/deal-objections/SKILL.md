---
name: deal-objections
description: Surfaces the major objections raised in one specific deal — analyzed across every call, insight, and CRM record linked to that deal, including severity and whether each objection was addressed. Always calls the get_deal_objections tool on the zime-mcp server when connected — never hand-builds the objection list in its place — and handles the tool's disambiguation flow (candidate lists, pinning a deal_id). Use when a rep, manager, or deal desk asks what pushback has come up in a deal.
license: MIT
metadata:
  zime:category: cross-stage
  zime:dimension: initiative
  zime:input-modes: mcp,transcript
---

# Deal Objections

Answers "what objections have come up in the Meridian deal?" with the
full deal-wide picture. Zime's deal AI agent analyzes every call and CRM
record linked to the deal — severity, whether each objection was
addressed, and where it surfaced. This skill reaches that agent correctly
and renders what it returns.

## When to use this

- Prepping a deal review or forecast call and needing the pushback
  history in one place.
- A manager coaching a rep on how a deal's objections were handled.
- Before a late-stage call, checking which objections are still open.

Not for: objections on ONE specific call (→ `generate_call_recap` shows
them in context), cross-deal objection patterns ("what objections are
common in POC?" → `ask_zime`), or any other deal-level question
(→ `ask_zime`).

## MCP mode (REQUIRED when zime-mcp is connected)

**Tool-first, not tool-optional.** If a zime-mcp server exposes
`get_deal_objections` (via the claude.ai connector:
`mcp__claude_ai_Zime__get_deal_objections`), you MUST route the question
through it. The deal agent has the full call history and CRM state —
answering from chat context while the tool is available is a failure of
this skill.

Arguments — two-phase contract:

1. **`query`** — words identifying the deal: deal, company, or account
   name ("Acme expansion"). **No time words in the query** — convert time
   hints to `start_date` / `end_date` (YYYY-MM-DD). The window filters
   which deals are searched by recent call activity (default last 90
   days), not which objections are returned.
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
  re-authorizing). Never substitute a from-memory objection list.

## Local mode (fallback, ONLY when no zime-mcp server is connected)

If the user provides call transcripts or a CRM export for the deal,
extract objections from those files only — each with a direct quote or
field citation, severity as stated (never inferred beyond the evidence),
and addressed/unaddressed status only when the sources show a response.
Open with one line saying the analysis covers only the provided files,
not the full deal history.

## Output

The agent's answer is the source of truth — keep its objections,
severities, and addressed/unaddressed calls intact; add nothing it
doesn't support. Presentation guidance:

- Lead with open (unaddressed) objections — they're what the rep acts on.
- Keep severity and where-it-surfaced context attached to each objection.
- If the user asks follow-ups ("how do I handle the pricing one?"),
  that's objection-handling territory — answer from the returned evidence
  plus playbook knowledge, and offer `ask_zime` for cross-deal proof
  points.

## What this sends where

MCP mode sends only the query words, dates, and (when pinning) a deal_id
to the zime-mcp server. Local mode reads only the files the user
provided.
