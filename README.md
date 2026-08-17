# zime-plugin

[![Skills](https://img.shields.io/badge/skills-15-blue)](skills/)
[![Internal](https://img.shields.io/badge/visibility-internal--only-red)](#visibility)

The internal, Zime-only Claude Code plugin: Agent Skills coupled to Zime
products, bundled with the Zime MCP connector config so installing the
plugin wires up both together. The counterpart open repo is
[zime-gtm-skills](https://github.com/zime-ai/zime-gtm-skills), which holds
skills that run standalone on a local file with no product coupling;
**this repo holds the skills (and the connector) that couple to Zime
products** — zime-mcp tools, workspace data — and therefore can't go open
source.

Same format (the [Agent Skills](https://agentskills.io) spec), same
structure, same validators, same trust bar: every factual claim a skill
produces traces to a source, never a plausible guess.

## Visibility

Internal only. Do not open-source, fork publicly, or share outside Zime.
Even here, three things never land in a tracked file:

1. **Secrets** — API keys, tokens, auth headers, company ids.
2. **Customer data** — real account names, deal names, attendee emails,
   transcripts. Sample data is always synthetic.
3. **Internal endpoints** — `internal-*` hostnames, admin API paths, raw
   HTTP calls. Skills talk to Zime through named MCP tools, nothing lower.

A skill with **no** product coupling doesn't belong here — contribute it
to the open repo instead.

## Available skills

<!-- SKILLS:START -->
| Skill | Does | Coupling |
|---|---|---|
| [get-account](skills/get-account/) | Looks up one CRM account record — domain, industry, owner | zime-mcp `list_accounts` (required when connected); local fallback from a CRM export |
| [get-deal](skills/get-deal/) | Looks up one CRM deal record — stage, amount, owner, close date | zime-mcp `list_deals` (required when connected); local fallback from a CRM export |
| [get-meeting](skills/get-meeting/) | Looks up one meeting's metadata — recorded calls and calendar events; title, date, attendees, linked deal | zime-mcp `list_meetings` (required when connected); local fallback from a provided transcript/invite |
| [get-transcript](skills/get-transcript/) | Gets the full verbatim transcript for one call | zime-mcp `get_transcript` (required when connected); no local fallback |
| [call-prep](skills/call-prep/) | Builds a pre-call prep note — meeting snapshot, deal state, who's who, prior-call history, likely objections, call objectives | zime-mcp `prep_note` tool (required when connected); local fallback from provided files |
| [call-recap](skills/call-recap/) | Structured recap of one recorded call — overview, decisions, risks, action items by owner, open questions | zime-mcp `list_meetings` + `ask_zime` (required when connected); local fallback from a provided transcript |
| [follow-up](skills/follow-up/) | Drafts the post-call follow-up email to the prospect, grounded in the call transcript; nothing is sent | zime-mcp `list_meetings` + `ask_zime` (required when connected); local fallback from a provided transcript |
| [deal-strategy](skills/deal-strategy/) | Deep-dives one deal — where it stands, objections and risks in play, stakeholders, concrete moves to advance it | zime-mcp `list_deals` + `ask_zime` (required when connected); local fallback from a provided transcript/CRM export |
| [actions-commitments](skills/actions-commitments/) | Open action items and commitments — what was promised, by whom, by when — for one call, one deal, or across an account | zime-mcp `list_meetings`/`list_deals` + `ask_zime` (required when connected); local fallback from a provided transcript |
| [account-research](skills/account-research/) | Prospect research brief — company profile, GTM motion, likely buyers, fit against our ICP | web search (primary) + zime-mcp `ask_zime` once for our ICP baseline; runs standalone without zime-mcp |
| [create-sales-asset](skills/create-sales-asset/) | Builds rep-facing sales collateral (proof points, a case-study writeup, battlecard section) from real call/CRM evidence only | zime-mcp `list_accounts`/`list_deals` + `ask_zime` + `get_transcript` (required when connected); local fallback from provided files |
| [create-sales-to-cs-handover](skills/create-sales-to-cs-handover/) | Assembles the Sales-to-CS handoff packet — deal state, stakeholders, commitments, technical risks CS should watch | zime-mcp `list_deals`/`list_accounts` + `ask_zime` + `list_meetings` (required when connected); local fallback from provided files |
| [pipeline-review](skills/pipeline-review/) | Pipeline health across many deals — at-risk, stalled, missing next steps, forecast commentary | zime-mcp `ask_zime` (required when connected); local fallback from a multi-deal CRM export |
| [daily-briefing](skills/daily-briefing/) | Orchestrated "what's on my plate today" — meetings, deals needing attention, action items due | zime-mcp `ask_zime`, optionally `list_meetings` for the calendar view (required when connected); no local fallback |
| [competitive-intelligence](skills/competitive-intelligence/) | What customers actually say about a named competitor — one call or across the corpus | zime-mcp `ask_zime`, plus `list_meetings` to confirm a single call and `get_transcript` for quotes; local fallback from provided transcripts |
<!-- SKILLS:END -->

## Install

```bash
# Claude Code plugin (needs access to the private repo)
/plugin marketplace add zime-ai/zime-plugin
/plugin install zime-plugin@zime-plugin
```

Installing the plugin also registers the bundled Zime MCP connector
(`.mcp.json`, pointing at `https://mcp.zime.ai/mcp`) — the first tool call
opens a browser for the standard Zime OAuth login. See
[Connector](#connector) below.

```bash
# or copy a skill straight into a project
cp -r zime-plugin/skills/call-prep .claude/skills/
```

## Validate

```bash
./validate-skills.sh                # frontmatter/layout, zero deps
./scripts/check-docs-sync.sh        # README badge + table vs skills/
python3 scripts/scan-content.py     # leak/injection/hidden-unicode scan
./tests/run-checks-tests.sh         # the validators vs broken fixtures
```

All inherited from the open repo (`check-docs-sync.sh` and the fixture
tests are simplified variants matched to this README). CI runs all four
plus the upstream `skills-ref` validator on every PR — see
`.github/workflows/validate.yml`. Run them before every PR.

## Evals

Per-skill `evals/evals.json` plus a repo-level `evals/trigger-set.json`
(does the right skill fire, including must-NOT-fire cases for prompts that
belong to the open repo's skills). Tool-coupled skills additionally carry
a tool-mandate case and an honest-failure case — see [EVALS.md](EVALS.md).

## Connector

`.mcp.json` bundles the Zime MCP connector so installing this plugin
registers it alongside the skills:

```json
{
  "mcpServers": {
    "zime": {
      "type": "http",
      "url": "https://mcp.zime.ai/mcp",
      "oauth": { "clientId": "zime-mcp" }
    }
  }
}
```

It's the same remote, OAuth-gated MCP server (`core/src/modules/mcp/` in
`zime-nodejs-microservices`) already reachable as the "Zime" connector on
claude.ai — per-user RBAC, no static API key. First tool call opens a
browser for Zime login; the session then persists (7 days). See that
repo's `core/docs/mcp/MCP_SERVER.md` for the engineering reference.

## Structure

```
zime-plugin/
├── .claude-plugin/          # /plugin marketplace add zime-ai/zime-plugin
├── .mcp.json                # bundled Zime MCP connector config
├── .github/workflows/       # CI: validators + skills-ref + PR review agent
├── skills/
│   └── skill-name/
│       ├── SKILL.md         # required
│       ├── references/      # optional
│       ├── assets/          # optional, synthetic samples only
│       └── evals/           # optional, declarative evals.json
├── evals/                   # trigger-set.json + gold briefs (Tier 1 & 3)
├── scripts/
├── tests/                   # fixture tests for the validators
├── validate-skills.sh
├── AGENTS.md                # rules for AI agents working in this repo
├── EVALS.md
└── README.md
```

Maintained by [Zime](https://zime.ai). Internal use only.
