---
name: compute-squad
description: >
  This skill should be used when the user asks to "run the squad", "run compute squad",
  "compute squad this", "squad run", or wants a code change executed through the
  Compute Squad delegation pipeline (Strategy → Archive → Recon → Plan → Execute → Accept)
  with COMPUTE_SQUAD_LOG.md coordination. Also use when the user names a goal and asks
  for the full pipeline treatment ("full pipeline on this", "recon-plan-execute-accept").
metadata:
  version: "3.11.0"
  author: "Nick Stafford"
---

# Compute Squad Protocol (v3)

Run the goal through the pipeline with the v3 role hierarchy. Each role runs on a rung of the host's model ladder (top, mid, bottom); the routing block below is the only place this skill names models.

- **Main session (top rung recommended): strategy.** Interrogates the goal, identifies gaps, clarifies them with the user, locks acceptance criteria, renders final judgment. Runs directly in the main session because only the main session can ask the user questions.
- **PM, top rung.** Plans the work and accepts the deliverable (`squad-pm`, PLAN and ACCEPT modes).
- **Recon, mid rung.** Maps the codebase (`squad-recon`).
- **Execution, one rung per classification.** The same executor protocol under three names: `squad-executor-haiku` (bottom), `squad-executor` (mid), `squad-executor-opus` (top).
- **Delegated work.** Tightly-specced execution subtasks (`squad-helper`) and zero-judgment busywork (`squad-mech`, the intern, bottom rung).

Coordinate exclusively through `COMPUTE_SQUAD_LOG.md` in the repo root.

## Model routing

<!-- routing:begin -->
Rungs (Claude alias, Codex ID): top `opus`, `gpt-5.6-sol`; mid `sonnet`, `gpt-5.6-terra`; bottom `haiku`, `gpt-5.6-luna`.
- Top: main session, `squad-pm`, `squad-executor-opus`, audit skeptic.
- Mid: `squad-recon`, `squad-executor`, `squad-helper`, audit finders.
- Bottom: `squad-executor-haiku`, `squad-mech`.
Codex effort: `high` for the main session, `max` for every squad agent. Agent files already pin their models.
<!-- routing:end -->

When this shared skill is loaded by Codex, use the generated definitions in
`codex/agents/` after copying them to `~/.codex/agents/`. The Claude agents'
`model:` aliases remain the source of truth for the Claude package; the Codex
TOML `model` fields are the source of truth for Codex.

## Stage 0 — Strategy (main session, before anything spawns)

Do this directly in the main session; never delegate it:

1. Interrogate the goal: what outcome is actually wanted, what does done look like, what is out of scope, what could this break, is there a higher-leverage framing of the same problem.
2. Identify gaps: ambiguities, unstated constraints, decisions with irreversible or cost-bearing consequences, conflicts with known project invariants.
3. Clarify gaps WITH THE USER via the host's question mechanism (AskUserQuestion in Claude; request_user_input in Codex) before the pipeline starts. Batch the questions; do not drip them. If the session is clearly unattended, make the most reasonable call per gap, state each assumption explicitly, and proceed.
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

## Stage 1 — Archive (squad-mech)

Spawn `squad-mech` to archive any non-empty `COMPUTE_SQUAD_LOG.md` to a timestamped file in `compute-squad-archive/` in the repo root, and start with an empty active log. Never discard a prior or failed run. After squad-mech reports an archive path or an already-empty log, append the `## Goal — Locked` entry composed in Stage 0 as the first entry of the fresh log, before spawning Recon. If it reports `ARCHIVE FAILED`, append nothing, give the user its message, and stop.

## Stage 2 — Recon (squad-recon)

Spawn `squad-recon` with the locked goal and criteria. It maps files, functions, line ranges, call sites, and invariants, and appends its entry to the log.

## Stage 3 — Plan (squad-pm in PLAN mode)

Spawn `squad-pm` with mode PLAN. It produces the spec and ordered task breakdown, and classifies execution as MECHANICAL, STANDARD, or COMPLEX.

If the PM logs a named blocker requiring a human decision, return to Stage 0: surface it to the user, resolve, re-lock, continue. Do not guess past it.

