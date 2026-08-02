---
name: compute-squad
description: >
  This skill should be used when the user asks to "run the squad", "run compute squad",
  "compute squad this", "squad run", or wants a code change executed through the
  Compute Squad delegation pipeline (Strategy → Archive → Recon → Plan → Execute → Accept)
  with COMPUTE_SQUAD_LOG.md coordination. Also use when the user names a goal and asks
  for the full pipeline treatment ("full pipeline on this", "recon-plan-execute-verify").
metadata:
  version: "3.7.0"
  author: "Nick Stafford"
---

# Compute Squad — Squad Manager Protocol (v3)

Run the goal through the pipeline with the v3 role hierarchy:

- **Main session (top-tier model recommended): strategy.** Interrogates the goal, identifies gaps, clarifies them with the user, locks acceptance criteria, renders final judgment. Runs directly in the main session because only the main session can ask the user questions.
- **Opus: PM.** Plans the work and accepts the deliverable (`squad-pm`, PLAN and ACCEPT modes).
- **Haiku: execution on MECHANICAL.** The same executor protocol on the cheapest model (`squad-executor-haiku`).
- **Sonnet: execution.** Codebase mapping (`squad-recon`), implementation (`squad-executor`), and delegated execution-tier subtasks (`squad-helper`).
- **Opus: execution on COMPLEX.** The same executor protocol on the stronger model (`squad-executor-opus`).
- **Haiku: intern.** Zero-judgment busywork (`squad-mech`).

Coordinate exclusively through `COMPUTE_SQUAD_LOG.md` in the repo root. Full routing rules in `references/routing-rules.md`.

## Codex model routing

When this shared skill is loaded by Codex, use the generated definitions in
`codex/agents/` after copying them to `~/.codex/agents/`. Their fixed routing is:

- Main session: `gpt-5.6-sol` at high reasoning.
- PM and COMPLEX execution: `gpt-5.6-sol` at max reasoning.
- Recon, STANDARD execution, and delegated execution: `gpt-5.6-terra` at max reasoning.
- MECHANICAL execution and intern work: `gpt-5.6-luna` at max reasoning.

The Claude agent aliases below remain the source of truth for the Claude package;
the Codex TOML `model` fields are the source of truth for Codex.

## Stage 0 — Strategy (main session, before anything spawns)

Do this directly in the main session; never delegate it:

1. Interrogate the goal: what outcome is actually wanted, what does done look like, what is out of scope, what could this break, is there a higher-leverage framing of the same problem.
2. Identify gaps: ambiguities, unstated constraints, decisions with irreversible or cost-bearing consequences, conflicts with known project invariants.
3. Clarify gaps WITH THE USER via AskUserQuestion before the pipeline starts. Batch the questions; do not drip them. If the session is clearly unattended, make the most reasonable call per gap, state each assumption explicitly, and proceed.
4. Lock the goal (one sentence) and acceptance criteria (concrete, verifiable). Once locked, no agent may redefine them; changes come back to Stage 0.
5. Compose the `## Goal — Locked` entry below, the mandatory first entry of every fresh log. Stage 0 composes it but does not write it — the fresh log doesn't exist yet — so Stage 1 appends it once the archive is done.

```markdown
## Goal — Locked
<timestamp line>
Goal: <one sentence>
Acceptance criteria:
- <concrete, verifiable item>
Out of scope: <items>
Assumptions: <only for unattended runs; otherwise "none">
```

If `COMPUTE_SQUAD_LOG.md` already contains entries for this same goal — read the goal from its `## Goal — Locked` entry, not from memory — offer the user a resume from the last logged entry instead of a fresh run, and archive only if they choose the fresh run.

## Stage 1 — Archive (squad-mech, Haiku)

Spawn `squad-mech` to archive any non-empty `COMPUTE_SQUAD_LOG.md` to a timestamped file in `compute-squad-archive/` in the repo root, and start with an empty active log. Never discard a prior or failed run. After squad-mech reports, append the `## Goal — Locked` entry composed in Stage 0 as the first entry of the fresh log, before spawning Recon.

## Stage 2 — Recon (squad-recon, Sonnet)

Spawn `squad-recon` with the locked goal and criteria. It maps files, functions, line ranges, call sites, and invariants, and appends its entry to the log.

## Stage 3 — Plan (squad-pm in PLAN mode, Opus)

Spawn `squad-pm` with mode PLAN. It produces the spec and ordered task breakdown, and classifies execution as MECHANICAL, STANDARD, or COMPLEX.

If the PM logs a named blocker requiring a human decision, return to Stage 0: surface it to the user, resolve, re-lock, continue. Do not guess past it.

## Stage 4 — Execute (squad-executor, Sonnet default)

Route by the PM's classification:

- **MECHANICAL** → spawn `squad-executor-haiku` (Haiku).
- **STANDARD** → spawn `squad-executor` (Sonnet).
- **COMPLEX** → spawn `squad-executor-opus` (Opus), the same protocol on the stronger model.

