---
name: deal-objections
description: Surfaces the major objections raised in one specific deal, analyzed across every call, insight, and CRM record linked to that deal — with severity, where each objection surfaced, and whether it was addressed. Use whenever a rep, manager, or deal desk asks about pushback, concerns, blockers, hesitations, or objections in a deal — "what's holding Swisscom back", "what pushback have we gotten on Acme", "which concerns are still open" — even if they never say "objections". Always calls the get_deal_objections tool on the zime-mcp server when connected — never hand-builds the objection list in its place — and handles the tool's disambiguation flow (candidate lists, pinning a deal_id).
license: MIT
metadata:
  zime:category: cross-stage
  zime:dimension: initiative
  zime:input-modes: mcp,transcript
---

# Deal Objections

Answers "what objections have come up in the Swisscom deal?" with the full
deal-wide picture. Zime's deal AI agent analyzes every call and CRM record
linked to the deal and distinguishes explicit objections from unresolved
concerns from recurring hesitations — with severity and whether each was
addressed. This skill reaches that agent correctly and delivers what it
returns, whole.

## Routing

- Objections on ONE specific call → `call-recap` shows them in context.
- Cross-deal objection patterns ("what objections are common in POC?") →
  `ask_zime`; the agent behind this tool is pinned server-side to one deal
  and will decline anything broader.
- Any other deal-level question (health, next steps, stakeholders) →
  `ask_zime` or the matching sibling skill.

## MCP mode (required when zime-mcp is connected)

When a zime-mcp server exposes `get_deal_objections` (fully qualified:
`Zime:get_deal_objections`; some clients surface it as
`mcp__claude_ai_Zime__get_deal_objections`), route the question through it.
Answering from chat context while the tool is available is a failure of
this skill: only the agent sees the full call history, the classified
objection signals, and the CRM state together.

### Arguments

- `query` (required) — words identifying the deal: deal, company, or
  account name. The search matches deal and account names and needs roughly
  75% of the words to hit, so a few distinctive words beat a sentence:
  "Swisscom", not "our big deal with the Swisscom team".
- `start_date` / `end_date` — YYYY-MM-DD, inclusive. Convert time hints
  here and keep time words out of `query`. The window scopes which deals
  are searched by recent call activity (default last 90 days) — it does not
  filter which objections are returned.
- `deal_id` — only to pin: after the tool returned a candidate list (pass
  the chosen candidate's `deal_id`), or when the ID is already known from
  this conversation. Never invent one.

**Example** — "what pushback have we gotten in the Swisscom deal?":

```json
{ "query": "Swisscom" }
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
  from-memory objection list.

## Output

The agent's answer already grades each item — explicit objection versus
unresolved concern versus mild hesitation — with severity, where it
surfaced, and addressed/unaddressed status. Those distinctions are the
analysis; a rep acts differently on an explicit unaddressed pricing
objection than on a mild hesitation:

- Reproduce the answer in full with every objection, its severity, and its
  status intact. Open (unaddressed) objections lead — they're what the rep
  acts on.
- "No supported objections in this deal" is a real finding — deliver it
  briefly and plainly.
- Add nothing the answer doesn't support; reformat only if the user
  explicitly asked.
- Follow-ups ("how do I handle the pricing one?") are objection-handling:
  answer from the returned evidence plus playbook knowledge, and offer
  `ask_zime` for cross-deal proof points.

## Local mode (only when no zime-mcp server is connected)

If the user provides call transcripts or a CRM export for the deal, extract
objections from those files only — each with a direct quote or field
citation, severity as stated (never inferred beyond the evidence), and
addressed/unaddressed status only when the sources show a response. Open
with one line saying the analysis covers only the provided files, not the
full deal history.

## What this sends where

MCP mode sends only the query words, dates, and (when pinning) a deal_id to
the zime-mcp server. Local mode reads only the files the user provided.
