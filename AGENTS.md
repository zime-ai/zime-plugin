# AGENTS.md

Guidelines for AI agents working in this repository.

## Repository overview

The product-coupled counterpart to
[zime-gtm-skills](https://github.com/zime-ai/zime-gtm-skills). Skills here
are allowed — expected — to couple to Zime products: zime-mcp tools,
connectors, live workspace data. That coupling is exactly why they live
here rather than in the standalone repo.

- **Name**: zime-plugin
- **Visibility**: public. The skills carry prompts and tool routing, never
  credentials or customer records, and the connector enforces access
  per user server-side. The content rules below are what keep that true —
  treat them as hard constraints, not conventions.
- **Maintained by**: [Zime](https://zime.ai)
- **Contains**: `skills/` (this repo's Agent Skills) plus a bundled MCP
  server config (`.mcp.json`) pointing at the live Zime MCP connector at
  `mcp.zime.ai` — installing the plugin registers both together.

## What goes in which repo

| Skill needs | Repo |
|---|---|
| Runs standalone on a local file, no product coupling | zime-gtm-skills (open) |
| Calls a zime-mcp tool, connector, or workspace data | **this repo** |

If a skill you're writing here turns out to need no coupling, move it to
the open repo before it lands.

## Repository structure

```
zime-plugin/
├── .claude-plugin/
│   ├── marketplace.json
│   └── plugin.json
├── .mcp.json                  # bundled Zime MCP connector config
├── skills/
│   └── skill-name/
│       ├── SKILL.md          # required
│       ├── references/       # optional
│       ├── assets/           # optional, synthetic samples only
│       └── evals/            # optional, evals.json, declarative
├── scripts/
├── validate-skills.sh
└── README.md
```

## Frontmatter contract (same as the open repo)

| Field | Required | Constraints |
|---|---|---|
| `name` | yes | 1–64 chars, lowercase `[a-z0-9-]`, must equal the parent directory name |
| `description` | yes | 1–1024 chars; state both *what* the skill does and *when* to use it |
| `license` | no | |
| `metadata` | no | this repo uses `zime:category`, `zime:dimension` (`stage`/`initiative`/`vertical-context`), `zime:input-modes` |

`SKILL.md` stays under 500 lines. Move detail into `references/`.
Subdirectories are one level deep: `references/`, `scripts/`, `assets/`,
`evals/` only.

## Validate

```bash
./validate-skills.sh                # frontmatter/layout, zero deps
./scripts/check-docs-sync.sh        # README badge + table vs skills/
python3 scripts/scan-content.py     # leak/injection/hidden-unicode scan
./tests/run-checks-tests.sh         # the validators vs broken fixtures
```

`scan-content.py` walks `git ls-files`, so `git add` (or `git add -N`)
new files before trusting a clean result. Run the fixture tests after
touching any validator — a check that has never been shown to catch
anything is assumed working, not known working. CI
(`.github/workflows/validate.yml`) runs all of the above plus the
upstream `skills-ref` validator, pinned to the same commit as the open
repo; bump both pins together. `pr-agent.yml` needs an `ANTHROPIC_KEY`
repo secret before it can review PRs.

## The hard content rules

Coupling to Zime products is allowed here. These still are not:

1. **No secrets.** No API keys, tokens, auth headers, or company ids in
   any tracked file.
2. **No customer data.** No real account names, deal names, attendee
   emails, or transcript excerpts — sample assets are always synthetic.
   Examples use fictional companies (`Acme`, `Northwind`, `Meridian`); a
   real customer name in an example prompt is a leak, and the repository is
   public. `scan-content.py` checks this against `.private/`'s denylist,
   which is gitignored — so the rule **skips** rather than fails when the
   file is absent. Keep a local copy or this check silently passes.
3. **No internal endpoints.** No `internal-*` hostnames, admin API paths,
   or raw HTTP calls in skill content. A skill addresses Zime through a
   named MCP tool (e.g. the zime-mcp `prep_note` tool, wrapped here by the
   `call-prep` skill); the tool owns the transport.
4. **Every factual claim a skill outputs traces to a source** — tool
   output, a provided transcript, a CRM field. Gaps are stated, never
   filled with plausible guesses. Same trust bar as the open repo.

## Evals

Each skill may carry `evals/evals.json` in the same declarative format as
the open repo (prompt + files + `expectations`). Tool-coupled skills MUST
include at least one eval asserting the tool is actually called when
available, and one covering honest behavior when the tool fails. The
repo-level `evals/trigger-set.json` holds Tier 1 firing cases, including
must-NOT-fire prompts that belong to open-repo skills; `evals/gold/`
holds Tier 3 briefs. See `EVALS.md`.
