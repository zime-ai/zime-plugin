---
name: follow-up
description: Drafts the follow-up email after ONE past call — recapping what was agreed and stating the next step, grounded in what was actually said. Use whenever someone wants the post-call email — "draft a follow-up for my Acme call", "write the recap email to Northwind", "send Concerto a note after yesterday's demo" — even if they never say "follow-up". Resolves the call with list_meetings, then delegates drafting to the Zime call agent via ask_call_brain; never invents a commitment, a number, or a next step the call didn't contain. Always presented as a draft for the rep to review before sending. Falls back to drafting from a user-provided transcript only when no zime-mcp server is available.
license: MIT
metadata:
  zime:category: cross-stage
  zime:dimension: initiative
  zime:input-modes: mcp,transcript
---

# Follow-up

Turns "draft a follow-up for my Acme call" into a sendable email. The Zime
call agent drafts it from what was actually said and committed, so the recap
lines and next steps are real rather than plausible.

## How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                          FOLLOW-UP                               │
├─────────────────────────────────────────────────────────────────┤
│  STEP 1 — RESOLVE (this skill)                                   │
│  ✓ list_meetings, recorded calls only                            │
│  ✓ Ambiguous → show candidates, ask, pin call_id                 │
├─────────────────────────────────────────────────────────────────┤
│  STEP 2 — DELEGATE (Zime call agent)                             │
│  + ask_call_brain drafts from real commitments and next steps          │
│  + Returns the draft; this skill formats and captions it         │
├─────────────────────────────────────────────────────────────────┤
│  ALWAYS                                                          │
│  ! Delivered as a DRAFT — the rep sends it, not this skill       │
├─────────────────────────────────────────────────────────────────┤
│  LOCAL FALLBACK (no zime-mcp)                                    │
│  ~ Draft from a transcript file the user provides                │
└─────────────────────────────────────────────────────────────────┘
```

## Usage

```
/follow-up <company or call> [+ when]
```

Draft the follow-up for: $ARGUMENTS

## Routing

- A structured internal summary rather than a customer email → `call-recap`.
- Just the open items and owners → `actions-commitments`.
- Prep for the NEXT call → `call-prep`.
- Reading past correspondence rather than writing → `get-email`.

## What I Need From You

Which call. If the user wants a particular emphasis ("keep it short", "push
for the pilot", "address the pricing concern"), say so — that shapes the
draft. Only recorded calls can be drafted from.

## MCP mode (required when zime-mcp is connected)

**Required tools:** `list_meetings` (resolve) and `ask_call_brain` (draft).

> `ask_call_brain` is the call-scoped agent tool — a `call_id` plus a question,
> routed to Zime's call agent. Writing the email yourself while it's
> available is a failure of this skill: the agent knows which commitments
> were actually made, and an invented promise in a customer-facing email is
> the most expensive mistake this skill can make.

### Step 1 — resolve the call

```json
{ "query": "Acme", "start_date": "2026-08-06", "end_date": "2026-08-13", "recorded": true }
```

`multiple_matches` → show candidates with dates, ask, pin. `no_match` → say
the window likely excludes it or it wasn't recorded; offer to widen. Never
draft from a different call.

### Step 2 — delegate the draft

```json
{ "call_id": "<call_id>", "question": "Draft a follow-up email to the customer for this call: recap what was discussed, restate the commitments we made, and propose the agreed next step with timing." }
```

Add the user's emphasis to the question verbatim if they gave one. Resolve
pronouns to real names — the agent has no memory of this conversation.

### Outcomes

- **A draft** — deliver per Output below.
- **The agent has nothing** (e.g. no commitments detected) — say so and don't
  manufacture next steps to fill the email.
- **An error** — `{"error": "<CODE>"}`. `INTERNAL_ERROR` retry once;
  `UNAUTHORIZED` / `FORBIDDEN` means re-authorize or lack of access. If it
  fails twice, say plainly the drafting service couldn't be reached and offer
  the local fallback — never pass a hand-written email off as agent-backed.

## Output

Two parts: a one-line provenance caption, then the email in plain text.

```markdown
**Draft follow-up — [call title]** · [date] · to [recipients]
_Review before sending. Every commitment below came from the call itself._

---

Subject: [subject line]

Hi [name],

[recap of what was discussed]

[commitments made, restated plainly]

[the agreed next step, with timing]

Best,
[rep name]
```

### Email style rules

The body is going into an email client, so:

1. **No markdown formatting.** No asterisks, no bold, no headers. Plain text
   that reads naturally anywhere.
2. **Short paragraphs**, blank line between sections.
3. **Plain dashes** for lists, not bullets or fancy formatting.
4. **Concise but complete** — customers are busy; don't pad.

**Good:**
```
Here's what we agreed:
- Quote for 20 seats by Friday
- Security review doc from your side
- Follow-up call the week of the 25th
```

**Bad:**
```
**What We Agreed:**
- **Quote** for 20 seats by Friday
```

### Grounding rules

- Every commitment, number, date, and name in the draft must have come from
  the agent's output. If the agent didn't return it, it doesn't go in the
  email — a plausible-sounding promise to a customer is worse than an
  incomplete draft.
- If a needed piece is missing (e.g. no date was agreed), leave a visible
  `[confirm timing]` placeholder rather than inventing one.
- Never state a discount, price, or contractual term the call didn't contain.
- Always caption it as a draft. This skill does not send email.

## Tips

1. **Say the emphasis you want** — "short and push for the pilot" changes the
   draft meaningfully.
2. **Placeholders are a feature** — `[confirm timing]` beats a made-up date.
3. **Read before you send** — the draft is grounded, not proofread for tone
   against your relationship with this customer.

## Local mode (only when no zime-mcp server is connected)

If the user provides a transcript, draft from that file only, with the same
grounding rules and the same draft caption. Open with one line saying the
draft covers only the provided transcript.

## What this sends where

MCP mode sends the query words and date range (to `list_meetings`), then a
`call_id` and the drafting question (to `ask_call_brain`). Local mode reads only the
provided file. Neither mode sends email.

## Related Skills

- **call-recap** — the internal summary version
- **actions-commitments** — what's still open across calls
- **get-email** — what's already been said over email
