---
name: sales-cs-handover
description: Assembles the handoff packet Customer Success needs when a deal moves from Sales into onboarding — the deal's CRM state, key stakeholders, what was actually committed or promised during the sales cycle, technical requirements or landmines raised on calls, and risks CS should watch going in. Use whenever someone is handing a deal off to CS or onboarding — "put together a handover for the Acme deal", "what does CS need to know before onboarding Northwind", "brief the CS team on Concerto before kickoff" — even if they never say "handover" or "handoff". Always assembles the packet from get_deal for the CRM record, get_deal_next_steps for committed next steps, and ask_zime for stakeholders, risks, and technical landmines — never hand-builds any part of it from memory while zime-mcp is connected — and handles each tool's own disambiguation flow. Falls back to assembling a narrower handoff from a user-provided CRM export and/or call transcripts only when no zime-mcp server is available.
license: MIT
metadata:
  zime:category: cross-stage
  zime:dimension: initiative
  zime:input-modes: mcp,csv,transcript
---

# Sales → CS Handover

Builds the packet a CS or onboarding owner reads on day one of a deal: the
CRM facts, who they're dealing with, what Sales actually promised, and what
could bite them technically. No single zime-mcp tool covers all of that —
this skill calls three of them in sequence and assembles what each returns
into one traceable document. Nothing here is synthesized from chat context;
every section cites the tool call it came from.

## Routing

- The deal is still open and being actively worked/sold, not yet handed off
  → `deal-strategy` (coaching/strategy) or `actions-commitments` (tracking
  commitments while selling) — this skill is for the handoff moment, not
  the sales motion itself.
- Only the raw CRM facts (stage, amount, owner, close date), no
  stakeholders/commitments/risk synthesis → `get-deal` alone.
- One specific call's content — a recap, or the exact wording of one call →
  `call-recap` or `get-transcript`; this skill only pulls a transcript when
  it needs to quote a specific already-identified promise.
- Objection *coaching* — how to handle or overcome a live objection — is
  `deal-strategy`'s job, not this one. This skill only surfaces objections
  that read as an unresolved risk CS should watch, and even then it asks
  `ask_zime` a risk-framed question rather than calling
  `get_deal_objections` — that tool's severity/addressed-status grading is
  built for a rep still working the objection, not a CS owner inheriting it.

## MCP mode (required when zime-mcp is connected)

Build the packet from three tools, in this order, reusing the resolved
`deal_id` and account/deal name across all three so later calls don't
re-trigger disambiguation the first call already resolved.

### 1. CRM snapshot — `get_deal`

Fully qualified `Zime:get_deal` (some clients: `mcp__claude_ai_Zime__get_deal`).
Arguments: `query`, `deal_id`, `account_name`, `start_date`, `end_date` — same
contract as `skills/get-deal/SKILL.md`.

```json
{ "query": "Acme expansion" }
```

- `{"status": "resolved", "data": {...}}` — keep the returned `deal_id`;
  reuse it below.
- `{"status": "multiple_matches", "candidates": [...]}` — show the
  candidates, ask which deal, re-call with the chosen `deal_id`.
- `{"status": "no_match"}` — say so plainly; nothing else in this packet
  can be built without a resolved deal.
- Error `{"error": "<CODE>"}` (`UNAUTHORIZED`/`FORBIDDEN`/`INVALID_ARGUMENT`/
  `INTERNAL_ERROR`) — retry `INTERNAL_ERROR` once; otherwise say the
  deal-lookup service couldn't be reached and stop, or offer local mode.

### 2. Committed next steps — `get_deal_next_steps`

Fully qualified `Zime:get_deal_next_steps`. Arguments: `query`,
`start_date`, `end_date`, `deal_id` — same contract as
`skills/actions-commitments/SKILL.md`. Pin `deal_id` to the one resolved in
step 1 to skip re-disambiguation.

```json
{ "query": "Acme expansion", "deal_id": "<deal_id from step 1>" }
```

- An answer — separates committed next steps (promised in calls, with
  owner/date when stated), scheduled meetings, and recommended actions.
  Keep those three groupings intact; do not collapse them into one
  "commitments" list.
- A candidate list (`status`: `multiple_matches`/`no_match`, `message`,
  up to 5 `candidates`) — only reachable if step 1 was skipped or the
  `deal_id` was rejected; resolve the same way as step 1.
- Error `{"error": "<CODE>"}` (`INTERNAL_ERROR`/`STREAM_ERROR`/
  `UNAUTHORIZED`/`INVALID_DATE_RANGE`) — retry the transient ones once,
  otherwise mark commitments as unavailable rather than filling from
  memory.

### 3. Stakeholders, risks, and technical landmines — `ask_zime`

Fully qualified `Zime:ask_zime`. Single argument `question`. Resolve the
deal/account name from step 1 into the question text — never pass a bare
pronoun or "this deal," since `ask_zime` has no memory of steps 1–2. Ask two
separate, narrow questions rather than one broad one, so each answer stays
traceable to what it was asked:

```json
{ "question": "Who are the key stakeholders on the Acme expansion deal, and what's known about their roles and sentiment?" }
```

```json
{ "question": "What technical requirements, integration constraints, or unresolved risks came up on the Acme expansion calls that Customer Success should know before onboarding?" }
```

Send the question close to verbatim once the entity is resolved; do not
compress it into keywords. `ask_zime` enforces access control server-side
and returns a synthesized answer — relay it, don't re-derive it.

### 4. Exact wording — `get_transcript` (only when needed)

If the user (or the assembled packet) needs the precise wording of one
specific promise or requirement and a call has already been identified
(e.g., `ask_zime` names a date, or a next step cites one), pull that one
call's transcript per `skills/get-transcript/SKILL.md`'s contract
(`query`/`call_id`/`start_date`/`end_date`). Don't call this speculatively —
only to verify or quote a claim already surfaced above.

## Output

Assemble one handoff document with four sections, each sourced from a named
tool call:

1. **Deal snapshot** — stage, amount, owner, close date, exactly as
   `get_deal` returned them; a field it didn't carry is marked absent, not
   guessed.
2. **Key stakeholders** — from the `ask_zime` stakeholder question; include
   role and sentiment only where the answer states them.
3. **What Sales committed** — the committed-next-steps and scheduled-
   meetings groupings from `get_deal_next_steps`, with owner and date kept
   attached to each item; "recommended" items are sales-side suggestions,
   not promises — label them as such if included, or drop them since they
   aren't commitments CS inherits.
4. **Technical landmines and risks CS should watch** — from the
   `ask_zime` risk question; if it surfaces an unresolved objection, present
   it as a risk to watch, not as objection-handling guidance.

Mark any section the tools couldn't fill (no match, an error, a "nothing
found" answer) as a gap in the packet — never paper over it with a
plausible-sounding filler paragraph. Add nothing beyond what the four tool
calls returned; reformat only if the user explicitly asked for a different
layout.

## Local mode (only when no zime-mcp server is connected)

If the user provides a CRM export (`.csv`) and/or call transcripts, build
the same four sections from those files only — deal facts from the CRM row,
stakeholders/commitments/risks extracted from the transcripts with a quote
or field citation for each. A commitment with no stated owner or date, or a
risk with no supporting quote, is listed as such, not dressed up. Open with
one line saying the packet covers only the provided files, not the deal's
full history.

## What this sends where

MCP mode sends only the query words, dates, resolved `deal_id`, and the
phrased `ask_zime` questions to the zime-mcp server, which looks up CRM,
call, and commitment data the workspace already holds. Local mode reads
only the files the user provided — nothing leaves the machine.
