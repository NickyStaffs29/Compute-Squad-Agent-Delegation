# Compute Squad

A delegation pipeline for AI coding agents that routes models by **decision density**, not task difficulty. One skill, four agents, a shared log, and a role hierarchy that mirrors how good teams actually work:

| Role | Model | Who | Does |
|---|---|---|---|
| Strategy | Your main session (top tier recommended) | you + the session model | Interrogates the goal, surfaces gaps, clarifies them with you, locks acceptance criteria, final judgment |
| PM | Opus | `squad-pm` | Plans the work (spec + ordered task breakdown), adversarially accepts the deliverable |
| Execution | Sonnet | `squad-recon`, `squad-executor` | Read-only codebase mapping, implementation exactly per plan |
| Intern | Haiku | `squad-mech` | Zero-judgment busywork: log archival, formatting, inventories |

Works in **Claude Code**, **Claude Cowork**, and (as a manual prompt pack) **Codex**.

## Install

**Claude Code:**

```
/plugin marketplace add NickyStaffs29/compute-squad
/plugin install compute-squad@compute-squad
```

**Claude Cowork:** download `compute-squad.plugin` from [Releases](../../releases), drop it into a chat, and accept the install.

**Codex:** no install. Use the prompt pack in [`codex/`](codex/) — the same pipeline as a manually-run sequence of sessions. See [`codex/README.md`](codex/README.md).

## Usage

```
run the squad: add rate limiting to the password-reset endpoint
```

What happens:

0. **Strategy (your session):** the goal gets interrogated, gaps get clarified with you in one batched pass, and the goal + acceptance criteria get locked. No agent spawns before this.
1. **Archive (Haiku):** any prior `COMPUTE_SQUAD_LOG.md` is archived to a timestamped file. Failed runs are never discarded.
2. **Recon (Sonnet):** read-only mapping — exact files, functions, line ranges, call sites, invariants.
3. **Plan (Opus PM):** a spec and ordered task list tight enough that execution needs no judgment calls, classified MECHANICAL / STANDARD / COMPLEX.
4. **Execute (Sonnet; Opus if COMPLEX):** exactly what the plan says. Production quality, no scaffolding, tests green before logging done.
5. **Accept (Opus PM):** adversarial verification — re-runs everything itself, attempts refutations per criterion, issues PASS or FAIL. On FAIL it names exactly one stage to re-run. On PASS it clears the log. High-stakes changes get a final review in your session.

Say "be thorough" and acceptance adds an audit-grade fan-out: parallel Sonnet finders across dimensions (runtime integrity, security/privacy, dead code, accessibility, docs drift), with Opus skeptics refuting each finding before it counts.

A complete worked run with every log entry format is in [`docs/example-log.md`](docs/example-log.md).

## The idea

Most multi-agent setups route by task difficulty and burn their strongest model supervising. Compute Squad routes by decision density:

**Stages that decide get strong models. Stages that execute against a tight spec get cheap ones.** Planning and acceptance are where errors cascade, so they run Opus. Mapping and implementation are volume work against a spec, so they run Sonnet. Zero-judgment steps run Haiku. Your top-tier session does the one thing only it can do: talk to you, and judge.

Three properties fall out of the structure rather than needing enforcement:

- **Verification asymmetry holds by construction.** The Opus PM reviews Sonnet execution, so the reviewer is always a tier above the work. The executor never accepts its own output.
- **Cheap execution is safe because the plan carries the intelligence.** PLAN mode must produce a task list a junior engineer could follow without judgment calls. A vague plan is a plan defect; the executor is instructed to log it as a blocker, never improvise.
- **The hierarchy is fractal (DELEGATE protocol).** Every stage pushes its own busywork down a tier via a `DELEGATE:` block in its log entry. Subagents can't spawn subagents, so the orchestrating session acts as the switchboard — downward only, capped at 5 helpers per stage.

Escalation is evidence-based: a stage that fails acceptance twice gets one model tier up on the third attempt. Three total FAILs stops the run. Anything that would change the locked goal goes back to the human, always.

The frame is capacity, not cost-cutting: concentrating strong-model spend in the two PM passes makes runs roughly 30-40% cheaper than an all-Opus worker pool, which means more runs, more parallel goals, and top-tier attention reserved for strategy instead of supervision.

## Components

```
compute-squad/
├── .claude-plugin/
│   ├── plugin.json           # plugin manifest
│   └── marketplace.json      # makes this repo directly installable in Claude Code
├── skills/compute-squad/
│   ├── SKILL.md              # the Squad Manager orchestration protocol
│   └── references/
│       └── routing-rules.md  # full routing rules, escalation, cost math
├── agents/
│   ├── squad-recon.md        # Sonnet · read-only mapping
│   ├── squad-pm.md           # Opus · PLAN + ACCEPT modes
│   ├── squad-executor.md     # Sonnet · implementation (Opus override on COMPLEX)
│   └── squad-mech.md         # Haiku · the intern
├── codex/                    # the pipeline as manual Codex session prompts
└── docs/example-log.md       # a complete worked run
```

## FAQ

**Why isn't the strategy layer an agent?** Two reasons. Subagents run headless — they can't ask you anything, and gap clarification is the whole point of Stage 0. And agent definitions pin to the opus/sonnet/haiku tiers; the main session is the only place your top-tier model runs. Strategy therefore lives in the skill, executed by whatever model you run your session on.

**Do the models auto-upgrade?** Yes. Agents use tier aliases (`opus`, `sonnet`, `haiku`), which resolve to the newest model in each class at runtime. No plugin update needed when new generations ship. Pin an explicit model ID in an agent's frontmatter only if a workflow regression-tests better on an older snapshot.

**Why is Sonnet execution safe?** Because the PM's plan is required to carry the intelligence (see above), acceptance always reviews from a tier up, and the PM's COMPLEX classification escalates execution to Opus when a tight spec can't fully de-risk the work.

**Why the shared log instead of passing context directly?** The log is durable, auditable state. FAILs re-run stages against the full history, failed runs archive instead of vanishing, and the same file protocol works in runtimes that can't spawn agents at all (see `codex/`).

**Isn't five stages heavy for a one-line change?** The stages are mandatory; their length isn't. A one-line change gets a three-sentence Recon entry and a four-line plan. The discipline is what stays constant.

## License

MIT — see [LICENSE](LICENSE).
