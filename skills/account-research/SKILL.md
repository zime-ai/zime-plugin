---
name: account-research
description: Builds a research brief on ONE named account/customer — CRM facts (domain, industry, owner) plus a synthesized narrative of deal history, recent call sentiment, risk signals, and stakeholder roles. Use whenever someone wants to get up to speed on a single company before outreach, a QBR, or account planning — "get me up to speed on Acme", "give me a rundown on Northwind before the QBR", "what's the state of the Concerto account" — even if they never say "research" or "brief". Always calls get_account for the CRM facts and ask_zime for the narrative layer on the zime-mcp server when connected — never hand-builds either half from memory or chat history in their place — and handles get_account's disambiguation flow (multiple_matches candidates, pinning an account_id). Falls back to building a narrower brief from a user-provided CRM export and/or call transcripts only when no zime-mcp server is available.
license: MIT
metadata:
  zime:category: cross-stage
  zime:dimension: initiative
  zime:input-modes: mcp,csv,transcript
---

# Account Research

Answers "get me up to speed on Acme" with one coherent brief: the hard CRM
facts on the account plus the synthesized picture of how the relationship
is actually going — deal history, recent call sentiment, risk signals, and
who the stakeholders are. No single tool produces that whole brief, so
this skill's job is to call both of the tools that together do, and
assemble what they return without adding anything of its own.

## Routing

- The user names ONE specific deal on this account ("what stage is the
  Acme renewal in", "what pushback have we gotten on the Acme expansion")
  → `get-deal` for the record, `deal-strategy` for objections/coaching, `actions-commitments` for next
  steps. Don't fold a single deal's detail into this brief — route it.
- The user names ONE specific call ("what happened on the last Acme call")
  → `get-meeting`, `get-transcript`, or `call-recap`.
- The user wants to get ready for a specific UPCOMING, scheduled meeting →
  `call-prep`, not this skill — that tool is tuned for one meeting, not an
  account-wide brief.
- Just the bare CRM record, no narrative → `get-account` alone is enough;
  this skill is for when the ask is broader than that.
- Cross-account questions ("which accounts are at risk") → `ask_zime`;
  this skill resolves exactly one named account.

## MCP mode (required when zime-mcp is connected)

When a zime-mcp server exposes `get_account` and `ask_zime` (fully
qualified `Zime:get_account` / `Zime:ask_zime`; some clients surface them
as `mcp__claude_ai_Zime__get_account` / `mcp__claude_ai_Zime__ask_zime`),
build the brief from both, in order. Hand-building either half — the CRM
facts or the narrative — from memory or chat context while the tools are
available is a failure of this skill: only these two calls together see
the live CRM record and the full cross-call, cross-deal picture.

### Step 1 — `get_account` for the CRM facts

Call this first, with the account name the user gave.

- `query` — the account/company name, e.g. "Acme".
- `account_id` — pin an exact account, only after a prior
  `multiple_matches` response or when already known from this
  conversation. Never invent one.
- `domain` — narrow by domain when the name alone is ambiguous.

**Example** — "get me up to speed on Acme":

```json
{ "query": "Acme" }
```

The tool returns one of three shapes:

- `{"status": "resolved", "data": {...}}` — the account record (domain,
  industry, owner, and whatever other fields it carries). Carry the
  resolved account name forward into Step 2.
- `{"status": "multiple_matches", "candidates": [...]}` — more than one
  account matched. Show the candidates, ask the user which one they mean,
  re-call with the chosen `account_id`, then continue to Step 2. Never
  guess among them.
- `{"status": "no_match"}` — no account matched; say so plainly. Still
  offer to run Step 2 with the name as given, since `ask_zime` may resolve
  it even when the CRM lookup didn't, but label that half of the brief
  accordingly if it does.
- An error — `isError: true` with `{"error": "<CODE>"}`. `INTERNAL_ERROR`
  is usually transient: retry once. `UNAUTHORIZED` or `FORBIDDEN` means the
  Zime connection needs re-authorizing or lacks access — say so.
  `INVALID_ARGUMENT` means the arguments were malformed — fix and re-call.
  If it still fails, say the CRM lookup half of the brief couldn't be
  reached, then still attempt Step 2 rather than dropping the whole brief.

### Step 2 — `ask_zime` for the narrative

Call this with the user's own question, close to verbatim, plus the
resolved account name from Step 1 substituted in for any pronoun or vague
reference. `ask_zime` has no memory of Step 1 — never send it a bare
"this account" or "them".

- `question` (required) — e.g. if the user asked "get me up to speed on
  Acme before the QBR", send that close to verbatim; if they said "give me
  a rundown before my call with them" and Step 1 resolved the account to
  "Acme", send "give me a rundown on Acme before my call with them" (or
  similar) — never a bare "them". Don't broaden scope beyond what was
  asked (e.g. don't add "and all related accounts" on your own), and don't
  narrow it either.

**Example** — continuing the Acme example, if the user's original ask was
"get me up to speed on Acme":

```json
{ "question": "get me up to speed on Acme — deal history, recent call sentiment, risk signals, and key stakeholders" }
```

Outcomes: `ask_zime` returns its answer as text, already scoped and
access-controlled server-side — deliver it per Output below. If it
declines (out of scope, no access, no data), say so plainly rather than
filling the gap from Step 1's data or from memory.

## Output

Assemble one brief from the two calls, in this order, and nothing else:

1. **CRM facts** — the account record from Step 1: domain, industry,
   owner, and any other fields it carried. If Step 1 was `no_match` or
   errored, say so instead of a facts section.
2. **Narrative** — the `ask_zime` answer from Step 2, reproduced with its
   distinctions intact (deal history, sentiment, risk signals, stakeholder
   roles — whatever it actually returned). Don't re-rank, re-word, or trim
   its findings, and don't add a finding it didn't state.

Every fact in the brief traces to one of these two calls. A gap — a field
Step 1 didn't carry, a topic Step 2 didn't cover — is presented as a gap,
not filled in with a plausible guess. If the user's ask was narrower than
"get me up to speed" (e.g. just "what's our relationship health with
Acme"), it's fine for the brief to lead with the relevant half and keep
the other brief, rather than padding it out.

## Local mode (only when no zime-mcp server is connected)

If the user provides a CRM export (`.csv`) and/or call transcripts
(`.txt`, `.vtt`, `.json`, `.md`) for the account, build a narrower brief
from those files only — CRM facts from the export, narrative signals
(sentiment, risk, stakeholders) only where the transcripts actually state
them, each with a file or quote citation. Open with one line saying the
brief covers only the provided files, not the account's full live history.
No files and no connection → say so rather than guessing at the account's
facts or relationship health.

## What this sends where

MCP mode sends only the query words, domain, and (when pinning) an
account_id to `get_account`, and the resolved question text to `ask_zime`
— nothing else. Local mode reads only the files the user provided.
