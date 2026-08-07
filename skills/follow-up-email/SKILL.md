---
name: follow-up-email
description: Drafts the follow-up email to the prospect after one recorded sales call, grounded in what was actually discussed on that call. Always calls the draft_follow_up_email tool on the zime-mcp server when connected — never hand-writes the email in its place — and handles the tool's disambiguation flow (candidate lists, pinning a call_id). Nothing is ever sent; the deliverable is a draft. Falls back to drafting from a user-provided transcript only when no zime-mcp server is available. Use when a rep asks for the follow-up email after a call.
license: MIT
metadata:
  zime:category: cross-stage
  zime:dimension: initiative
  zime:input-modes: mcp,transcript
---

# Follow-up Email

Drafts the post-call email a rep sends the prospect. The draft is written
by Zime's call AI agent from the full transcript and call insights — this
skill reaches that agent correctly, renders the draft, and never sends
anything.

## When to use this

- A rep just finished a call and wants the follow-up email drafted.
- A stale deal needs a re-engagement email grounded in the last call.

Not for: emails not tied to one recorded call (cold outreach, check-ins
with no call behind them → draft normally or use `ask_zime` for account
context), or recaps (→ `generate_call_recap`).

## MCP mode (REQUIRED when zime-mcp is connected)

**Tool-first, not tool-optional.** If a zime-mcp server exposes
`draft_follow_up_email` (via the claude.ai connector:
`mcp__claude_ai_Zime__draft_follow_up_email`), you MUST route the draft
through it — it writes from the actual transcript, so it can reference
what was really said. Hand-writing the email from chat context while the
tool is available is a failure of this skill.

Arguments — two-phase contract, same as the other call-scoped tools:

1. **`query`** — words identifying the call: company, attendee, or topic.
   **No time words in the query** — convert "this morning" / "yesterday" /
   "last week" into `start_date` / `end_date` (YYYY-MM-DD). Default
   window is the user's own recorded calls, last 90 days.
2. **`call_id`** — only to pin: after a candidate list (pass the chosen
   `call_id`), or when the ID is already known from this conversation.

Handle each outcome:

- **A draft** — present it (see Output below).
- **Candidates (`multiple_matches` / `no_match`)** — newest-first. Show
  them and ask which call — EXCEPT "latest" / "most recent" requests:
  pick the first candidate and re-call with its `call_id` without asking.
- **An error code** — retry once; then say plainly the drafting service
  couldn't be reached (`UNAUTHORIZED` → the Zime connection needs
  re-authorizing). Never silently hand-write a draft and present it as
  grounded in the transcript.

## Local mode (fallback, ONLY when no zime-mcp server is connected)

If the user provides the call transcript, draft from it directly and say
so in one opening line. Reference only things actually in the transcript
— names, numbers, commitments. No transcript → ask for one or for the
Zime connection rather than inventing a generic email.

## Output

Present the tool's draft as the deliverable. Light touch:

- Keep the draft's substance intact — every referenced detail came from
  the transcript, so don't paraphrase specifics away or add claims,
  commitments, or deadlines the draft doesn't contain.
- Formatting for a 10-second scan is fine (subject line visible, short
  paragraphs), as is fixing an obvious salutation/sign-off gap.
- State clearly that nothing has been sent — this is a draft for the rep
  to review, edit, and send themselves.
- If the user then asks for edits ("make it shorter", "push the demo to
  Thursday"), edit the draft in conversation — no second tool call needed
  unless they want it re-grounded in a different call.

## What this sends where

MCP mode sends only the query words, dates, and (when pinning) a call_id
to the zime-mcp server. Local mode reads only what the user provided.
Nothing is ever emailed by this skill.
