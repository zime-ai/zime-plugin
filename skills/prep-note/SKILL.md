---
name: prep-note
description: Generates a focused, tactical prep note for one upcoming (scheduled, future) customer call the rep is about to have — the single biggest risk or win condition, the rep's top 2-3 concrete moves, and links back into Zime. Use whenever someone wants to get ready for a specific upcoming meeting — "prep me for my Meridian call tomorrow", "help me get ready for the Concerto demo", "brief me before my 3pm" — even if they never say "prep note". Always calls the prep_note tool on the zime-mcp server when connected — never hand-builds the note in its place — and handles its disambiguation flow (candidate meeting lists, pinning a calendar_event_id). Falls back to assembling a note locally from a meeting-context file plus past-call transcripts or a CRM export only when no zime-mcp server is available.
license: MIT
metadata:
  zime:category: cross-stage
  zime:dimension: initiative
  zime:input-modes: mcp,meeting-context,transcript,csv
---

# Pre-Call Prep Note

Gets a rep up to speed before a customer call. Zime generates the note from
the meeting's CRM deal and account, its external attendees, and the
relevant past calls — context no chat history can match. This skill's job
is to reach that generator correctly and deliver the note it returns.

## Routing

- Anything about PAST calls (recaps, "what objections came up") →
  `call-recap` or `ask_zime`.
- General deal or coaching questions not tied to preparing for one specific
  upcoming call ("how do I win this deal") → `ask_zime`.
- "What meetings do I have?" is a calendar listing, not preparing for one →
  `ask_zime`.
- Use this skill only when there is an upcoming, scheduled call AND the
  user wants to prepare for it.

## MCP mode (required when zime-mcp is connected)

When a zime-mcp server exposes `prep_note` (fully qualified:
`Zime:prep_note`; some clients surface it as
`mcp__claude_ai_Zime__prep_note`), route the note through it. Hand-building
the note from general knowledge while the tool is available is a failure of
this skill, even when the user gave you enough context to write something
plausible — the tool grounds every claim in the workspace's real calls and
CRM.

### Arguments

- `query` (required) — the user's request, minimally rewritten. Keep the
  company or person named AND any time hint. Unlike the other Zime skills,
  time words BELONG in this query: the tool matches against the rep's own
  upcoming calendar meetings and parses "today", "tomorrow", "this week",
  "next week", and weekday names itself to narrow the meeting first, then
  matches the remaining words against attendee company domains, meeting
  titles, and attendee names. Do not invent a company or time that was not
  said.
- `calendar_event_id` — only on a follow-up call, after the tool returned a
  candidate list and the user picked a meeting (you may keep the same
  query). Never invent one.

**Example** — "prep me for my Meridian call tomorrow":

```json
{ "query": "prep me for my Meridian call tomorrow" }
```

### Outcomes

- **A prep note** (markdown) — deliver it per Output below. If the same
  meeting was prepped recently, Zime returns the stored note quickly
  instead of regenerating — that reuse is by design, not staleness.
- **A candidate list** — a numbered text list of the rep's upcoming
  meetings (up to 10), each line carrying its title, time (UTC), attendee
  domains, and `calendar_event_id`. Show it, ask which meeting the user
  means, then re-call with that `calendar_event_id`. If a pinned id comes
  back rejected ("that meeting isn't in your upcoming calls"), the id was
  stale or not the rep's own meeting — pick again from the fresh list the
  tool re-offers.
- **"You have no upcoming external meetings"** — nothing to prep; tell the
  user plainly.
- **"Prep notes aren't configured for your workspace yet"** — generation
  needs workspace setup; tell the user to ask their Zime admin.
- **"A prep note for this call is already being generated"** — another
  request is mid-generation; wait a few seconds and call again once.
- **An error** — `{"error": "<CODE>"}`. `INTERNAL_ERROR` is usually
  transient: retry once. `UNAUTHORIZED` means the Zime connection needs
  re-authorizing — say so. If it still fails, say plainly the prep-note
  service couldn't be reached and offer the local fallback — never silently
  substitute a hand-written note and present it as tool-backed.

Note: the tool can only prep the rep's OWN meetings (where they are an
attendee or the organizer). If the user asks to prep someone else's call,
say that directly instead of retrying.

## Output

The returned note is already the deliverable — a short brief with the
single biggest risk or win condition, the rep's top 2-3 numbered moves, and
links back into Zime:

- Relay the markdown as returned. Every claim in it traces to the
  workspace's calls and CRM, so don't rewrite, re-rank, summarize, or
  supplement it from other tools or memory.
- Keep every link it returns; an item without a link is presented without
  one — silently, never with a "link unavailable" note.

## Local mode (only when no zime-mcp server is connected)

Build the note from files the user provides — a meeting-context block or
pasted calendar invite, optional past-call transcripts (`.txt`, `.vtt`,
`.json`, `.md`), and an optional CRM export (`.csv`). Follow
[references/prep-note-format.md](references/prep-note-format.md) exactly:
seven sections, skimmable in a minute, every claim sourced, gaps marked as
gaps ("No prior calls provided — ask the rep what's already been
discussed") instead of plausible filler. Open with one line saying the note
was built from provided files only, without live workspace data.

Sample inputs to try first: `assets/sample-meeting-context.txt` (synthetic
meeting-context block) and `assets/sample-past-call.txt` (synthetic prior
call with the same account).

## What this sends where

MCP mode sends only the user's request wording (and, when pinning, a
calendar_event_id) to the zime-mcp server, which looks up calls and CRM
data the workspace already holds. Local mode reads only the files the user
points it at — nothing leaves the machine.
