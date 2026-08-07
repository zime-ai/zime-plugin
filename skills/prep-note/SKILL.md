---
name: prep-note
description: Builds a pre-call prep note for an upcoming customer meeting — meeting snapshot, deal state, who's who, prior-call history, likely objections, and clear objectives for the call. Always calls the prep-note tool on the zime-mcp server when that server is connected — never hand-builds the note in its place — and only falls back to assembling the note locally from a meeting-context file plus past-call transcripts or a CRM export when no zime-mcp server is available. Use before any customer-facing call — discovery, demo, negotiation, QBR, or renewal.
license: MIT
metadata:
  zime:category: cross-stage
  zime:dimension: initiative
  zime:input-modes: meeting-context,transcript,csv,mcp
---

# Pre-Call Prep Note

Gets a rep up to speed before a customer call: one skimmable note covering
what the meeting is, where the deal stands, who's in the room, what happened
on prior calls, and what this call needs to achieve.

Unlike the audit skills in this repo, this one is *generative* — it produces
a forward-looking note, not a scored rubric. The same trust bar still
applies: **every factual claim in the note traces to a source** (tool
output, a provided transcript, a CRM field). Anything the sources don't
support is marked as a gap, never guessed.

## When to use this

- A rep has a customer call in the next few hours and wants a 60-second
  brief instead of re-reading old notes.
- A solutions engineer or leader is joining a deal mid-stream and needs
  context fast.
- A CSM is walking into a QBR or renewal conversation and wants prior
  commitments and open issues in one place.

## Modes

### MCP mode (REQUIRED when zime-mcp is connected)

**This skill is tool-first, not tool-optional.** Before doing anything
else, check whether a `zime-mcp` server is connected and exposes a
`prep-note` tool (search the available tools if it isn't already loaded).
If it is, you MUST route the note through it — it has live access to the
workspace's calls, deals, and accounts that no local file can match.
Hand-building the note from general knowledge while the tool is available
is a failure of this skill, even if the user gave you enough context to
write something plausible.

1. Gather the meeting context from whatever the user gives you: a pasted
   calendar invite, a deal or account name, attendee emails, or a
   meeting-context block (see field reference below).
2. Call the `prep-note` tool with that context — depending on the client
   it may be exposed as `prep-note` or `prep_note` (e.g.
   `mcp__claude_ai_Zime__prep_note` via the claude.ai connector); treat
   either as the same tool. Pass the fields you have; do not fabricate
   values for fields you don't.
3. Render the tool's result in the output format from
   `references/prep-note-format.md`. The tool's output is the source of
   truth — do not add claims it doesn't support, and do not drop deal or
   call facts it returned. Keep every recording or document link it
   returns; if an item has no link, present it without one — silently,
   never with a "link unavailable" note.
4. If the tool call errors, retry once; if it still fails, say plainly
   that the live prep-note service couldn't be reached and offer the
   local fallback below — never silently substitute a hand-written note
   and present it as tool-backed.

### Local mode (fallback, ONLY when no zime-mcp server is connected)

Use this mode only when no zime-mcp server is available in the session.
When you use it, open the note with one line saying it was built from
provided files only, without live workspace data, and that connecting the
zime-mcp server gives a richer note.

No network calls, no credentials — build the note from files the user
provides, same guarantee as every other skill in this repo:

- **Meeting context** — a text block or pasted calendar invite: title,
  date/time, attendees, account/deal name.
- **Past-call transcripts** (`.txt`, `.vtt`, `.json`, `.md`) — optional,
  one or more prior calls with this account.
- **CRM export** (`.csv`) — optional, the deal/account row(s).

```
claude "run prep-note on ./meetings/northwind-demo-context.txt with ./calls/northwind-discovery.txt"
```

Build each section of the note only from what those files contain. A
section with no supporting data gets a one-line gap marker (for example,
"No prior calls provided — ask the rep what's already been discussed")
instead of plausible-sounding filler.

## Meeting-context fields

These are the fields the `prep-note` tool accepts and the local mode reads.
All are optional except a meeting title or deal/account name — pass what
you have:

| Field | Meaning |
|---|---|
| `CONTEXT_LEVEL` | `deal` or `account` — what the note anchors on |
| `ACCOUNT_NAME` / `ACCOUNT_ID` | the customer account |
| `DEAL_NAME` / `DEAL_ID` | the specific opportunity |
| `DEAL_STAGE` | current CRM stage |
| `DEAL_OWNER` | rep who owns the deal |
| `EXTERNAL_ATTENDEES` | customer-side attendee emails |
| `ATTENDEE_DOMAIN` | attendee company domains — flags multi-party calls |
| `INTERNAL_ATTENDEE_FUNCTIONS` | who's joining from your side (roles) |
| `MEETING_TITLE` | the calendar title |
| `DATE_TIME` | when the meeting happens (note timezone) |
| `PAST_CALLS` | prior calls: id, date, title, attendee-overlap tag |

`assets/sample-meeting-context.txt` is a synthetic example of this block.

## Output

Follow `references/prep-note-format.md` exactly. In short: seven sections —
meeting snapshot, deal state, who's who, what happened before, likely pains
and objections, goals for this call, landmines — skimmable in about a
minute, bold on headings only, every claim sourced, gaps marked as gaps.

## Sample data

- `assets/sample-meeting-context.txt` — synthetic meeting-context block.
- `assets/sample-past-call.txt` — short synthetic prior call with the same
  account, so local mode has history to draw on.

Run the skill against both first to see real output before pointing it at
your own meeting.

## What this sends where

- **Local mode:** nothing leaves your machine. It reads the files you point
  it at and nothing else.
- **MCP mode:** the meeting context you provide is sent to the connected
  Zime MCP server, which looks up calls and CRM data your workspace already
  holds. If you don't want that, don't connect the server — local mode
  works without it.
