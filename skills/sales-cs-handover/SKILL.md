---
name: sales-cs-handover
description: Fills the Sales-to-CS handover document for one deal or account — stakeholders and motivations, why we won, objections still live, commitments made, call history, and marching orders for CS. Use whenever someone is handing an account over — "build the CS handover for Acme", "prep the handover doc for Northwind", "what does CS need to know about Concerto" — even if they never say "handover". Resolves the deal or account with list_deals / list_accounts, gathers evidence via ask_deal_brain / ask_account_brain and list_meetings, then fills the template; fields only the rep knows are left as explicit TO-FILL prompts rather than guessed, because an invented client sensitivity is worse than a blank one. Falls back to a narrower draft from user-provided files only when no zime-mcp server is available.
license: MIT
metadata:
  zime:category: post-sale
  zime:dimension: initiative
  zime:input-modes: mcp,transcript,csv
---

# Sales → CS Handover

Fills the handover document CS uses to accept an account. Two kinds of field
live in it, and the difference is the whole skill:

1. **Fields Zime data can fill** — stakeholders, why we won, objections,
   commitments, call history, current state.
2. **Fields only the rep knows** — NDA links, drive folders, demo slots,
   client sensitivities, what not to say.

Category 2 is left as an explicit `[SALES TO FILL]` prompt. Never guessed.

## Why guessing is worse than blank here

CS accepts or rejects a handover based on this document. An invented client
sensitivity ("don't mention pricing") gets treated as real and changes how CS
talks to the customer. A blank field gets chased and filled. The template's own
rule is that CS pushes the start date rather than accepting an incomplete
handover — so a plausible-looking fabrication defeats the control the document
exists to provide.

## How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                   SALES → CS HANDOVER                            │
├─────────────────────────────────────────────────────────────────┤
│  STEP 1 — RESOLVE                                                │
│  ✓ list_deals (deal handover) or list_accounts (account)         │
├─────────────────────────────────────────────────────────────────┤
│  STEP 2 — GATHER                                                 │
│  + ask_deal_brain / ask_account_brain — why we won, objections, commitments  │
│  + list_meetings — call history, cadence, last engagement        │
├─────────────────────────────────────────────────────────────────┤
│  STEP 3 — FILL, DON'T GUESS                                      │
│  ✓ Zime-backed fields filled with evidence + dates               │
│  ! Rep-only fields left as [SALES TO FILL]                       │
│  ✓ Open gaps listed at the top so CS sees them first             │
├─────────────────────────────────────────────────────────────────┤
│  LOCAL FALLBACK (no zime-mcp)                                    │
│  ~ Narrower draft from provided transcripts or CRM export        │
└─────────────────────────────────────────────────────────────────┘
```

## Usage

```
/sales-cs-handover <deal or account name>
```

Build the handover for: $ARGUMENTS

## Routing

- Deal strategy while still selling → `deal-strategy`.
- Just the open commitments → `actions-commitments`.
- An account review deck for a QBR → `sales-asset-builder`.
- The account's CRM record alone → `get-account`.

## What I Need From You

The deal or account name. Also useful, and otherwise left blank:

- Who's handing over, and to whom
- Anything sensitive CS must not say or do
- Links (drive folder, NDA, charter) if you have them

Anything not supplied comes back as a `[SALES TO FILL]` prompt — that's the
design, not a shortfall.

## MCP mode (required when zime-mcp is connected)

**Required tools:** `list_deals` / `list_accounts` (resolve), `ask_deal_brain` /
`ask_account_brain` (evidence), `list_meetings` (call history).

### Step 1 — resolve

```json
{ "query": "Acme" }
```

`multiple_matches` → show candidates, ask, pin. A handover written about the
wrong account is worse than none.

### Step 2 — gather, asking for dates and names

```json
{ "deal_id": "<deal_id>", "question": "For this deal: who are the stakeholders and what does each one care about, why did we win, what objections or blockers are still live, and what did we commit to delivering? Give the evidence, the speaker, and the date for each." }
```

Call history:

```json
{ "query": "Acme", "start_date": "2026-02-01", "end_date": "2026-08-13" }
```

Ask for speaker and date explicitly — a stakeholder motivation with no source
can't be validated by CS.

### Outcomes

Usual shapes — `resolved` / `multiple_matches` / `no_match`, or
`{"error": "<CODE>"}` (`INTERNAL_ERROR` retry once; `UNAUTHORIZED` /
`FORBIDDEN` means re-authorize or lack of access). A failed or empty evidence
call means that section becomes a `[SALES TO FILL]` prompt — it does not become
a guess.

## Output

Follow [references/handover-template.md](references/handover-template.md) for
the full field list. Structure:

```markdown
# Sales → CS Handover: [Account]
_Drafted from Zime call and CRM data on [date]. Sections marked
[SALES TO FILL] need the rep before CS can accept._

