# Skills and learnings

What ships in this plugin, and what building it taught us.

`README.md` is the front door (install, visibility, the skills table).
`AGENTS.md` is the contract for writing a skill. `EVALS.md` is the testing
methodology. This file is the retrospective: the shape of the skill set and
the decisions we'd otherwise have to re-derive.

Current release: **0.2.0** · **15 skills** · **57 skill-level evals** ·
**28 trigger cases**

---

## The skill set

Three layers, and the layer a skill belongs to decides almost everything
about how it's written.

### Layer 1 — Record lookups (4 skills)

Pin one CRM record and return its fields. No agent, no synthesis.

| Skill | Returns | Tool |
|---|---|---|
| `get-account` | domain, industry, owner | `list_accounts` |
| `get-deal` | stage, amount, owner, close date | `list_deals` |
| `get-meeting` | date, attendees, linked deal, recorded? | `list_meetings` |
| `get-transcript` | full verbatim transcript | `get_transcript` |

These are the cheapest and the least likely to go wrong. They exist mostly
so the analysis skills have something to route *away* to: "what stage is
Acme in" should never spend an agent call.

### Layer 2 — Analysis (7 skills)

Resolve an entity, then delegate the thinking to Zime's agent.

| Skill | Scope | Tools |
|---|---|---|
| `call-recap` | one past call | `list_meetings` → `ask_zime`, `get_transcript` |
| `follow-up` | one past call → draft email | `list_meetings` → `ask_zime` |
| `deal-strategy` | one deal, in depth | `list_deals` → `ask_zime` |
| `actions-commitments` | call, deal, or account | `list_meetings`/`list_deals` → `ask_zime` |
| `competitive-intelligence` | one call or the whole corpus | `ask_zime` (+ `list_meetings`, `get_transcript`) |
| `pipeline-review` | many deals, no resolve step | `ask_zime` |
| `daily-briefing` | the rep's day | `ask_zime` (+ `list_meetings`) |

### Layer 3 — Deliverables and pre-pipeline (4 skills)

| Skill | Produces | Notes |
|---|---|---|
| `call-prep` | prep note for an upcoming call | the only `prep_note` consumer |
| `create-sales-asset` | deck, one-pager, battlecard, case study | deck → Slides, rest → Doc |
| `create-sales-to-cs-handover` | the CS handover doc | → Google Doc |
| `account-research` | prospect brief before first contact | web search primary, `ask_zime` once for our ICP |

By category: 13 `cross-stage`, 1 `pre-pipeline` (`account-research`),
1 `post-sale` (`create-sales-to-cs-handover`).

### The tool surface

Seven tools, after consolidation:

```
ask_zime        the agent — all synthesis, coaching, cross-entity questions
prep_note       upcoming-call prep (its own pipeline, not the agent)
list_deals      \
list_accounts    |  resolve or browse CRM records
list_meetings    |
get_contact     /
get_transcript  verbatim text of one call
```

`ask_zime` appears in 10 of 15 skills. It has **no scoping argument** — you
narrow it by naming the call, deal, account, or window inside the question
text. That single fact drives most of the phrasing rules below.

---

## Learnings

### 1. Tool surface area is a liability, not a feature

