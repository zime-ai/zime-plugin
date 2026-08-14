---
name: get-email
description: Looks up email correspondence with ONE account or contact — who wrote, when, subject, and the thread. Use whenever someone wants the facts of an email exchange — "what did Acme say in email", "pull the last thread with Northwind", "did we ever email Concerto about pricing" — even if they never say "email record". Always calls the list_emails tool on the zime-mcp server when connected, never reconstructs an email from memory or chat context, and handles the disambiguation flow (multiple_matches candidates, pinning an id). Falls back to a user-provided email export only when no zime-mcp server is available.
license: MIT
metadata:
  zime:category: cross-stage
  zime:dimension: initiative
  zime:input-modes: mcp,csv
---

# Get Email

Answers "what did Acme actually say in email?" with the real correspondence —
nothing reconstructed. This is a lookup, not a draft.

## How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                         GET EMAIL                                │
├─────────────────────────────────────────────────────────────────┤
│  RESOLVE (this skill's whole job)                                │
│  ✓ Account/contact + optional topic & dates → thread(s)          │
│  ✓ Ambiguous → show candidates, ask, re-call pinned              │
│  ✓ Return sender, date, subject, body as returned                │
├─────────────────────────────────────────────────────────────────┤
│  NOT THIS SKILL (route away)                                     │
│  ✗ Writing an email             → follow-up                      │
│  ✗ Commitments made over email  → actions-commitments            │
│  ✗ Call transcripts             → get-transcript                 │
├─────────────────────────────────────────────────────────────────┤
│  LOCAL FALLBACK (no zime-mcp)                                    │
│  ~ Read an email export the user provides                        │
└─────────────────────────────────────────────────────────────────┘
```

## Usage

```
/get-email <account or contact> [+ topic] [+ when]
```

Find email with: $ARGUMENTS

## Routing

- **Drafting** an email → `follow-up`. This skill reads; that one writes.
- Promises or commitments made in email → `actions-commitments`.
- What was said on a call → `get-transcript`.
- The account record itself → `get-account`.

## What I Need From You

Which account or person. A topic and date range narrow it usefully — email
volume per account is high, so an unfiltered request often returns
`multiple_matches`.

## MCP mode (required when zime-mcp is connected)

**Required tool:** `list_emails` (fully qualified `Zime:list_emails`).

Reconstructing what an email "probably said" while the tool is available is a
failure of this skill — an invented quote from a customer is worse than no
answer.

### Arguments

- `query` — account name, contact name, or email address. Keep time words OUT.
- `email_id` / `thread_id` — pin an exact message or thread from a prior
  `multiple_matches` response. Never invent one.
- `account_name` — narrow when a contact name alone is ambiguous.
- `start_date` / `end_date` — YYYY-MM-DD, inclusive. All time hints here.

**Example** — "what did Acme say about pricing last month?":

```json
{ "query": "Acme pricing", "start_date": "2026-07-01", "end_date": "2026-07-31" }
```

### Outcomes

- `{"status": "resolved", "data": {...}}` — the thread or message. Deliver
  per Output below.
- `{"status": "multiple_matches", "candidates": [...]}` — show candidates
  with sender and date, ask which one, re-call pinned. Never guess.
- `{"status": "no_match", "candidates": [...]}` — nothing matched. This does
  **not** mean no such email exists: the window may exclude it, the address
  may differ, or it may not be visible to this user. Say that, show
  near-misses, offer to widen. Never invent an exchange.
- An error — `{"error": "<CODE>"}`. `INTERNAL_ERROR` retry once;
  `UNAUTHORIZED` / `FORBIDDEN` means re-authorize or lack of access;
  `INVALID_ARGUMENT` means malformed dates — fix and re-call.

## Output

```markdown
**Email — [subject]** · [date]
**From:** [sender] → **To:** [recipients]
**Account:** [account name]

---

[message body, verbatim as returned]

---
_[N] messages in this thread. Live email record via Zime._
```

Rules:

- Relay bodies **verbatim**. Never tidy up, summarize, or "clarify" what
  someone wrote — this skill exists to show the actual words.
- Show sender and date on every message; who said it and when is usually the
  point of the question.
- If a thread is returned, keep chronological order.
- Quotation marks require a real returned message, never a paraphrase.

## Tips

1. **Add a topic word** — "Acme" alone matches everything; "Acme pricing"
   narrows fast.
2. **Date-bound it** — email is the highest-volume source; an open-ended
   query usually needs disambiguating.
3. **Reading vs writing** — this reads correspondence; `follow-up` writes it.

## Local mode (only when no zime-mcp server is connected)

If the user provides an email export (`.csv`, `.md`, `.txt`), read it and say
the answer is limited to that file. No file and no connection → say so rather
than describing an exchange that may not have happened.

## What this sends where

MCP mode sends only the query words, dates, account name, and (when pinning)
an id to the zime-mcp server. Local mode reads only the provided file.

## Related Skills

- **follow-up** — draft the next email
- **actions-commitments** — promises made across calls and email
- **get-account** — the account record behind the correspondence
