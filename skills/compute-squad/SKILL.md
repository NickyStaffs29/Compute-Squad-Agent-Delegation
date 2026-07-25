---
name: compute-squad
description: >
  This skill should be used when the user asks to "run the squad", "run compute squad",
  "compute squad this", "squad run", or wants a code change executed through the
  Compute Squad delegation pipeline (Strategy → Recon → Plan → Execute → Accept) with
  COMPUTE_SQUAD_LOG.md coordination. Also use when the user names a goal and asks
  for the full pipeline treatment ("full pipeline on this", "recon-plan-execute-verify").
metadata:
  version: "3.2.0"
  author: "Nick Stafford"
---

# Compute Squad — Squad Manager Protocol (v3)

Run the goal through the pipeline with the v3 role hierarchy:

- **Main session (top-tier model recommended): strategy.** Interrogates the goal, identifies gaps, clarifies them with the user, locks acceptance criteria, renders final judgment. Runs directly in the main session because only the main session can ask the user questions.
- **Opus: PM.** Plans the work and accepts the deliverable (`squad-pm`, PLAN and ACCEPT modes).
- **Sonnet: execution.** Codebase mapping (`squad-recon`) and implementation (`squad-executor`).
- **Haiku: intern.** Zero-judgment busywork (`squad-mech`).

Coordinate exclusively through `COMPUTE_SQUAD_LOG.md` in the repo root. Full routing rules in `references/routing-rules.md`.

## Stage 0 — Strategy (main session, before anything spawns)

Do this directly in the main session; never delegate it:

1. Interrogate the goal: what outcome is actually wanted, what does done look like, what is out of scope, what could this break, is there a higher-leverage framing of the same problem.
2. Identify gaps: ambiguities, unstated constraints, decisions with irreversible or cost-bearing consequences, conflicts with known project invariants.
3. Clarify gaps WITH THE USER via AskUserQuestion before the pipeline starts. Batch the questions; do not drip them. If the session is clearly unattended, make the most reasonable call per gap, state each assumption explicitly, and proceed.
4. Lock the goal (one sentence) and acceptance criteria (concrete, verifiable). Once locked, no agent may redefine them; changes come back to Stage 0.

## Stage 1 — Archive (squad-mech, Haiku)

Spawn `squad-mech` to archive any non-empty `COMPUTE_SQUAD_LOG.md` to a timestamped file (in `codex-prompts/compute-squad-archive/` if it exists, else `compute-squad-archive/`) and start with an empty active log. Never discard a prior or failed run.

## Stage 2 — Recon (squad-recon, Sonnet)

Spawn `squad-recon` with the locked goal and criteria. It maps files, functions, line ranges, call sites, and invariants, and appends its entry to the log.

## Stage 3 — Plan (squad-pm in PLAN mode, Opus)

Spawn `squad-pm` with mode PLAN. It produces the spec and ordered task breakdown, and classifies execution as MECHANICAL, STANDARD, or COMPLEX.

If the PM logs a named blocker requiring a human decision, return to Stage 0: surface it to the user, resolve, re-lock, continue. Do not guess past it.

## Stage 4 — Execute (squad-executor, Sonnet default)

Route by the PM's classification:

- **MECHANICAL / STANDARD** → spawn `squad-executor` as defined (Sonnet).
- **COMPLEX** → spawn `squad-executor` with an Opus model override.

When unsure, route up: a wrong answer that forces a re-run costs more than the tier difference.

## Stage 5 — Accept (squad-pm in ACCEPT mode, Opus)

Spawn `squad-pm` with mode ACCEPT. Being Opus, it is never weaker than the Sonnet execution it reviews; if the Executor ran on an Opus override, acceptance stays at least at Opus.

- **PASS:** the PM clears the log as its final step. If it flagged the change high-stakes (auth, payments, migrations, privacy, production config), do a final review directly in the main session before declaring the run complete. Then report outcome and evidence to the user.
- **FAIL:** the PM names exactly one stage to re-run (Recon, Plan, or Executor). Re-run that stage and all stages after it with the log intact.

## Intra-stage delegation (the DELEGATE protocol)

The role hierarchy is fractal: every level pushes its own busywork down a tier. Subagents cannot spawn subagents, so the Squad Manager acts as the switchboard:

1. Any stage may end its log entry with a `DELEGATE:` block listing subtasks below its tier, each with an exact procedure and a target tier (`intern` for zero-judgment work, `execution` for tightly-specced Sonnet work).
2. On seeing a `DELEGATE:` block, spawn the requested helpers (`squad-mech` for intern tasks; a Sonnet general-purpose agent for execution tasks), append their results to the log under `## Delegated — <stage>`, then continue the pipeline. If the requesting stage said it needs the results to finish (marked `BLOCKING`), re-spawn that stage to complete its entry with the results in the log.
3. Delegation only flows downward. A stage that wants a higher tier is asking for escalation, not delegation; that goes through the escalation rules.
4. Cap helper fan-out at 5 per stage per run; past that, the stage's scoping is the problem, and it should say so in its entry instead.

Typical uses: Recon delegates bulk file inventories or dependency listings to the intern; the PM delegates boilerplate collection or changelog assembly; the Executor delegates formatting normalization or fixture generation.

## Escalation rules

- Same stage fails twice → escalate that stage one model tier on the third attempt (Sonnet → Opus → flag the user for a top-tier main-session pass) instead of retrying at the same tier.
- Three total FAILs on one run → stop, summarize the log history, and hand back to the user.
- Anything that would change the locked goal or acceptance criteria → back to Stage 0 with the user. Always.

## Audit-grade runs

When the user asks for an audit, adversarial review, or says "be thorough": after execution, fan out parallel Sonnet finder agents across dimensions (runtime integrity, security/privacy, dead code/slop, UI/accessibility, docs drift), then have Opus skeptic passes attempt to refute each finding. Only skeptic-confirmed findings count as FAIL evidence. See `references/routing-rules.md`.

## Hard rules

- Coordination happens only through `COMPUTE_SQUAD_LOG.md`; every stage appends, no stage rewrites history, only a PASSing PM clears it.
- No stage skips: even a one-line change gets Recon and Plan entries (they can be short).
- The Executor never accepts its own work; the PM never writes product code; the intern never makes judgment calls.
- Anti-slop discipline everywhere: YAGNI, stdlib/native first, no speculative abstractions, no scaffolding.
