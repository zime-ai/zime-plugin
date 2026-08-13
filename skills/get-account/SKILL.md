---
name: get-account
description: Looks up ONE CRM account (company/customer) record — domain, industry, owner. Use whenever someone wants the facts on a single named account/company — "what account is Acme on our side", "who owns the Northwind account", "what industry is Concerto in" — even if they never say "account". Always calls the get_account tool on the zime-mcp server when connected — never hand-answers from memory or chat context in its place — and handles the tool's disambiguation flow (multiple_matches candidates, pinning an account_id). Falls back to looking up the account in a user-provided CRM export only when no zime-mcp server is available.
license: MIT
metadata:
  zime:category: cross-stage
  zime:dimension: initiative
  zime:input-modes: mcp,csv
---

# Get Account

Answers "what do we have on file for Acme?" with the one CRM record for
that account — nothing synthesized, nothing inferred. This is a lookup, not
an analysis: for anything that requires reasoning across calls or deals
about the account, route elsewhere per below.

## Routing

- The DEAL tied to this account, not the account record itself → `get-deal`.
- A specific PERSON at this account → `get-contact` (not bundled in this
  plugin yet — until then, `ask_zime`).
- Objections, next steps, strategy, or "how are we doing with this
  customer" → `ask_zime` or `account-research` for a fuller research brief.
- Research across everything Zime knows about the account (calls, deals,
  sentiment, history) → `account-research`.

## MCP mode (required when zime-mcp is connected)

When a zime-mcp server exposes `get_account` (fully qualified:
`Zime:get_account`; some clients surface it as
`mcp__claude_ai_Zime__get_account`), route the lookup through it.
Answering from memory or chat context while the tool is available is a
failure of this skill — the tool reads the live CRM record, and a
remembered or guessed domain/owner can be stale or wrong.

### Arguments

- `query` — the account/company name, e.g. "Acme". Omit if you already
  have `account_id`.
- `account_id` — pin an exact account (from a prior `multiple_matches`
  response, or already known from this conversation). Never invent one.
- `domain` — narrow by domain when the name alone is ambiguous (e.g. two
  "Acme" accounts on different domains).

**Example** — "who owns the Acme account?":

```json
{ "query": "Acme" }
```

### Outcomes

The tool returns one of three shapes:

- `{"status": "resolved", "data": {...}}` — the account record (domain,
  industry, owner, and whatever other fields it carries). Deliver per
  Output below.
- `{"status": "multiple_matches", "candidates": [...]}` — more than one
  account matched. Show the candidates, ask the user which one they mean,
  then re-call with the chosen `account_id`. Never guess among them.
- `{"status": "no_match"}` — no account matched; say so plainly rather than
  substituting a similarly-named account.
- An error — `isError: true` with `{"error": "<CODE>"}`. `INTERNAL_ERROR`
  is usually transient: retry once. `UNAUTHORIZED` or `FORBIDDEN` means the
  Zime connection needs re-authorizing or lacks access — say so.
  `INVALID_ARGUMENT` means the arguments were malformed — fix and re-call.
  If it still fails, say plainly the account-lookup service couldn't be
  reached and offer the local fallback. Never substitute a remembered or
  guessed record.

## Output

Relay the record's fields as returned — don't add, infer, or round
anything it doesn't state. A field the record doesn't carry is presented as
absent, not filled in with a plausible guess.

## Local mode (only when no zime-mcp server is connected)

If the user provides a CRM export (`.csv`), look up the account row there
instead and say the answer is limited to that file, not the live CRM. No
file and no connection → say so rather than guessing at the account's
domain, industry, or owner.

## What this sends where

MCP mode sends only the query words, domain, and (when pinning) an
account_id to the zime-mcp server. Local mode reads only the file the user
provided.