## Stage 4 — Execute (squad-executor)

Route by the PM's classification:

- **MECHANICAL** → spawn `squad-executor-haiku` (bottom rung).
- **STANDARD** → spawn `squad-executor` (mid rung).
- **COMPLEX** → spawn `squad-executor-opus` (top rung), the same protocol on the strongest rung.

When unsure, route up: a wrong answer that forces a re-run costs more than running the stage one rung higher.

## Stage 5 — Accept (squad-pm in ACCEPT mode)

Spawn `squad-pm` with mode ACCEPT. It runs on the top rung, so it is never below the execution it reviews and is a rung above it by default; if execution ran on `squad-executor-opus`, acceptance shares the top rung. Its spawn prompt names the mode and the repo root and nothing else: no reading list, no checklist, and no summary of the plan or of the Executor's account.

- **PASS:** the PM appends its PASS entry, archives the full log to `compute-squad-archive/` with the archive command (Hard rules), which verifies the copy with `cmp`, then clears the active log only if the change is not high-stakes. If it flagged the change high-stakes (auth, payments, migrations, privacy, production config), the PM leaves the active log intact: do the final review directly in the main session, then close the run by running the archive command yourself, which archives the log as it then stands and clears it only after `cmp` succeeds, before declaring the run complete. This closing archive is the main session's own step, not a stage's work, so the Hard rule against doing a stage's work yourself does not cover it. Report outcome and evidence to the user either way.
- **FAIL:** the PM names exactly one stage to re-run (Recon, Plan, or Executor). Re-run that stage and all stages after it with the log intact.
- **PM — Accept (pending):** the PM needed delegated work before it could decide. Run the `DELEGATE:` block, append the results, and re-spawn the PM in ACCEPT mode for the verdict.

## Intra-stage delegation (the DELEGATE protocol)

The role hierarchy is fractal: every level pushes its own busywork down a tier. Stages do not spawn agents themselves: no squad agent is given a tool for it, and some hosts disable nested spawning. So the orchestrating session acts as the switchboard:

1. Any stage may end its log entry with a `DELEGATE:` block listing subtasks below its tier, each with an exact procedure and a target tier (`intern` for zero-judgment work, `execution` for tightly-specced work).
2. On seeing a `DELEGATE:` block, spawn the requested helpers (`squad-mech` for intern tasks; `squad-helper` for execution tasks). Helpers return their results in their final message; you append those results to the log under `## Delegated — <stage>`, then continue the pipeline. If a helper refused a step or reports one that did not run as the procedure says, append that report the same way and re-spawn the requesting stage even if its request was not `BLOCKING`; the stage does that step itself or ends its entry with a `BLOCKER:` block. A stage whose request was not `BLOCKING` appends a new, complete entry under its plain heading, never `(cont.)`. If the requesting stage said it needs the results to finish (marked `BLOCKING`), re-spawn that stage. A re-spawned stage appends a `## <Stage> (cont.)` entry covering only the remainder of its work; the "exactly one entry" rule is per spawn, not per run.
3. Delegation only flows downward. A stage that needs a stronger model ends its entry with a `BLOCKER:` block naming its own stage (`rerun: Recon`, `rerun: Plan`, or `rerun: Executor`); treat it as a FAIL of that stage under the escalation rules. A stage on the top rung asks with `needs-human:` instead.
4. Spawn at most 5 helpers per stage per run, counted from that stage's `## Delegated — <stage>` entries. Never spawn a sixth: append `## Delegated — <stage>` listing each subtask left undone as `not run: helper cap reached`, and re-spawn the stage, which does those subtasks itself under step 2's heading rule.

Typical uses: Recon delegates bulk file inventories or dependency listings to the intern; the PM delegates boilerplate collection or changelog assembly; the Executor delegates formatting normalization or fixture generation.

## Escalation rules

- Escalate a stage only on the PM's COMPLEX classification or under the FAIL rules below, never on vibes.
- Same stage fails twice → escalate that stage one rung on the third attempt (mid → top → flag the user for a top-tier main-session pass) instead of retrying on the same rung. For execution, the escalation ladder is `squad-executor-haiku` → `squad-executor` → `squad-executor-opus` (bottom → mid → top); two FAILs at a tier moves execution up one tier.
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

