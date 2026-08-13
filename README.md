# zime-plugin

[![Skills](https://img.shields.io/badge/skills-16-blue)](skills/)
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
| [get-account](skills/get-account/) | Looks up one CRM account record — domain, industry, owner | zime-mcp `get_account` (required when connected); local fallback from a CRM export |
| [get-deal](skills/get-deal/) | Looks up one CRM deal record — stage, amount, owner, close date | zime-mcp `get_deal` (required when connected); local fallback from a CRM export |
| [get-meeting](skills/get-meeting/) | Looks up one meeting/call's metadata — title, date, attendees, linked deal | zime-mcp `get_call` (required when connected); local fallback from a provided transcript/invite |
| [get-transcript](skills/get-transcript/) | Gets the full verbatim transcript for one call | zime-mcp `get_transcript` (required when connected); no local fallback |
| [get-email](skills/get-email/) | Placeholder for looking up one email — no backing tool yet, so it always declines honestly | none yet — blocked on a connector tool; see the skill's Status note |
| [call-prep](skills/call-prep/) | Builds a pre-call prep note — meeting snapshot, deal state, who's who, prior-call history, likely objections, call objectives | zime-mcp `prep_note` tool (required when connected); local fallback from provided files |
| [call-recap](skills/call-recap/) | Structured recap of one recorded call — overview, decisions, risks, action items by owner, open questions | zime-mcp `generate_call_recap` (required when connected); local fallback from a provided transcript |
| [follow-up](skills/follow-up/) | Drafts the post-call follow-up email to the prospect, grounded in the call transcript; nothing is sent | zime-mcp `draft_follow_up_email` (required when connected); local fallback from a provided transcript |
| [deal-strategy](skills/deal-strategy/) | Objections in one deal, plus prescriptive coaching — how to win, why a deal is stalling, positioning vs. a competitor | zime-mcp `get_deal_objections` + `ask_zime` (required when connected); local fallback for the objections half only |
| [actions-commitments](skills/actions-commitments/) | Next steps for one deal (committed/scheduled/recommended, kept separate), plus personal or cross-deal action items | zime-mcp `get_deal_next_steps` + `ask_zime` (required when connected); local fallback for the single-deal half only |
| [account-research](skills/account-research/) | Research brief on one account — CRM facts plus a synthesized narrative of deal history, sentiment, risk, and stakeholders | zime-mcp `get_account` + `ask_zime` (required when connected); local fallback from a CRM export and/or transcripts |
| [sales-asset-builder](skills/sales-asset-builder/) | Builds rep-facing sales collateral (proof points, a case-study writeup, battlecard section) from real call/CRM evidence only | zime-mcp `ask_zime` + `get_transcript`/`get_account`/`get_deal` (required when connected); local fallback from provided files |
| [sales-cs-handover](skills/sales-cs-handover/) | Assembles the Sales-to-CS handoff packet — deal state, stakeholders, commitments, technical risks CS should watch | zime-mcp `get_deal` + `get_deal_next_steps` + `ask_zime` (required when connected); local fallback from provided files |
| [pipeline-review](skills/pipeline-review/) | Pipeline health across many deals — at-risk, stalled, missing next steps, forecast commentary | zime-mcp `ask_zime` (required when connected); local fallback from a multi-deal CRM export |
| [daily-briefing](skills/daily-briefing/) | Orchestrated "what's on my plate today" — meetings, deals needing attention, action items due | zime-mcp `ask_zime` (required when connected); no local fallback |
| [competitive-intelligence](skills/competitive-intelligence/) | Cross-deal/cross-call view of how the team is doing against a named competitor | zime-mcp `ask_zime` + `get_transcript` (required when connected); local fallback from provided transcripts |
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