The MCP server once exposed 14 tools. Seven were removed in
[#2116](https://github.com/zime-ai/zime-nodejs-microservices/pull/2116):
three entity-scoped variants (`ask_call_brain`, `ask_deal_brain`,
`ask_account_brain`) that differed only in which id they pinned, and four
canned-question tools (`get_deal_objections`, `get_deal_next_steps`,
`generate_call_recap`, `draft_follow_up_email`) that each sent one hardcoded
prompt to the same agent.

None of them enabled anything a caller couldn't get by naming the entity and
phrasing the question. What they did do is give the model 14 near-synonymous
choices, and force every skill to document which one to pick.

**The tell:** if two tools would send the same request to the same backend
and differ only in argument shape, they're one tool.

### 2. A tool rename is a cross-repo migration

Renaming `ask_zime_brain` → `ask_zime` touched, in this repo alone: 50
references across 10 `SKILL.md` files, 32 across 11 eval files, 5 in
`README.md`, and 2 eval *identifiers* (`...-routes-to-call-brain`) that
described tools no longer in existence.

The eval rewrites were not a find-and-replace. The removed tools took a
`call_id`/`deal_id` argument that `ask_zime` doesn't have, so assertions like
`"ask_call_brain is called with the resolved call_id"` had to become
`"ask_zime is called naming the resolved call"` — a change in meaning, not
spelling.

And mechanical substitution produced three sentences that read
`"calls ask_zime … rather than sending a question to ask_zime"`. Nonsense
that a regex can't see. **Read the output back after any bulk rewrite.**

### 3. Descriptions are read by a router, but also by humans

The original descriptions ran 500–758 characters, packing trigger phrases,
tool chains, and fallback behavior into the frontmatter. Thorough, and nobody
read them. They now run 88–244 characters, one or two plain sentences.

The detail didn't disappear — it moved into the body, where there's room for
it. Frontmatter is a router hint and a menu label; it is not the manual.

### 4. Scoping in prose needs the scope spelled out

Because `ask_zime` has no date or entity parameters and no memory of the
conversation, every skill has to say so. Three rules recur:

- **Put the window in the question.** "this quarter" is not a parameter.
- **Resolve pronouns.** "that deal" means nothing; name it.
- **Don't broaden.** A count question is not a list question, and
  "fetch everything then filter yourself" over-fetches and loses the scope.

### 5. Two eval cases catch the failures that matter

Per `EVALS.md`, every tool-coupled skill carries both:

- **Tool-mandate** — the tool is available *and* the conversation already
  holds enough context to hand-write a plausible answer. The skill must
  still call the tool. This is the highest-risk regression precisely because
  the fabricated output looks fine.
- **Honest failure** — the tool errors. Retry once, then say the service was
  unreachable and offer the fallback. Never pass a hand-written result off as
  tool-backed.

`call-prep` evals 3 and 4 are the reference implementations.

### 6. Negative trigger cases are as valuable as positive ones

`get-email` was withdrawn because email records carry no per-user access
control — every user in a company can read every colleague's subjects and
snippets. Defensible for aggregate counts; not for handing an LLM a mailbox.

The interesting part is what happened to its eval. Rather than deleting the
case, it became a **negative**: "What did we email Acme last week about
pricing?" now asserts that *nothing* fires. A rep will still ask it, and the
risk isn't a missing answer — it's `follow-up` or `call-recap` confidently
answering a question they can't actually answer.

5 of 28 trigger cases are must-NOT-fire. Several belong to open-repo skills,
guarding against this plugin hijacking prompts meant for the standalone set.

### 7. A validator nobody has seen fail is not known to work

`tests/run-checks-tests.sh` runs each validator against deliberately broken
fixtures — 21 assertions. It caught a real gap: `check-docs-sync.sh` had a
`wrong badge count fails` fixture that passed, and the badge itself said 16
while 15 skill directories existed. The check was fine; the badge was stale
since `cd2cea0` removed `get-email` without decrementing it.

CI had been red on every push for three days and it read as noise.

### 8. Publishing is a separate system from pushing

Four commits reached `main` and the marketplace kept serving a three-day-old
version. The cause, from Anthropic's
[org plugin docs](https://support.claude.com/en/articles/13837433-manage-plugins-for-your-organization):

> Auto-sync runs when **a pull request with a plugin version bump is merged**
> to the default branch. **Direct pushes don't trigger a sync.**

So a release needs *both* a version bump in `.claude-plugin/plugin.json`
*and* delivery by merged PR. A bump pushed straight to `main` publishes
nothing — we did exactly that in `248aa18`, then reverted and re-landed it
through PR #1.

`.github/workflows/release-pr.yml` now opens that PR automatically when
`skills/**` or `.claude-plugin/**` changes.

### 9. Don't infer the version bump from commit messages

The obvious automation is conventional-commits → semver. It would have been
wrong here: the `ask_zime` rename is breaking, and nothing in a commit
subject distinguishes it from a description tweak. Inference would have
proposed `0.1.1` for a release that needed `0.2.0`.

The workflow always proposes a **patch** bump and says in the PR body to
edit it when the change deserves more. A wrong-but-automatic version is worse
than a boring one a human corrects.

### 10. Skills and server must ship together

`0.2.0` is published and references `ask_zime`. PR #2116, which renames the
tool server-side, is **unmerged**. Until it deploys, every `ask_zime` call
fails against production.

Two repos, one contract, independent deploys — the ordering has to be
deliberate. Server first (add the new name), then plugin, or the plugin
points at something that doesn't exist yet.

---

## Open items

- **#2116 unmerged.** Until it deploys, `0.2.0` skills call a tool prod
  doesn't expose.
- **`MCP_ENABLED_TOOLS` fails silently.** An unrecognized name isn't an
  error — the tool just never registers. `core/.env` still lists
  `list_transcripts,search_transcripts`, which match nothing, so local dev
  runs 1 of 7 tools. Prod doesn't set the var, so it's unaffected. A startup
  warning for unknown names would turn this into a visible failure.
- **PPT output is approximate.** No slide-authoring tool exists; the deck
  path uses the Drive connector's Slides mime type, and text-to-slides
  conversion needs a manual cleanup pass. `create-sales-asset` says so
  rather than overselling it.
- **Jest not run** on #2116. The three touched specs are verified only by
  typecheck and static arity checks.