When unsure, route up: a wrong answer that forces a re-run costs more than the tier difference.

## Stage 5 — Accept (squad-pm in ACCEPT mode, Opus)

Spawn `squad-pm` with mode ACCEPT. Being Opus, it is never weaker than the Sonnet execution it reviews; if execution ran on `squad-executor-opus`, acceptance stays at Opus.

- **PASS:** the PM appends its PASS entry, archives the full log to `compute-squad-archive/` and verifies the copy, then clears the active log only if the change is not high-stakes. If it flagged the change high-stakes (auth, payments, migrations, privacy, production config), the PM leaves the active log intact: do the final review directly in the main session, then clear the log yourself before declaring the run complete. Report outcome and evidence to the user either way.
- **FAIL:** the PM names exactly one stage to re-run (Recon, Plan, or Executor). Re-run that stage and all stages after it with the log intact.
- **PM — Accept (pending):** the PM needed delegated work before it could decide. Run the `DELEGATE:` block, append the results, and re-spawn the PM in ACCEPT mode for the verdict.

## Intra-stage delegation (the DELEGATE protocol)

The role hierarchy is fractal: every level pushes its own busywork down a tier. Subagents cannot spawn subagents, so the Squad Manager acts as the switchboard:

1. Any stage may end its log entry with a `DELEGATE:` block listing subtasks below its tier, each with an exact procedure and a target tier (`intern` for zero-judgment work, `execution` for tightly-specced Sonnet work).
2. On seeing a `DELEGATE:` block, spawn the requested helpers (`squad-mech` for intern tasks; `squad-helper` for execution tasks). Helpers return their results in their final message; you append those results to the log under `## Delegated — <stage>`, then continue the pipeline. If the requesting stage said it needs the results to finish (marked `BLOCKING`), re-spawn that stage. A re-spawned stage appends a `## <Stage> (cont.)` entry covering only the remainder of its work; the "exactly one entry" rule is per spawn, not per run.
3. Delegation only flows downward. A stage that wants a higher tier is asking for escalation, not delegation; that goes through the escalation rules.
4. Cap helper fan-out at 5 per stage per run; past that, the stage's scoping is the problem, and it should say so in its entry instead.

Typical uses: Recon delegates bulk file inventories or dependency listings to the intern; the PM delegates boilerplate collection or changelog assembly; the Executor delegates formatting normalization or fixture generation.

## Escalation rules

- Same stage fails twice → escalate that stage one model tier on the third attempt (Sonnet → Opus → flag the user for a top-tier main-session pass) instead of retrying at the same tier. For execution, the escalation ladder is `squad-executor-haiku` → `squad-executor` → `squad-executor-opus` (haiku → sonnet → opus); two FAILs at a tier moves execution up one tier.
- Three total FAILs on one run → stop, summarize the log history, and hand back to the user.
- Anything that would change the locked goal or acceptance criteria → back to Stage 0 with the user. Always.

Blockers work the same way from any stage, not just the PM, and all of them use one grammar — a block at the end of a stage's own entry:

```
BLOCKER:
- rerun: <Recon|Plan|Executor>   (or)   needs-human: <the decision required>
- why: <one sentence, with evidence refs>
```

A `rerun:` blocker re-runs that stage and every stage after it, and it counts toward the three-FAIL stop. A `needs-human:` blocker returns to Stage 0: surface it, resolve it with the user, re-lock, continue. Freeform prose blockers are a protocol violation — never guess past a blocker, and never log one outside this grammar.

## Audit-grade runs

When the user asks for an audit, adversarial review, or says "be thorough": after execution, fan out parallel Sonnet finder agents across dimensions (runtime integrity, security/privacy, dead code/slop, UI/accessibility, docs drift), then have Opus skeptic passes attempt to refute each finding. Only skeptic-confirmed findings count as FAIL evidence. Use the ready-made briefs in `references/audit-prompts.md` for the five finders and the skeptic; routing and cost posture are in `references/routing-rules.md`.

## Hard rules

- Coordination happens only through `COMPUTE_SQUAD_LOG.md`; every stage appends, no stage rewrites history, and it is cleared only after a PASS: by the PM itself, or by the main session once a high-stakes review is done.
- Every append is a single Bash heredoc (`cat >> COMPUTE_SQUAD_LOG.md <<'EOF' ... EOF`), never a Read-then-Write of the whole file — that race can silently drop entries another stage appended in between. Whole-file `Write` on the active log is legitimate in exactly two places: squad-mech's truncate-after-verified-archive, and the PM's clear-on-PASS.
- Every fresh log opens with a `## Goal — Locked` entry, appended by Stage 1 before Recon spawns. No stage acts on a goal it did not read from that entry.
- No stage skips: even a one-line change gets Recon and Plan entries (they can be short).
- The Executor never accepts its own work; the PM never writes product code; the intern never makes judgment calls.
- Anti-slop discipline everywhere: YAGNI, stdlib/native first, no speculative abstractions, no scaffolding.
