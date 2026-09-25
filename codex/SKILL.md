# Compute Squad: Codex reading copy

Version: 4.2.0
No host loads this file. Claude Code and the Codex plugin both load `skills/compute-squad/SKILL.md`; runtime rules live there. This copy restates it with the Codex model names for readers.

Run the goal through the six-stage pipeline. The main session owns strategy and
human decisions; named Codex agents own the stages after the goal is locked.

## Model routing

<!-- routing:begin -->
Generated from `models.conf` (reviewed 2026-09-24); edit that file, never this table.

| Role | Agent | Rung | Codex model | Effort |
|---|---|---|---|---|
| Strategy and final judgment | main session | top | `gpt-5.6-sol` | `high` |
| Plan and acceptance | `squad-pm` | top | `gpt-5.6-sol` | `max` |
| COMPLEX execution | `squad-executor-complex` | top | `gpt-5.6-sol` | `max` |
| Audit skeptic | none | top | `gpt-5.6-sol` | `max` |
| Recon | `squad-recon` | mid | `gpt-5.6-terra` | `max` |
| STANDARD execution | `squad-executor` | mid | `gpt-5.6-terra` | `max` |
| Delegated execution | `squad-helper` | mid | `gpt-5.6-terra` | `max` |
| Audit finders | none | mid | `gpt-5.6-terra` | `max` |
| MECHANICAL execution | `squad-executor-mechanical` | bottom | `gpt-5.6-luna` | `max` |
| Intern work | `squad-mech` | bottom | `gpt-5.6-luna` | `max` |
<!-- routing:end -->

Stage headings below name each stage's rung; the table above names each rung's
Codex model and effort.

Before starting, ensure the seven files in `~/.codex/agents/` are installed as
described in `codex/README.md`. If the named roles or their models are
unavailable, stop and report the setup gap instead of improvising a different pipeline.

## Stage 0 — Strategy (main session)

Do this directly in the main session; never delegate it:

1. Interrogate the goal: desired outcome, concrete definition of done, scope,
   risks, and higher-leverage framings.
2. Identify ambiguities, unstated constraints, irreversible or cost-bearing
   decisions, and conflicts with project invariants.
3. Ask the user the batched clarifying questions before the pipeline starts. If
   the session is unattended (the user said so, or request_user_input is
   unavailable, as in `codex exec`), make the smallest reasonable assumptions,
   record them, and write `Attended: no` in the Goal entry. Only this step makes
   assumptions; once the Goal entry is written, only the user changes them. A
   false goal fact that changes what a criterion checks is a `needs-human:`
   blocker.
4. Lock one goal sentence and concrete, verifiable acceptance criteria. No
   later stage may redefine them; changes return here. Changing a command,
   test, or check that a criterion names redefines that criterion. A re-lock
   needs the user: a `## Decision` entry of Type re-lock quoting their words,
   then a new full `## Goal — Locked` entry with a `Supersedes:` line naming
   the prior entry's timestamp. The latest one governs.
5. Compose this mandatory first log entry for Stage 1 to append:

```markdown
## Goal — Locked
Timestamp: <output of date -u +%Y-%m-%dT%H:%M:%SZ>
Run: <UTC date and a slug: lowercase letters, digits, hyphens>
Attended: <yes|no>
Goal: <one sentence>
Acceptance criteria:
- <concrete, verifiable item>
Out of scope: <items>
Assumptions: <only for unattended runs; otherwise "none">
```

If the active log already contains a locked entry for this same goal, offer a
resume from the last logged stage. Archive only when the user chooses a fresh
run.

One active run per worktree. When a new run would start over a non-empty log
whose latest `Next:` line is not `Next: none`, do not spawn the archive, and
append nothing to that log until the user chooses. For the same goal, offer the
resume; a user who chooses a fresh run instead parks or abandons this one.
Otherwise ask the user to resume that run, park it (archive it now, restore it
later), abandon it, or start the new goal in a separate git worktree. Record a
park or abandon as a `## Decision`, then a `## Status` with `Next: none`, then
run Stage 1. An unattended run stops here instead and appends nothing. Restore a
parked run only onto an empty log (`test ! -s COMPUTE_SQUAD_LOG.md && cp
<archive> COMPUTE_SQUAD_LOG.md && cmp <archive> COMPUTE_SQUAD_LOG.md`), then
recompute `Next:` from the resume table as if the park entries were absent and
append a fresh `## Status`; the archive stays.