## Open gaps — blocking acceptance
- [ ] [field] — [SALES TO FILL]

## 1. Deal and commercial status
| Field | Value | Source |
|---|---|---|
| Deal | [name] · [stage] · [amount] | CRM |
| Close date | [date] | CRM |
| NDA / charter links | [SALES TO FILL] | — |

## 2. Client context
[what they do, team shape, tooling — evidence + date, or SALES TO FILL]

## 3. Stakeholders
| Name | Title | Role | What they care about | Source |
|---|---|---|---|---|
| [name] | [title] | [champion / DM / economic buyer] | [motivation] | [call, date] |

## 4. Why we won
- **[hook]** — [evidence] — [speaker, date]

## 5. Objections and blockers still live
| Objection | Raised by | Date | Status |
|---|---|---|---|

## 6. Commitments made
| Commitment | Owner | Due | Source |
|---|---|---|---|

## 7. Call history
| Date | Meeting | Type | Attendees |
|---|---|---|---|

**Last engagement:** [date] · **Cadence:** [observed pattern]

## 8. Marching orders for CS
[first actions, from what the calls indicate]

## 9. What NOT to do — client sensitivities
[SALES TO FILL] — not inferable from call data

## 10. Open questions for CS to chase
- [unresolved item] — [source]
```

### Rules

- **`[SALES TO FILL]` is mandatory** for: NDA and charter links, drive folder,
  demo/kickoff slots, client sensitivities, what-not-to-say, post-POC
  commercial terms. Never infer these — none are reliably in call data.
- **Every Zime-filled row carries a source** (call + date). CS validates the
  handover; unsourced claims can't be validated.
- **Lead with Open gaps.** CS reads that first and knows immediately whether
  this handover is acceptable.
- **A stakeholder needs a real source.** No inferring a champion from who
  talked most.
- **Never invent an owner or a due date** on a commitment. "not stated" is
  correct.
- If the account has almost no call history, say so plainly at the top — a
  thin handover honestly labelled is useful; a padded one is not.

## Tips

1. **Supply the links up front** — they're the most common blockers to
   acceptance.
2. **Sensitivities are yours to write** — the calls rarely contain them and
   guessing them is the most dangerous fabrication in this document.
3. **Widen the call-history window** — handovers want the whole relationship,
   not the last 90 days.
4. **Chase the gaps with `actions-commitments`** before handing over.

## Local mode (only when no zime-mcp server is connected)

If the user provides transcripts or a CRM export, draft from those files only.
Open with one line saying the draft covers only the provided files, so
stakeholder motivations and objections from other calls are missing by
construction. Expand `[SALES TO FILL]` to cover everything the files don't
carry.

## What this sends where

MCP mode sends query words (to `list_deals`/`list_accounts`), an id plus the
evidence question (to `ask_deal_brain`/`ask_account_brain`), and query words plus dates (to
`list_meetings`). Local mode reads only the provided files.

## Related Skills

- **actions-commitments** — close the gaps before handing over
- **deal-strategy** — the pre-handover view of the same deal
- **sales-asset-builder** — the account review deck CS will run later
