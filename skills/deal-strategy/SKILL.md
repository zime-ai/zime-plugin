---
name: deal-strategy
description: Handles two deal-level jobs — every objection raised in one deal (severity, addressed status, across its calls and CRM record), and prescriptive deal strategy/coaching (how to win, why a deal is stalling, positioning vs. a competitor, playbook vs. reality). Use for pushback/concerns/objections in a named deal — "what's holding Swisscom back" — or how to win/save/advance one — "why are we losing to Concerto Robotics on Acme" — even if they never say "objections". Always calls get_deal_objections for the objections half and ask_zime for the coaching half on zime-mcp when connected — never hand-builds either answer — and handles get_deal_objections's disambiguation (candidate lists, pinning a deal_id). Falls back to extracting objections from a transcript/CRM export for the objections half only; no local equivalent exists for coaching.
license: MIT
metadata:
  zime:category: cross-stage
  zime:dimension: initiative
  zime:input-modes: mcp,transcript
---

# Deal Strategy

Two related jobs, one skill:

1. **Objections** — "what pushback have we gotten on Acme?" The full,
   deal-wide list of objections across every call and CRM record linked to
   that deal, with severity and addressed/unaddressed status.
2. **Strategy & coaching** — "how do I win this?", "why are we losing to
   Competitor X?", "what should I do next?" Prescriptive advice grounded in
   the deal's actual calls, CRM state, and playbook.

## Decision rule (read this first)

Ask: is the request specifically and *only* about objections, pushback, or
concerns in one named deal?

- **Yes, and nothing broader** → call `get_deal_objections`. It is scoped
  server-side to exactly one deal and returns nothing beyond the objection
  list.
- **No — it's prescriptive, comparative, or broader** ("how do I win", "why
  are we losing", "what should I do", positioning against a named
  competitor, playbook-vs-reality) → call `ask_zime` instead.
  `get_deal_objections`'s own agent is pinned server-side to objections in
  one deal and will decline anything broader — sending a strategy question
  there wastes a call and gets a refusal.

A single conversation may legitimately need both, back to back: objections
first via `get_deal_objections`, then a follow-up like "so how do I overcome
that pricing one?" goes to `ask_zime`, carrying the objection forward as
context (see Output below — `ask_zime` has no memory of the prior call).

## Routing

- Next steps / commitments in this ONE deal → `actions-commitments`.
- Plain CRM facts only (stage, amount, owner, close date) → `get-deal`.
- Cross-deal objection or strategy patterns ("what objections are common in
  POC stage", "how are we doing across the pipeline") → `ask_zime` or
  `pipeline-review`; neither tool in this skill resolves more than one deal.
- Competitor-specific patterns across MANY deals ("where are we losing to
  Competitor X in general") → `competitive-intelligence`. A single named
  deal's positioning against a competitor stays here, routed to `ask_zime`.
- Objections or strategy questions about ONE specific call rather than the
  whole deal → `call-recap` shows objections in that call's context;
  `ask_zime` still covers call-specific coaching questions.

## MCP mode (required when zime-mcp is connected)

Both tools live on the same zime-mcp server (fully qualified `Zime:<tool>`;
some clients surface them as `mcp__claude_ai_Zime__<tool>`). Route through
whichever the decision rule above selects. Answering from chat context
while the tool is available is a failure of this skill: only these agents
see the full call history, classified signals, and CRM state together.

### Objections half — `get_deal_objections(query, start_date?, end_date?, deal_id?)`

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

**Outcomes**

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

### Strategy half — `ask_zime(question)`

`ask_zime` is Zime's general-purpose AI agent; its own description
explicitly covers coaching and strategy — how to win, why deals are lost,
what to do next, how reps are positioning, playbook vs. reality — alongside
deal/pipeline intelligence and call-derived signals. It enforces access
control server-side and has no memory of earlier turns.

- Send the question close to verbatim, but resolve pronouns and references
  into the actual entity first — "this deal" becomes the deal's real name,
  since `ask_zime` cannot see this conversation.
- If an objection surfaced earlier in the same conversation (from
  `get_deal_objections`) is relevant to a follow-up strategy question, fold
  it into the question text — `ask_zime` won't otherwise know it happened.

**Example** — "why are we losing to Concerto Robotics on the Acme deal?":

```json
{ "question": "Why are we losing to Concerto Robotics on the Acme deal?" }
```

**Example** — a strategy follow-up carrying forward an earlier objections
result:

```json
{ "question": "In the Acme deal, the main open objection is pricing versus Concerto Robotics's bundled tier. How should the rep overcome that and move the deal forward?" }
```

**Outcomes**

- **An answer** — deliver it per Output below.
- An error or access-control refusal — say plainly what happened; never
  substitute a hand-built strategy in its place.

## Output

**Objections half.** The agent's answer already grades each item —
explicit objection versus unresolved concern versus mild hesitation — with
severity, where it surfaced, and addressed/unaddressed status. Those
distinctions are the analysis; a rep acts differently on an explicit
unaddressed pricing objection than on a mild hesitation:

- Reproduce the answer in full with every objection, its severity, and its
  status intact. Open (unaddressed) objections lead — they're what the rep
  acts on.
- "No supported objections in this deal" is a real finding — deliver it
  briefly and plainly.
- Add nothing the answer doesn't support; reformat only if the user
  explicitly asked.

**Strategy half.** Per `ask_zime`'s own "USING THE RESULT" guidance, relay
its full answer without truncation, paraphrasing, or trimming — it has
already scoped and grounded the advice in the deal's actual evidence. Add
nothing it doesn't support.

## Local mode (only when no zime-mcp server is connected)

**Objections half only.** If the user provides call transcripts or a CRM
export for the deal, extract objections from those files only — each with a
direct quote or field citation, severity as stated (never inferred beyond
the evidence), and addressed/unaddressed status only when the sources show
a response. Open with one line saying the analysis covers only the provided
files, not the full deal history.

**Strategy half.** There is no local equivalent. Prescriptive coaching
depends on `ask_zime`'s live, cross-source analysis of the deal — say
plainly that strategy/coaching advice isn't available without a zime-mcp
connection rather than improvising it from whatever files are on hand.

## What this sends where

MCP mode sends only the query words, dates, and (when pinning) a deal_id to
`get_deal_objections`, or the resolved question text to `ask_zime` — nothing
else leaves this skill. Local mode reads only the files the user provided.
