---
name: sales-asset-builder
description: Builds rep-facing sales collateral for one deal — ROI proof points, a case-study-style writeup of how a named customer uses the product, a battlecard section against a competitor, or talking points for an objection — assembled only from facts a tool returned this conversation. Use whenever someone wants a draft asset built from real customer evidence — "build me a proof point for the Acme deal", "give me a mini case study of how Northwind uses us", "put together a battlecard section against Competitor X", "give me talking points for the security objection" — even if they never say "asset". Always calls ask_zime (plus get_transcript for an exact quote, get_account/get_deal for hard facts) on zime-mcp when connected — never hand-builds a stat, quote, or outcome from memory — and every claim must trace to a tool result from this conversation. Falls back to a narrower asset from user-provided transcripts or a CRM export only when no zime-mcp server is available.
license: MIT
metadata:
  zime:category: cross-stage
  zime:dimension: initiative
  zime:input-modes: mcp,csv,transcript
---

# Sales Asset Builder

Turns "build me a proof point for the Acme deal" or "give me talking points
for the security objection" into a rep-usable draft — arranged and framed by
this skill, but every fact in it comes from a tool call in this
conversation. This skill never originates a metric, a quote, or a "customer
said" line; it only assembles what the tools actually returned.

## The hard rule

Every factual claim in the built asset — a metric, a quoted line, a stated
customer outcome, a competitive win — must trace to something a tool
returned in THIS conversation. If a needed fact wasn't returned by a tool,
the asset says the gap is open rather than filling it with a plausible
number or a paraphrased "customers typically say" line. This is the one rule
this skill cannot bend: arranging and framing real tool output is the job;
inventing supporting evidence is a failure of it, even when the invented
line looks exactly like something a customer would say.

## Routing

- A plain pipeline stat with no asset to build ("what's our win rate this
  quarter") → `pipeline-review`.
- Objections, risk, or strategy for ONE specific deal, with no asset to
  build → `deal-strategy`.
- A straight recap of one call, or the follow-up email after it, not an
  asset for reuse → `call-recap` / `follow-up`.
- A single exact quote once the call is already identified → call
  `get_transcript` directly (or `get-meeting` first if the call isn't known
  yet); see MCP mode below.
- One CRM fact alone (industry, deal size, close date) with no asset
  requested → `get-account` / `get-deal`.

## MCP mode (required when zime-mcp is connected)

Hand-building a proof point, case-study line, or battlecard claim from
memory or general product knowledge while these tools are available is a
failure of this skill — only the tools see the workspace's real calls, CRM
records, and extracted signals.

### ask_zime — primary tool for synthesis

When a zime-mcp server exposes `ask_zime` (fully qualified: `Zime:ask_zime`;
some clients surface it as `mcp__claude_ai_Zime__ask_zime`), use it for any
cross-call or cross-deal synthesis the asset needs: outcomes a named
customer has reported, recurring proof points, how the team positions
against a named competitor in won deals, or the strength of an argument
across many calls. Send the question close to verbatim, with pronouns
resolved to the actual account, deal, or competitor name — `ask_zime` has no
memory of earlier turns in this conversation.

**Example** — "what outcomes has Acme reported since going live?":

```json
{ "question": "What outcomes has Acme reported since going live?" }
```

**Example** — "how do we position against Concerto's competitor in deals we've won?":

```json
{ "question": "How are we positioning against Northwind in deals we've won?" }
```

`ask_zime` enforces access control server-side and answers in prose; there
is no separate candidate/pin flow to manage. If it declines or has nothing
on the topic, say so plainly and build the asset only from what it did
return — don't fill the gap yourself.

### get_transcript — for one exact, citable quote

Once a specific call is identified (already known, or resolved first via
`get-meeting`/`get_call`), call `get_transcript` to pull an exact line
verbatim instead of quoting `ask_zime`'s paraphrase. Use this whenever the
asset needs something the rep can literally put in quotation marks.

```json
{ "query": "Acme renewal", "start_date": "2026-05-01", "end_date": "2026-05-31" }
```

Same three-shape contract as `get-meeting`/`get-transcript`'s own skill:
`{"status": "resolved", "data": {...}}` with the transcript, or
`multiple_matches`/`no_match` with up to 5 `candidates` — show them and
re-call with the chosen `call_id`, never guess. Errors arrive as
`{"error": "<CODE>"}`; `UNAUTHORIZED`/`FORBIDDEN` mean re-authorize or lack
of access, `INTERNAL_ERROR` is usually transient (retry once).

### get_account / get_deal — for hard grounding facts

When the asset needs a hard fact (industry, deal size, close date) rather
than a synthesized claim, call `get_account`/`get_deal` directly.

```json
{ "query": "Acme" }
```

Same contract as their own skills (`get-account`, `get-deal`):
`resolved`/`multiple_matches`/`no_match`, with the same error codes as
above. Never substitute a remembered or guessed figure for one of these
calls.

## Output

Assemble the asset from tool output only, shaped to what was asked for
(proof points, a case-study-style writeup, a battlecard section, objection
talking points):

- Every metric, quote, and outcome in the asset must be attributable to a
  specific tool call made in this conversation — when relaying a claim from
  `ask_zime`, keep it close to how the tool phrased it rather than
  sharpening or rounding it into a punchier line.
- An exact quote presented in quotation marks must have come from
  `get_transcript`, not from paraphrasing `ask_zime`'s synthesis.
- If a section of the requested asset has no supporting tool output, say so
  in that section ("no proof point returned for this claim") instead of
  omitting the gap or writing around it.
- State plainly, every time this skill delivers an asset: **this is an
  internal draft for the rep's own use, not customer-facing collateral
  cleared by marketing or legal.** Calls may contain confidential customer
  language, so anything built here needs review before it leaves the
  building — before it goes to a prospect, gets pasted into a deck sent
  externally, or gets published anywhere.

## Local mode (only when no zime-mcp server is connected)

If the user provides call transcripts or a CRM export, build a narrower
asset from those files only — same rule: every claim traces to a quote or
field in the provided files, nothing filled in from general knowledge. Open
with one line saying the asset covers only the provided files, not the full
account or deal history, and repeat the internal-draft caveat above.

## What this sends where

MCP mode sends only the question text (to `ask_zime`), or query words,
dates, and (when pinning) a call_id/account_id/deal_id (to `get_transcript`,
`get_account`, `get_deal`) to the zime-mcp server. Local mode reads only the
files the user provided.
