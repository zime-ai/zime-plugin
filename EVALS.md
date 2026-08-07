# Evals

How this repo tests its skills. The full methodology — why format
compliance and insight quality are reported as two separate metrics, what
each tier can and cannot prove — lives in the open repo's
[EVALS.md](https://github.com/zime-ai/zime-gtm-skills/blob/main/EVALS.md);
this file covers only what's different for tool-coupled internal skills.

## The three tiers (inherited)

1. **Trigger evals** (automated) — does the right skill fire for a given
   prompt? `evals/trigger-set.json`, run via `skill-creator`'s
   `scripts/run_eval.py`. Because most users install these skills
   alongside the open zime-gtm-skills set, the trigger set includes
   negative cases: prompts that belong to an open-repo skill and must NOT
   fire anything here (`should_trigger: null`).
2. **Format compliance** (automated) — the with/without-skill loop over
   each skill's `evals/evals.json`. Reported as consistency and scope
   discipline, never as insight quality.
3. **Insight recall vs. human gold labels** (requires a human, once) —
   briefs in `evals/gold/BRIEFS.md`, authored by someone who has not read
   the skill's references, so transcripts aren't written to contain
   exactly what the skill hunts for.

## The extra tier for tool-coupled skills

Skills here call live tools (zime-mcp), which adds a failure axis the open
repo doesn't have. Every tool-coupled skill's `evals/evals.json` must
include:

- **Tool-mandate case**: the tool is available AND the prompt alone holds
  enough context to hand-write a plausible answer — the skill must still
  call the tool. Hand-building while the tool is available is the
  highest-risk regression for these skills, because the output *looks*
  fine.
- **Honest-failure case**: the tool errors — the skill retries once, then
  says plainly the live service was unreachable and offers the fallback.
  It never presents a hand-written result as tool-backed.

`prep-note` evals 3 and 4 are the reference implementations of both.

## Private data

Real transcripts, gold labels, and case files never land in this repo —
even though it's private, the .gitignore keeps `evals/transcripts/`,
`evals/gt/`, `evals/cases/`, and `evals/labels/` untracked, same as the
open repo. Synthetic fixtures only.