## Modes, grants, and the Status entry

The first word of a `/squad` request, or the user's own words, sets the mode;
the default is `full`. `full` runs Stages 0 to 5, and the request grants
execution of every plan revision. `plan` runs Stages 0 to 3 and stops with no
product edits. `execute <work order>` continues the run in this worktree: it
records the request as a `## Decision` granting that work order of the
governing plan revision, revalidates, executes and accepts it, and stops. `accept` accepts
an implementation made outside the run against the governing plan revision,
then stops. The governing plan revision is the latest `## PM — Plan` entry with
its `(cont.)` entries; revision r<N> is the plan entry whose `Attempt:` line
reads N, the Nth without `(cont.)`. Resume is not a
mode and grants nothing: it performs the `Next:` action of the latest
`## Status` entry. If stage entries follow that entry, first recompute `Next:`
from `skills/compute-squad/references/resume.md` and append a fresh
`## Status`. If the log has no `## Status`, ask the user what to do next.

Only the main session writes `## Status` and `## Decision` entries; their
templates are in the shared skill. Stage 1 appends the first `## Status` with
the Goal entry, and the main session appends another after every stage entry
and decision; a re-lock decision gets its `## Status` after the new Goal entry
that directly follows it. A `## Decision` quotes the user's own words and never
records an assumption; `plan-approved` never grants execution. Spawn an
executor only when the latest `## Status` grants the plan revision and work
order about to run. A new plan revision voids a grant made for an earlier
one, except in `full` mode. Never ask for a grant the log already records. A
grant covers only the work orders it names: after their verdict, append a
`## Status` and stop. No Codex hook enforces this: an `## Executor` entry with
no granting `## Status` above it shows in the log.

## Resume and handoff

When the active log is non-empty at invocation, or the user says resume, read
`skills/compute-squad/references/resume.md` and route by its next-action table
before any spawn. A resumed or handed-over session continues the same run: it
never runs Stage 1 on that log, and FAILs logged by earlier sessions count
toward the three-FAIL stop. Before any executor spawn, it checks the working
tree for edits no entry explains and compares the `Base:` commit with `HEAD`.

The latest `## Status` is the handoff record. To hand the run to another
session or host, append a `## Status` whose `Next:` names the action and who
performs it (for example `Next: execute WO-2 in Claude Code, then accept in
Codex`) and whose `Stop:` names where the receiving session ends, then stop.
When `Next:` hands over acceptance, it also names the tree to accept as
`<commit SHA>, working tree <clean | N changed files>`. The receiving session
takes the allowed scope and required checks from the plan attempt the latest
`## Status` names.

## Stage 1 — Archive (`squad-mech`, bottom rung)

When this invocation starts a new run, spawn `squad-mech` to archive a non-empty
`COMPUTE_SQUAD_LOG.md` with the archive command in the shared skill's Hard
rules: it names the copy under `compute-squad-archive/` from `date -u` and the
run ID, never overwrites an existing archive, verifies the copy with `cmp`, and
only then empties the active log. If the log does not exist, it creates an empty
one. After squad-mech reports an archive path or an already-empty log, append
the Stage 0 locked-goal entry and the first `## Status` in one command, before
Recon starts. If it reports `ARCHIVE FAILED` or `ARCHIVE REFUSED`, append
nothing, give the user its message, and stop.

Never discard a prior or failed run. The only clear before a PASS is the
verified archive procedure here.

## Stage 2 — Recon (`squad-recon`, mid rung)

Spawn `squad-recon` with the locked goal and criteria. It is read-only except
for its one append to the log. It maps exact files, functions, line ranges,
call sites, tests, migrations, config, invariants, risks, and unresolved
ambiguities for the PM.