When the user asks for an audit, adversarial review, or says "be thorough": after execution, fan out parallel finder agents on the mid rung across dimensions (runtime integrity, security/privacy, dead code/slop, UI/accessibility, docs drift), then have skeptic passes on the top rung attempt to refute each finding. In Claude Code, finders and skeptics have no agent file, so pass each rung's alias from the routing block as the Agent tool's `model` parameter. Only skeptic-confirmed findings count as FAIL evidence. Use the ready-made briefs in `references/audit-prompts.md` for the five finders and the skeptic.

## Hard rules

- Coordination happens only through `COMPUTE_SQUAD_LOG.md`; every stage appends, no stage rewrites history, and it is cleared only after a PASS: by the PM itself, or by the main session once a high-stakes review is done.
- Every append is a single Bash heredoc (`cat >> COMPUTE_SQUAD_LOG.md <<'EOF' ... EOF`), never a Read-then-Write of the whole file — that race can silently drop entries another stage appended in between. Clearing the active log is legitimate in exactly three places, each chained after a successful `cmp` in the archive command below: `squad-mech` at Stage 1, the PM on an ordinary PASS, and the main session when it closes a high-stakes run after its review.
- Every archive copy is written by this command and nothing else, in one Bash call. It names the copy from `date -u` and the run ID, refuses to overwrite an existing file (`set -C`), verifies the copy byte for byte with `cmp`, and clears the active log only after `cmp` succeeds. The PM's form inserts `test ! -e "$t" && echo "Archive target: $t" >> COMPUTE_SQUAD_LOG.md && ` at the start of the second line; on a high-stakes PASS it also ends with `echo "archived, log kept: $t"` in place of the clear and its message. An archive file is never overwritten, appended to, or edited once written. If the command does not print `archived and cleared:` (or `archived, log kept:` in the PM's high-stakes form), the agent reports `ARCHIVE FAILED:` and the error; append nothing, report it to the user, and stop.

```bash
run=$(sed -n 's/^Run: //p' COMPUTE_SQUAD_LOG.md | head -n 1); t="compute-squad-archive/COMPUTE_SQUAD_LOG_$(date -u +%Y-%m-%d_%H%M%S)_${run:-norun}.md"
mkdir -p compute-squad-archive && (set -C; cat COMPUTE_SQUAD_LOG.md > "$t") && cmp COMPUTE_SQUAD_LOG.md "$t" && : > COMPUTE_SQUAD_LOG.md && echo "archived and cleared: $t"
```

- Every entry's `Timestamp:` line is the output of `date -u +%Y-%m-%dT%H:%M:%SZ` from a Bash call made just before the append, never a typed or estimated time; the main session's entries follow the same rule.
- Every fresh log opens with a `## Goal — Locked` entry, appended by Stage 1 before Recon spawns. No stage acts on a goal it did not read from that entry.
- Log entries use only these headings: `## Goal — Locked`, `## Recon`, `## PM — Plan`, `## Executor`, `## PM — Accept (pending)`, `## PM — PASS`, `## PM — FAIL`, `## Delegated — <stage>`. Only `## Recon`, `## PM — Plan`, and `## Executor` may add ` (cont.)`. Any other heading or suffix is a protocol violation.
- No stage skips: even a one-line change gets Recon and Plan entries.
- The Executor never accepts its own work; the PM never writes product code; the intern never makes judgment calls.
- Anti-slop discipline everywhere: YAGNI, stdlib/native first, no speculative abstractions, no scaffolding.
- If a spawn fails because its model is unavailable to the account, stop and report the setup gap with the spawn's error text. Never run that stage on a lower rung, with a different agent, or in the main session.
- The orchestrating session spawns the named agent for every stage and never does a stage's work (archive, map, plan, execute, accept) itself in that agent's place. If a stage's named agent is not installed on this host, stop and report the setup gap instead of running a different pipeline. Every stage entry's `Agent:` line names the agent that wrote it, so an absorbed stage shows in the log.
