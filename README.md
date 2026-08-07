# zime-internal-skills

[![Skills](https://img.shields.io/badge/skills-1-blue)](skills/)
[![Internal](https://img.shields.io/badge/visibility-internal--only-red)](#visibility)

The internal, Zime-only counterpart to
[zime-gtm-skills](https://github.com/zime-ai/zime-gtm-skills). The open
repo holds skills that run standalone on a local file with no product
coupling; **this repo holds the skills that couple to Zime products** —
zime-mcp tools, connectors, workspace data — and therefore can't go open
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
| [prep-note](skills/prep-note/) | Builds a pre-call prep note — meeting snapshot, deal state, who's who, prior-call history, likely objections, call objectives | zime-mcp `prep-note` tool (required when connected); local fallback from provided files |
<!-- SKILLS:END -->

## Install

```bash
# Claude Code plugin (needs access to the private repo)
/plugin marketplace add zime-ai/zime-internal-skills
/plugin install zime-internal-skills@zime-internal-skills
```

```bash
# or copy a skill straight into a project
cp -r zime-internal-skills/skills/prep-note .claude/skills/
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

## Structure

```
zime-internal-skills/
├── .claude-plugin/          # /plugin marketplace add zime-ai/zime-internal-skills
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
