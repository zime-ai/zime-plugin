---
name: get-deal
description: Looks up ONE CRM deal record — stage, amount, owner, close date. Use whenever someone wants the facts on a single named deal — "what stage is Acme expansion in", "what's the close date on Northwind", "who owns the Concerto deal" — even if they never say "deal record". Always calls the get_deal tool on the zime-mcp server when connected — never hand-answers from memory or chat context in its place — and handles the tool's disambiguation flow (multiple_matches candidates, pinning a deal_id). Falls back to looking up the deal in a user-provided CRM export only when no zime-mcp server is available.
license: MIT
metadata:
  zime:category: cross-stage
  zime:dimension: initiative
  zime:input-modes: mcp,csv
---

# Get Deal

Answers "what stage is the Acme expansion in?" with the one CRM record for
that deal — nothing synthesized, nothing inferred. This is a lookup, not an
analysis: for anything that requires reasoning about the deal, route
elsewhere per below.

## Routing

- Objections in this ONE deal → `ask_zime` or `deal-strategy`.
- Next steps / commitments in this ONE deal → `actions-commitments`.
- "How do I win this deal" / coaching / strategy → `deal-strategy`.
- Questions about MANY deals (filters, aggregations, "deals at risk",
  "what's stuck") → `ask_zime` or `pipeline-review`; this tool resolves
  exactly one deal and will not answer those.
- The account behind this deal → `get-deal`'s `data` already names the
  account; for the account's own record, use `get-account`.

## MCP mode (required when zime-mcp is connected)

When a zime-mcp server exposes `get_deal` (fully qualified: `Zime:get_deal`;
some clients surface it as `mcp__claude_ai_Zime__get_deal`), route the
lookup through it. Answering from memory or chat context while the tool is
available is a failure of this skill — the tool reads the live CRM record,
and a remembered stage/amount can be stale or wrong.

### Arguments

- `query` — deal or account name, e.g. "Acme expansion". Omit if you
  already have `deal_id`.
- `deal_id` — pin an exact deal (from a prior `multiple_matches` response,
  or already known from this conversation). Never invent one.
- `account_name` — narrow by account name when the deal name alone is
  ambiguous.
- `start_date` / `end_date` — YYYY-MM-DD, inclusive. Convert time hints
  here and keep time words out of `query`.

**Example** — "what stage is the Acme expansion in?":

```json
{ "query": "Acme expansion" }
```

### Outcomes

The tool returns one of three shapes:

- `{"status": "resolved", "data": {...}}` — the deal record (stage,
  amount, owner, close date, and whatever other fields it carries). Deliver
  per Output below.
- `{"status": "multiple_matches", "candidates": [...]}` — more than one
  deal matched. Show the candidates, ask the user which one they mean, then
  re-call with the chosen `deal_id`. Never guess among them.
- `{"status": "no_match"}` — no deal matched; say so plainly rather than
  substituting a similarly-named deal.
- An error — `isError: true` with `{"error": "<CODE>"}`. `INTERNAL_ERROR`
  is usually transient: retry once. `UNAUTHORIZED` or `FORBIDDEN` means the
  Zime connection needs re-authorizing or lacks access — say so.
  `INVALID_ARGUMENT` means the arguments were malformed — fix and re-call.
  If it still fails, say plainly the deal-lookup service couldn't be
  reached and offer the local fallback. Never substitute a remembered or
  guessed record.

## Output

Relay the record's fields as returned — don't add, infer, or round
anything it doesn't state. A field the record doesn't carry (e.g. no close
date set) is presented as absent, not filled in with a plausible guess.

## Local mode (only when no zime-mcp server is connected)

If the user provides a CRM export (`.csv`), look up the deal row there
instead and say the answer is limited to that file, not the live CRM. No
file and no connection → say so rather than guessing at the deal's stage,
amount, or close date.

## What this sends where

MCP mode sends only the query words, dates, account name, and (when
pinning) a deal_id to the zime-mcp server. Local mode reads only the file
the user provided.
