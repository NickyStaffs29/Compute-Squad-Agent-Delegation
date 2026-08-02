---
name: compute-squad
description: >
  Use when the user asks to run the squad, run compute squad, compute squad this,
  squad run, or wants a code change executed through the Compute Squad delegation
  pipeline (Strategy -> Archive -> Recon -> Plan -> Execute -> Accept) with
  COMPUTE_SQUAD_LOG.md coordination.
metadata:
  version: "3.7.0"
  author: "Nick Stafford"
---

# Compute Squad — Codex Manager Protocol

Run the goal through the six-stage pipeline. The main session owns strategy and
human decisions; named Codex agents own the stages after the goal is locked.

## Model routing

The profiles in `codex/profiles.toml` pin reasoning effort. The agent TOMLs in
`codex/agents/` pin the model tier:

| Role | Agent | Codex model | Effort |
|---|---|---|---|
| Strategy and final judgment | main session | `gpt-5.6-sol` | `high` |
| Plan and acceptance | `squad-pm` | `gpt-5.6-sol` | `max` |
| Recon, standard execution, delegated execution | `squad-recon`, `squad-executor`, `squad-helper` | `gpt-5.6-terra` | `max` |
| COMPLEX execution and escalation | `squad-executor-opus` | `gpt-5.6-sol` | `max` |
| MECHANICAL execution and intern work | `squad-executor-haiku`, `squad-mech` | `gpt-5.6-luna` | `max` |

The `opus`, `sonnet`, and `haiku` suffixes are retained in agent names for
compatibility with the Claude package. The Codex model fields are the source of
truth for Codex routing.

Before starting, ensure the seven files in `~/.codex/agents/` are installed as
described in `codex/README.md`. If the named roles are unavailable, stop and
report the setup gap instead of improvising a different pipeline.

## Stage 0 — Strategy (main session)

Do this directly in the main session; never delegate it:

1. Interrogate the goal: desired outcome, concrete definition of done, scope,
   risks, and higher-leverage framings.
2. Identify ambiguities, unstated constraints, irreversible or cost-bearing
   decisions, and conflicts with project invariants.
3. Ask the user the batched clarifying questions before the pipeline starts. If
   the session is unattended, make the smallest reasonable assumptions and
   record them.
4. Lock one goal sentence and concrete, verifiable acceptance criteria. No
   later stage may redefine them; changes return here.
5. Compose this mandatory first log entry for Stage 1 to append:

```markdown
## Goal — Locked
<timestamp line>
Goal: <one sentence>
Acceptance criteria:
- <concrete, verifiable item>
Out of scope: <items>
Assumptions: <only for unattended runs; otherwise "none">
```

If the active log already contains a locked entry for this same goal, offer a
resume from the last logged stage. Archive only when the user chooses a fresh
run.

## Stage 1 — Archive (`squad-mech`, Luna MAX)

Spawn `squad-mech` to archive a non-empty `COMPUTE_SQUAD_LOG.md` to a timestamped
file under `compute-squad-archive/`, verify the copy, and leave a fresh empty
active log. If the log does not exist, it creates an empty one. Append the
Stage 0 locked-goal entry after the archive and before Recon starts.

Never discard a prior or failed run. The only whole-file clear before a PASS is
the verified archive procedure here.

## Stage 2 — Recon (`squad-recon`, Terra MAX)

Spawn `squad-recon` with the locked goal and criteria. It is read-only except
for its one append to the log. It maps exact files, functions, line ranges,
call sites, tests, migrations, config, invariants, risks, and unresolved
ambiguities for the PM.

## Stage 3 — Plan (`squad-pm`, Sol MAX, PLAN mode)

Spawn `squad-pm` in PLAN mode after Recon logs. It reads the locked goal and
Recon entry, produces the exact implementation spec and ordered task list, and
classifies execution as MECHANICAL, STANDARD, or COMPLEX. It never writes
product code. Product-level, irreversible, or cost-bearing decisions become a
`BLOCKER:` with `needs-human:` for the main session.

## Stage 4 — Execute

Route exactly by the PM classification:

- MECHANICAL -> `squad-executor-haiku` (Luna MAX).
- STANDARD -> `squad-executor` (Terra MAX).
- COMPLEX -> `squad-executor-opus` (Sol MAX).

Each executor reads the complete log and implements exactly the PM plan. It
does not improvise around an incomplete plan; it appends a `BLOCKER:` naming
Plan when the plan is wrong or under-classified. The executor never accepts its
own work.

## Stage 5 — Accept (`squad-pm`, Sol MAX, ACCEPT mode)

Spawn `squad-pm` in ACCEPT mode after execution. It re-derives expectations
from the locked criteria before reading the Executor account, reruns the
project's verification commands, checks every invariant and must-not-change
item, and attempts a refutation for every acceptance criterion.

- **PASS:** append the PASS entry, copy and verify the full log to the named
  archive target, then clear the active log only for a non-high-stakes change.
  Leave high-stakes logs intact for final main-session review.
- **FAIL:** append evidence and exactly one stage to rerun (Recon, Plan, or
  Executor). Leave the log intact and rerun that stage plus every later stage.
- **Accept pending:** append a pending entry and `DELEGATE:` block when
  zero-judgment work is needed before the verdict; run the helper, append its
  result, and respawn the PM.

## Intra-stage delegation

Stages may end their own entry with a `DELEGATE:` block containing exact,
zero-judgment procedures and a target tier: `intern` for `squad-mech`, or
`execution` for `squad-helper`. The main session runs helpers, appends their
results under `## Delegated — <stage>`, and respawns a blocking requester.
Delegation flows downward only and is capped at five helpers per stage per run.

## Log and escalation rules

- Every stage appends to `COMPUTE_SQUAD_LOG.md`; no stage rewrites history.
- Every append uses one shell heredoc (`cat >> COMPUTE_SQUAD_LOG.md <<'EOF' ...
  EOF`) so concurrent entries cannot be silently dropped.
- Every fresh run starts with `## Goal — Locked` after Stage 1 archives prior
  state. The log clears only after a PASS and verified archive.
- A blocker is always:

```text
BLOCKER:
- rerun: <Recon|Plan|Executor>   (or)   needs-human: <decision required>
- why: <one sentence with evidence refs>
```

- The same stage failing twice escalates one model tier on the third attempt.
  Three total FAILs stop the run and return the full history to the user.
- Anything that changes the locked goal or criteria returns to Stage 0.

## Audit-grade runs

When the user asks for an audit or says `be thorough`, after execution fan out
parallel Terra finders across runtime integrity, security/privacy, dead code,
accessibility, and docs drift. Use a fresh Sol pass to refute each finding;
only findings that survive refutation count as acceptance failures.

## Hard rules

No stage skips. No executor acceptance. No PM product-code edits. No intern
judgment calls. Keep diffs minimal, use existing project conventions, and stop
at every `needs-human:` blocker.
