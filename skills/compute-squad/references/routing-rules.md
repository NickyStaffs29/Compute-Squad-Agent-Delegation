# Compute Squad v3 — Role Hierarchy and Routing Rules

Updated 2026-07-25. v3 restructures roles around a clean four-tier hierarchy: main session = strategy, Opus = PM, Sonnet = execution, Haiku = intern.

## Roles and model routing

| Role | Model | Agent | Responsibility |
|---|---|---|---|
| Strategy | Main-session model (top tier recommended) | none — runs in the main session | Interrogates the goal, identifies gaps, clarifies them with the user, locks goal + acceptance criteria, final judgment and high-stakes review. Runs in the main session because only the main session can ask the user questions; subagents are headless. |
| PM | Opus | `squad-pm` (PLAN / ACCEPT modes) | Plans the work (spec + ordered task breakdown, execution classification) and accepts the deliverable (adversarial verification, PASS/FAIL, clears the log on PASS). Never writes product code. |
| Execution | Sonnet | `squad-recon`, `squad-executor` | Codebase mapping and implementation against the PM's plan. Executor escalates to an Opus override only when the PM classifies the work COMPLEX. |
| Intern | Haiku | `squad-mech` | Zero-judgment busywork: log archival, rotation, formatting normalization, boilerplate collection. Refuses anything requiring judgment. |

## Why the hierarchy works

- **Verification asymmetry holds by construction.** The Opus PM accepts Sonnet execution, so the reviewer is always a tier above the work. When execution escalates to Opus (COMPLEX), acceptance stays at Opus and high-stakes changes add a top-tier main-session review on top.
- **The tight-spec dependency.** Sonnet-as-execution is only as good as the PM's plan. That is by design: the PLAN mode requirement (a task list a junior engineer could follow without judgment calls) is what makes cheap execution safe. A vague plan is a plan defect, and the Executor is instructed to log it as a blocker rather than improvise.
- **Gaps surface before tokens are spent.** Stage 0 strategy runs before any agent spawns, so ambiguity gets resolved with the user once, up front, instead of being discovered by a FAIL three stages deep.

## Routing rules

1. **Route by role, escalate by evidence.** Default routing follows the hierarchy. Escalate a stage's model only on the PM's COMPLEX classification or after repeated FAILs, never on vibes.
2. **Retry economics.** Opus costs roughly 1.67x Sonnet ($5/$25 vs $3/$15 per M tokens, July 2026). If a stage's failure forces upstream re-runs, the stronger model is the cheaper one. When unsure, route up.
3. **Escalate on repeated FAIL.** Same stage fails twice → one tier up for the third attempt (Sonnet → Opus → flag the user for a top-tier main-session pass). Three total FAILs on a run → stop and hand back to the user with the log history.
4. **Strategy changes go to the user.** Anything that would alter the locked goal or acceptance criteria returns to Stage 0 and the user. No agent, including the PM, renegotiates strategy.
5. **Adversarial verification** (audit-grade runs): fan out Sonnet finder agents across dimensions (runtime integrity, security/privacy, dead code/slop, UI/accessibility, docs drift); Opus skeptics attempt to refute each finding; only skeptic-confirmed findings count.
6. **The hierarchy is fractal (DELEGATE protocol).** Every level pushes its own busywork down a tier. The runtime is flat (subagents cannot spawn subagents), so stages request delegation via a `DELEGATE:` block in their log entry and the Squad Manager executes it on their behalf: intern tasks go to `squad-mech`, tightly-specced execution tasks to a Sonnet helper, results land under `## Delegated — <stage>`, and `BLOCKING` requests re-spawn the requesting stage with results in the log. Downward only; capped at 5 helpers per stage per run.

## Cost posture (July 2026, $/M input/output)

Fable 5 $10/$50 · Opus 5 $5/$25 · Sonnet 5 $3/$15 · Haiku 4.5 $1/$5.

v3 concentrates Opus spend in the two decision-dense PM passes and pushes volume work (mapping, implementation) to Sonnet. Versus v2 (Opus executor by default), a typical run is roughly 30-40% cheaper on tokens; the trade is a hard dependency on plan quality, which rule 3 backstops. The frame is capacity: cheaper runs mean more runs, more parallel goals, and top-tier attention reserved for strategy instead of supervision.

## Model aliases

Agent definitions use the `sonnet` / `opus` / `haiku` aliases so the squad tracks each tier's current generation automatically. Agent frontmatter only accepts the opus/sonnet/haiku tiers, which is why strategy lives in the main session (whatever model you run there, and the only place user clarification is possible). Pin explicit model IDs only if a workflow regression-tests better on an older snapshot.

## Log discipline (unchanged)

- All coordination through `COMPUTE_SQUAD_LOG.md` in the repo root; each stage appends one entry (`## Recon`, `## PM — Plan`, `## Executor`, `## PM — PASS` / `## PM — FAIL`).
- Archive any non-empty log to a timestamped file before every new run (`codex-prompts/compute-squad-archive/` if present, else `compute-squad-archive/`). Never discard a prior or failed run.
- Only a PASSing PM clears the active log, and only as its final action.
- Anti-slop discipline in the plan: YAGNI, stdlib/native first, no speculative abstractions.
