---
name: competitive-intelligence
description: Surfaces what customers actually say about competitors — where a named competitor comes up, what they claim, how we're positioned against them, and which patterns repeat across deals. Use whenever someone asks about competitive dynamics — "where is Competitor X showing up", "what do customers say about them", "how do we position against them", "what objections mention competitors" — even if they never say "competitive intelligence". Scopes to one call via ask_call_brain or across the corpus via ask_zime_brain, resolving with list_meetings when a single call is meant; never fills gaps with general market knowledge about the competitor. Falls back to a user-provided transcript only when no zime-mcp server is available.
license: MIT
metadata:
  zime:category: cross-stage
  zime:dimension: initiative
  zime:input-modes: mcp,transcript
---

# Competitive Intelligence

Answers "what are customers actually saying about Competitor X?" from the
workspace's own calls. The value is that it's evidence from real
conversations, not what the internet says about a competitor — and the two are
often very different.

## The line this skill holds

General market knowledge about a competitor is the failure mode. What their
website claims, their published pricing, their reputation — none of that is
what this skill returns. If the corpus has nothing on a competitor, the answer
is "nothing in our calls mentions them", not a summary from training data.
That distinction is the whole point: a rep can act on "three customers raised
their SSO gap last quarter" and cannot act on "they're generally seen as
cheaper."

## How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                  COMPETITIVE INTELLIGENCE                        │
├─────────────────────────────────────────────────────────────────┤
│  SCOPE FIRST (this skill decides which)                          │
│  ✓ "on the Acme call"    → list_meetings → ask_call_brain              │
│  ✓ "across our deals"    → ask_zime_brain (no resolve needed)          │
├─────────────────────────────────────────────────────────────────┤
│  DELEGATE (Zime agent)                                           │
│  + Agent reads real calls, mentions, and extracted signals       │
│  + Returns evidence with accounts and dates attached             │
├─────────────────────────────────────────────────────────────────┤
│  NEVER                                                           │
│  ✗ Competitor facts from general knowledge                       │
│  ✗ A "typical" objection nobody actually raised                  │
├─────────────────────────────────────────────────────────────────┤
│  LOCAL FALLBACK (no zime-mcp)                                    │
│  ~ Scan a transcript file the user provides                      │
└─────────────────────────────────────────────────────────────────┘
```

## Usage

```
/competitive-intelligence <competitor> [+ scope] [+ when]
```

Competitive intel on: $ARGUMENTS

## Routing

- Objections on ONE deal, competitor or not → `deal-strategy`.
- A recap of one call that happened to mention a competitor → `call-recap`.
- Turning competitive evidence into a battlecard or talking points →
  `create-sales-asset`.
- Win/loss rates and pipeline totals → `pipeline-review`.

## What I Need From You

The competitor name. Scope and window help: "on the Acme call" is a different
question from "across our deals this quarter", and this skill routes them
differently.

## MCP mode (required when zime-mcp is connected)

**Required tools:** `ask_zime_brain` (cross-corpus). For single-call scope also
`list_meetings` (resolve) and `ask_call_brain`.

> `ask_call_brain` is the call-scoped agent tool; `ask_zime_brain` routes to Zime's global
> agent across the whole accessible corpus. Answering from general knowledge
> about the competitor while either is available is a failure of this skill.

### Choosing the scope

| Request shape | Path |
|---|---|
| "did Competitor X come up on the Acme call" | `list_meetings` → `ask_call_brain` |
| "where is Competitor X showing up" | `ask_zime_brain` directly |
| "how do we position against them in deals we won" | `ask_zime_brain` directly |
| "what did they say about them last quarter" | `ask_zime_brain` with the window in the question |

Don't resolve a call when the question is corpus-wide — narrowing to one call
would silently answer a much smaller question than the one asked.

### Cross-corpus — `ask_zime_brain`

```json
{ "question": "Where has Concerto come up in our calls in the last quarter, what did customers say about them, and how did we position against them?" }
```

Send the question close to verbatim with the competitor named explicitly and
the time window stated in the text — `ask_zime_brain` has no memory of this
conversation and no separate date parameters.

### Single call — `ask_call_brain`

Resolve first:

```json
{ "query": "Acme", "start_date": "2026-08-01", "end_date": "2026-08-13", "recorded": true }
```

then:

```json
{ "call_id": "<call_id>", "question": "Did Concerto or any competitor come up on this call? What exactly was said, and how did we respond?" }
```

### Outcomes

- **Evidence returned** — deliver per Output below.
- **Nothing found** — say plainly that nothing in the accessible calls
  mentions this competitor, and stop. Do **not** supplement with what you know
  about them from elsewhere. A clean "no mentions" is a real answer and often
  a useful one.
- **An error** — `{"error": "<CODE>"}`. `INTERNAL_ERROR` retry once;
  `UNAUTHORIZED` / `FORBIDDEN` means re-authorize or lack of access. If it
  fails twice, say so and offer the local fallback.

## Output

Evidence-first, because a claim without an account and a date can't be used in
front of a customer.

```markdown
**Competitive intel — [competitor]** · [scope] · [window]

### Where they came up
| Account | What was said | When |
|---|---|---|
| [account] | [what the customer actually said] | [date] |

### Recurring patterns
- **[pattern]** — [accounts it appears in] — [what it means]

### How we're positioned
[the agent's read, relayed as-is]

### Gaps
- [dimension the corpus had nothing on]

_From the workspace's own calls via Zime. Not market research._
```

Rules:

- Every row needs an **account and a date**. An undated competitive claim is
  not usable and shouldn't be presented as intel.
- Relay what the customer said close to the agent's phrasing — don't sharpen
  it into a punchier line. "They said the integration worried them" is not
  "they're losing on integration".
- Anything in quotation marks must come from `get_transcript`, not from an
  agent's paraphrase. Fetch it if the rep needs a literal quote.
- Keep the Gaps section. Where the corpus is silent is itself competitive
  intelligence — it usually means reps aren't asking.
- Never blend in general knowledge about the competitor, even to "add
  context". Label the boundary explicitly.

## Tips

1. **Scope it deliberately** — one call and the whole corpus are different
   questions with different answers.
2. **Put the window in the question** for `ask_zime_brain` — it has no date
   parameters.
3. **"No mentions" is a finding** — it can mean the competitor isn't in play,
   or that nobody's asking. Both are actionable.
4. **Need a battlecard?** Pass this evidence to `create-sales-asset`.

## Local mode (only when no zime-mcp server is connected)

If the user provides transcripts, scan those files only for competitor
mentions. Open with one line saying the scan covers just the provided files,
so this is not a corpus-wide view. Same rule: no general knowledge about the
competitor, only what the files contain.

## What this sends where

MCP mode sends the question text (to `ask_zime_brain`), or query words and dates
plus a `call_id` and question (to `list_meetings` / `ask_call_brain`). Local mode
reads only the provided files.

## Related Skills

- **create-sales-asset** — turn this evidence into a battlecard
- **deal-strategy** — competitor dynamics on one specific deal
- **get-transcript** — the exact quotable line
