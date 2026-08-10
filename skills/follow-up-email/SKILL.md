---
name: follow-up-email
description: Drafts the follow-up email to the prospect after one recorded sales call, grounded in what was actually said on that call. Use whenever a rep wants the email to send after a call — "draft my follow-up", "write the email for my Acme call", "send them a summary of what we agreed" — even if they never say "follow-up email". Always calls the draft_follow_up_email tool on the zime-mcp server when connected — never hand-writes the email in its place — and handles the tool's two-phase disambiguation (candidate lists, pinning a call_id). Nothing is ever sent; the deliverable is a draft. Falls back to drafting from a user-provided transcript only when no zime-mcp server is available.
license: MIT
metadata:
  zime:category: cross-stage
  zime:dimension: initiative
  zime:input-modes: mcp,transcript
---

# Follow-up Email

Drafts the post-call email a rep sends the prospect. Zime's call AI agent
writes it from the verbatim transcript and the call's extracted signals, so
every referenced detail — names, numbers, commitments — is something that
was actually said. This skill reaches that agent correctly, presents the
draft, and never sends anything.

## Routing

- Emails not tied to one recorded call (cold outreach, a check-in with no
  call behind it) → draft normally, or use `ask_zime` for account context.
- A recap rather than an email → `call-recap`.
- Cross-call context ("mention what they said across our last three
  calls") → `ask_zime`; the agent behind this tool is pinned server-side to
  one call and will decline anything broader.

## MCP mode (required when zime-mcp is connected)

When a zime-mcp server exposes `draft_follow_up_email` (fully qualified:
`Zime:draft_follow_up_email`; some clients surface it as
`mcp__claude_ai_Zime__draft_follow_up_email`), route the draft through it.
Hand-writing the email from chat context while the tool is available is a
failure of this skill: an email that misquotes a number or invents a
commitment damages the deal, and only the agent has the transcript.

### Arguments

- `query` (required) — words identifying the call. The search matches call
  titles, deal names, and account names and needs roughly 75% of the words
  to hit, so a few distinctive words beat a sentence: "Acme renewal", not
  "the call we had with Acme about the renewal".
- `start_date` / `end_date` — YYYY-MM-DD, inclusive. Convert every time
  hint here ("this morning", "yesterday") and keep time words out of
  `query`. Default window: the user's own recorded calls, last 90 days.
- `call_id` — only to pin: after the tool returned a candidate list (pass
  the chosen candidate's `call_id`), or when the ID is already known from
  this conversation. Never invent one.

**Example** — "draft the follow-up for my Acme call this morning" (today
2026-08-10):

```json
{ "query": "Acme", "start_date": "2026-08-10", "end_date": "2026-08-10" }
```

### Outcomes

- **A draft** — present it per Output below.
- **A candidate list** — JSON with `status` (`multiple_matches` or
  `no_match`), a `message`, and up to 5 `candidates` (call_id, title, date,
  account_name, deal_name), newest first. On `no_match` the candidates are
  the user's most recent recorded calls, offered as a fallback — present
  them as such. Show title/date/account and ask which call — EXCEPT when
  the user asked about their "latest" or "most recent" call: take the first
  candidate and re-call without asking.
- **An error** — `{"error": "<CODE>"}`. `INTERNAL_ERROR` and `STREAM_ERROR`
  are usually transient: retry once. `UNAUTHORIZED` means the Zime
  connection needs re-authorizing — say so. `INVALID_DATE_RANGE` means the
  dates are malformed or reversed — fix and re-call. If it still fails, say
  plainly the drafting service couldn't be reached and offer the local
  fallback. Never silently hand-write a draft and present it as grounded in
  the transcript.

## Output

The agent returns a plain-text email — subject, greeting, a specific
reference to the conversation, the key takeaways, a clear next step, and a
sign-off — deliberately unformatted so the rep can copy and send it.

- Keep the draft's substance intact: every detail in it came from the
  transcript, so don't paraphrase specifics away or add claims,
  commitments, or deadlines it doesn't contain.
- If the requester wasn't on the call, the agent drafts it as a teammate
  following up on the conversation — that framing is deliberate and
  correct; don't rewrite it into first-person attendance.
- State clearly that nothing has been sent — this is a draft for the rep to
  review, edit, and send themselves.
- Edits ("make it shorter", "move the demo to Thursday") happen in
  conversation on the returned draft — no second tool call unless the user
  wants it re-grounded in a different call.

## Local mode (only when no zime-mcp server is connected)

If the user provides the call transcript, draft from it directly and say so
in one opening line. Reference only things actually in the transcript. No
transcript → ask for one or for the Zime connection rather than inventing a
generic email.

## What this sends where

MCP mode sends only the query words, dates, and (when pinning) a call_id to
the zime-mcp server. Local mode reads only what the user provided. Nothing
is ever emailed by this skill.