## Stage 3 — Plan (`squad-pm`, top rung, PLAN mode)

Spawn `squad-pm` in PLAN mode after Recon logs. It reads the locked goal and
Recon entry, produces the exact implementation spec and ordered task list, and
classifies execution as MECHANICAL, STANDARD, or COMPLEX. It never writes
product code. Product-level, irreversible, or cost-bearing decisions become a
`BLOCKER:` with `needs-human:` for the main session.

## Stage 4 — Execute

Check the grant, then route by the `Classification:` line of the governing
plan revision, never by the PM's final message. A missing line, or any other
value, routes as COMPLEX:

- MECHANICAL -> spawn `squad-executor-mechanical` (bottom rung).
- STANDARD -> spawn `squad-executor` (mid rung).
- COMPLEX -> spawn `squad-executor-complex` (top rung).

Each executor reads the complete log and implements exactly the plan revision
and work order the latest `## Status` names, then stops. It does not improvise
around an incomplete plan; it appends a `BLOCKER:` naming Plan when the plan is
wrong or under-classified. The executor never accepts its own work.

## Stage 5 — Accept (`squad-pm`, top rung, ACCEPT mode)

Spawn `squad-pm` in ACCEPT mode after execution. It reads the goal alone first
and the Executor's entries last, reruns the project's verification commands,
checks every invariant and must-not-change item, and attempts a refutation for
every acceptance criterion. When execution ran on the top rung (COMPLEX work, or
after escalation), acceptance shares that rung, and four controls stand in for
the missing one: ACCEPT is a fresh spawn that never saw the Executor's working
context, it derives its expectations from the locked criteria before it reads
the Executor's entry, every criterion it marks met is reproduced rather than
inspected, and a high-stakes change still gets the main-session review before
archive.

- **PASS:** append the PASS entry, archive the full log with the archive
  command, which verifies the copy with `cmp`, then clear the active log only
  for a non-high-stakes change. Leave high-stakes logs intact for final
  main-session review, which closes the run with the same archive command.
  That closing archive is the main session's own step, not a stage's work, so
  the hard rule against doing a stage's work does not cover it. A PASS on a
  work order that is not the plan revision's last archives and clears nothing,
  whatever its stakes: append a `## Status` naming the next work order, which
  outside `full` mode needs its own grant. After a high-stakes review of such a
  PASS, the closing archive waits for the PASS on the last work order.
- **FAIL:** append a `## PM — FAIL` entry whose `Rerun:` line names exactly one
  stage (Recon, Plan, or Executor), with evidence. Leave the log intact and
  rerun that stage plus every later stage; each re-run is a new attempt.
- **Accept pending:** append a pending entry and `DELEGATE:` block when
  zero-judgment work is needed before the verdict; run the helper, append its
  result, and respawn the PM.

## Intra-stage delegation

Stages may end their own entry with a `DELEGATE:` block containing exact,
zero-judgment procedures and a target tier: `intern` for `squad-mech`, or
`execution` for `squad-helper`. The main session spawns the requested helpers
(`squad-mech` for intern tasks; `squad-helper` for execution tasks), appends
their results under `## Delegated — <stage>`, and re-spawns a blocking
requester, which appends a `(cont.)` entry covering only the remainder of its
work; the one-entry rule is per spawn, not per run. Delegation flows downward
only and is capped at 5 helpers per stage per run.

## Log and escalation rules

- Every stage appends to `COMPUTE_SQUAD_LOG.md`; no stage rewrites history.
- Every append uses one shell heredoc (`cat >> COMPUTE_SQUAD_LOG.md <<'EOF' ...
  EOF`) so concurrent entries cannot be silently dropped.
- Every entry's `Timestamp:` line is the output of `date -u +%Y-%m-%dT%H:%M:%SZ`
  from a Bash call made just before the append, never a typed or estimated
  time; the main session's entries follow the same rule.
