---
name: get-account
description: Looks up one account already in CRM. Shows domain, industry, and owner. For a company not yet in CRM, use account-research instead.
license: MIT
metadata:
  zime:category: cross-stage
  zime:dimension: initiative
  zime:input-modes: mcp,csv
---

# Get Account

Answers "pull up the Acme account" with the one CRM record for that account —
nothing synthesized, nothing inferred. This is a lookup, not research.

## How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                        GET ACCOUNT                               │
├─────────────────────────────────────────────────────────────────┤
│  RESOLVE (this skill's whole job)                                │
│  ✓ Name or domain → one account_id                               │
│  ✓ Ambiguous → show candidates, ask, re-call pinned              │
│  ✓ Return the record's fields verbatim                           │
├─────────────────────────────────────────────────────────────────┤
│  NOT THIS SKILL (route away)                                     │
│  ✗ Company NOT in CRM yet         → account-research             │
│  ✗ Account health / churn risk    → competitive-intelligence     │
│                                      or deal-strategy            │
│  ✗ The deals on this account      → get-deal / pipeline-review   │
├─────────────────────────────────────────────────────────────────┤
│  LOCAL FALLBACK (no zime-mcp)                                    │
│  ~ Look the row up in a CRM export the user provides             │
└─────────────────────────────────────────────────────────────────┘
```

## Usage

```
/get-account <account name or domain>
```

Look up the account: $ARGUMENTS

## Routing

- A **prospect** not yet in CRM — ICP fit, company intel, outside research →
  `account-research`. That skill web-searches; this one reads CRM.
- Signals, churn risk, or expansion on an existing account →
  `competitive-intelligence` (cross-account) or `deal-strategy` (one deal).
- Deals belonging to this account → `get-deal` for one, `pipeline-review`
  for many.

## What I Need From You

The account name or domain. If several match, I'll show candidates and ask —
I will not pick for you.

## MCP mode (required when zime-mcp is connected)

**Required tool:** `list_accounts` (fully qualified `Zime:list_accounts`).

Answering from memory while the tool is available is a failure of this
skill — the tool reads the live CRM record.

### Arguments

- `query` — account or company name, e.g. "Acme". Omit if you already have
  `account_id`.
- `account_id` — pin an exact account, from a prior `multiple_matches`
  response or already known this conversation. Never invent one.
- `domain` — narrow when the name alone is ambiguous.

**Example** — "pull up the Acme account":

```json
{ "query": "Acme" }
```

### Outcomes

- `{"status": "resolved", "data": {...}}` — the account record. Deliver per
  Output below.
- `{"status": "multiple_matches", "candidates": [...]}` — show candidates,
  ask which one, re-call with the chosen `account_id`. Never guess.
- `{"status": "no_match", "candidates": [...]}` — nothing matched
  confidently. This does **not** mean the account doesn't exist: it may be
  named differently in CRM or not visible to this user. Say that, show any
  near-miss candidates, and consider whether the user actually meant a
  prospect (→ `account-research`). Never substitute a similarly-named
  account.
- An error — `{"error": "<CODE>"}`. `INTERNAL_ERROR` is usually transient:
  retry once. `UNAUTHORIZED` / `FORBIDDEN` means re-authorize or lack of
  access. `INVALID_ARGUMENT` means malformed arguments — fix and re-call.

## Output

```markdown
**[Account name]**

| Field | Value |
|---|---|
| Domain | [domain] |
| Industry | [industry] |
| Account type | [type] |
| Owner | [owner name / email] |
| Account ID | `[crm_id]` |

_Live CRM record via Zime._
```

Rules:

- Relay fields exactly as returned; no inference, no rounding.
- A field the record doesn't carry is shown as absent, not guessed.
- Keep the `Account ID` line: later skills pin to it.


### Render it as a visual artifact

Present the finished output as a self-contained HTML artifact rather than
plain markdown in the chat, so it's scannable at a glance:

- **Card-style sections** for each block above, not one long wall of text.
- **Badges** for short labelled values (stage, status, owner, dates).
- **Light colour accents on status and risk fields only** — red for
  at-risk/blocked/overdue, amber for needs-attention, green for
  on-track/confirmed. Colour carries meaning here, so never colour a field
  that has no status semantics, and always keep the word as well as the
  colour: colour alone is unreadable for anyone who can't distinguish it.
- **Keep prose in the chat response, not in the artifact.** Caveats, what
  you did, and what to do next belong in the surrounding message. The
  artifact holds the structured result.
- Every grounding rule above still applies. An artifact makes gaps *less*
  visible, so a missing value stays visible as "not stated" rather than
  being quietly dropped to keep a card tidy.

Fall back to the markdown above when artifacts aren't available in the
current environment (for example Claude Code in a terminal). Say which you
did only if the user asked for a specific format.

## Tips

1. **Domain beats name** — "acme.com" resolves more precisely than "Acme".
2. **CRM vs prospect** — if you're researching someone you've never sold to,
   you want `account-research`, not this.

## Local mode (only when no zime-mcp server is connected)

If the user provides a CRM export (`.csv`), look up the row there and say the
answer is limited to that file. No file and no connection → say so rather
than guessing.

## What this sends where

MCP mode sends only the query words, domain, and (when pinning) an
`account_id` to the zime-mcp server. Local mode reads only the provided file.

## Related Skills

- **account-research** — a company not yet in CRM (web research + ICP fit)
- **get-deal** — a specific deal on this account
- **create-sales-to-cs-handover** — package this account for CS
