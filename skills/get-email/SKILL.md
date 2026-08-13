---
name: get-email
description: Intended to look up ONE email associated with a deal or contact — sender, recipients, subject, body, thread. NOT YET BACKED BY A TOOL — the zime-mcp connector has no get_email (or equivalent) tool as of this writing. This skill exists so the plugin has a stable place to route email-lookup intents to; until the connector ships the tool, it always states the capability is unavailable rather than guessing at an email's contents from memory, a related transcript, or any other source. Use this skill (to fail honestly) whenever someone asks to look up, find, or quote a specific email — "what did we email Acme about pricing", "find the email where they confirmed the demo time" — even though today it can only decline.
license: MIT
metadata:
  zime:category: cross-stage
  zime:dimension: initiative
  zime:input-modes: mcp
  zime:status: blocked-no-tool
---

# Get Email

**Status: blocked.** There is no `get_email` (or equivalent) tool on the
zime-mcp connector yet. This skill is a placeholder with one job: when
someone asks to look up a specific email, say plainly that Zime doesn't
expose email lookup yet, instead of inventing or paraphrasing an email from
a transcript, a CRM note, or memory. Remove this "Status" section and write
a real MCP mode the day the tool ships — see `AGENTS.md` for the frontmatter
contract this repo expects real tool-coupled skills to follow (routing,
Arguments, Outcomes, Output, Local mode, What this sends where).

## Routing

- What was actually said on a CALL (not an email) → `get-transcript` or
  `call-recap`.
- Drafting a NEW follow-up email grounded in a call → `follow-up`. That
  tool (`draft_follow_up_email`) writes an email; it does not look up ones
  already sent.
- General account or deal context that might reference email activity →
  `ask_zime` — it may have visibility into email-derived signals even
  though this skill doesn't have a dedicated lookup tool for the raw
  message.

## Current behavior (no MCP mode, no local mode)

Every request this skill receives — connected or not — gets the same
honest answer: Zime's MCP connector doesn't currently expose a tool to look
up a specific email's contents, so this skill can't retrieve, quote, or
reconstruct one. Suggest `ask_zime` for anything the general agent might
still know (e.g. an email-derived commitment surfaced on a call), and
`follow-up` if the actual goal is drafting a new email rather than finding
an old one.

Never substitute a plausible-sounding email body assembled from a related
transcript or CRM note and present it as the email that was sent — that
would be presenting an invention as a retrieved record, exactly the
failure mode every other skill in this repo is built to avoid.

## What this sends where

Nothing — this skill never calls a tool or reads a file; it only responds
in conversation.