- No Codex hook records usage. On Claude Code a plugin hook writes each
  stage's model, elapsed time and tokens to `compute-squad-archive/usage.jsonl`;
  when a Codex run ends or stops, say usage is unavailable and never estimate
  it.
- Every fresh run starts with `## Goal — Locked` and `## Status` after Stage 1
  archives prior state. The log clears only after a PASS on the last work
  order of the governing plan revision and a verified archive.
- A blocker is always:

```
BLOCKER:
- rerun: <Recon|Plan|Executor>   (or)   needs-human: <the decision required>
- why: <one sentence, with evidence refs>
```

- Only `## Recon`, `## PM — Plan`, and `## Executor` may add ` (cont.)`, and
  only for a stage continuing after its own `BLOCKING` `DELEGATE:` block. A
  re-run after a FAIL or a `rerun:` blocker is a new, complete attempt under
  the plain heading. The latest attempt of each stage governs; the next
  `## Status` names the governing plan revision on its `Plan:` line.
- Routing values sit on fixed lines under the `Agent:` line, one value each:
  `Attempt:` on every stage entry (a plan's attempt is its revision); `Plan:`
  on Executor entries; `Classification:` and `High-stakes:` on PM Plan
  entries; `Rerun:` on PM FAIL entries. Route and count from these lines and
  from `- rerun:` blocker lines, never from prose. A run is high-stakes once
  any line reads `High-stakes: yes`; no later entry lowers it.
- Count FAILs from the log: the FAIL total is the number of lines matching
  `^(Rerun: |- rerun: )`.
- A FAIL is charged to the stage its `Rerun:` or `- rerun:` line names, not to
  the stage that wrote it, and counts once toward the three-FAIL stop.
- The named stage's next attempt runs one rung above its previous attempt:
  bottom to mid, mid to top. A stage already on the top rung re-runs there.
  Stages that re-run only because they follow the named stage keep their rung.
- Execution runs on the higher of the latest plan's classification rung and the
  rung escalation has reached: `squad-executor-mechanical` (bottom),
  `squad-executor` (mid), `squad-executor-complex` (top). Within the three-FAIL
  stop, execution reaches the top rung from any classification.
- Recon escalates by model, not by agent. In Claude Code, spawn `squad-recon`
  with the Agent tool's `model` parameter set to the next rung's alias from the
  routing block. In Codex an agent's pinned model takes precedence over a spawn
  argument, so Recon re-runs on its own rung. Plan runs on the top rung and
  re-runs there.
- Three total FAILs on one run → stop, summarize the log history, and hand back
  to the user.
- Anything that changes the locked goal, criteria, or assumptions returns to
  Stage 0 and the user. A `needs-human:` blocker stops the pipeline: spawn no
  stage until it is resolved. With the user present, resolve it with them,
  record the re-lock, and re-spawn the stage that raised it. Unattended, do not
  resolve it yourself: append a `## Status` entry whose `Stop:` quotes the
  blocker and whose `Next:` names the stage to re-spawn, leave the log intact,
  and end the run. Never tell a stage the run is unattended.

## Audit-grade runs

When the user asks for an audit or says `be thorough`, after execution fan out
parallel mid-rung finders across runtime integrity, security/privacy, dead code,
accessibility, and docs drift. Use a fresh top-rung pass to refute each finding;
only findings that survive refutation count as acceptance failures.

## Hard rules

No stage skips within a mode. No executor acceptance. No PM product-code edits.
No intern judgment calls. The orchestrating session spawns the named agent for
every stage and never does a stage's work (archive, map, plan, execute, accept)
itself in that agent's place. If a stage's named agent is not installed on this
host, stop and report the setup gap instead of running a different pipeline.
Every stage entry's `Agent:` line names the agent that wrote it, so an absorbed
stage shows in the log. Keep diffs minimal, use existing project conventions,
and stop at every `needs-human:` blocker.

If a spawn fails because its model is unavailable to the account, stop and
report the setup gap with the spawn's error text. Never run that stage on a
lower rung, with a different agent, or in the main session.
