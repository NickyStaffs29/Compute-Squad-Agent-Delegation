---
name: compute-squad
description: >
  This skill should be used when the user asks to "run the squad", "run compute squad",
  "compute squad this", "squad run", or wants a code change executed through the
  Compute Squad delegation pipeline (Strategy → Archive → Recon → Plan → Execute → Accept)
  with COMPUTE_SQUAD_LOG.md coordination. Also use when the user names a goal and asks
  for the full pipeline treatment ("full pipeline on this", "recon-plan-execute-accept").
metadata:
  version: "4.2.0"
  author: "Nick Stafford"
---

# Compute Squad Protocol (v3)

Run the goal through the pipeline with the v3 role hierarchy. Each role runs on a rung of the host's model ladder (top, mid, bottom); the generated routing block below is the only place this skill names models.

- **Main session (top rung recommended): strategy.** Interrogates the goal, identifies gaps, clarifies them with the user, locks acceptance criteria, renders final judgment. Runs directly in the main session because only the main session can ask the user questions.
- **PM, top rung.** Plans the work and accepts the deliverable (`squad-pm`, PLAN and ACCEPT modes).
- **Recon, mid rung.** Maps the codebase (`squad-recon`).
- **Execution, one rung per classification.** The same executor protocol under three names: `squad-executor-mechanical` (bottom), `squad-executor` (mid), `squad-executor-complex` (top).
- **Delegated work.** Tightly-specced execution subtasks (`squad-helper`) and zero-judgment busywork (`squad-mech`, the intern, bottom rung).

Coordinate exclusively through `COMPUTE_SQUAD_LOG.md` in the repo root.

## Model routing

<!-- routing:begin -->
Generated from `models.conf` (reviewed 2026-09-24); edit that file, never this block.
Rungs (Claude alias, Codex ID): top `fable`, `gpt-5.6-sol`; mid `opus`, `gpt-5.6-terra`; bottom `sonnet`, `gpt-5.6-luna`.
- Top: main session, `squad-pm`, `squad-executor-complex`, audit skeptic.
- Mid: `squad-recon`, `squad-executor`, audit finders; in Codex also `squad-helper`.
- Bottom: `squad-executor-mechanical`, `squad-mech`; in Claude Code also `squad-helper`.
Codex effort: `high` for the main session, `max` for every other role. Agent files already pin their models. To spawn on a rung (escalation, finders, skeptic), pass the rung's alias as the Agent tool's `model` in Claude Code; in Codex a named agent keeps its pinned model, so pass the rung's ID and effort only for finders and the skeptic.
<!-- routing:end -->

## Stage 0 — Strategy (main session, before anything spawns)

Do this directly in the main session; never delegate it:

1. Interrogate the goal: what outcome is actually wanted, what does done look like, what is out of scope, what could this break, is there a higher-leverage framing of the same problem.
2. Identify gaps: ambiguities, unstated constraints, decisions with irreversible or cost-bearing consequences, conflicts with known project invariants.
3. Clarify gaps WITH THE USER via the host's question mechanism (AskUserQuestion in Claude; request_user_input in Codex) before the pipeline starts. Batch the questions; do not drip them. If the session is unattended (the user said so, or the question mechanism is unavailable in this session), make the most reasonable call per gap, state each assumption explicitly, write `Attended: no` in the Goal entry, and proceed. This step is the only place an unattended run makes assumptions: once the Goal entry is written, only the user changes them. Recon reports a false goal fact in its entry; one that changes what a criterion checks is a `needs-human:` blocker.
4. Lock the goal (one sentence) and acceptance criteria (concrete, verifiable). Once locked, no agent may redefine them; changes come back to Stage 0. Changing a command, test, or check that an acceptance criterion names counts as redefining that criterion. A re-lock needs the user: in one Bash command, append a `## Decision` entry of Type re-lock quoting their words, then a new `## Goal — Locked` entry with the full template and a `Supersedes: <timestamp of the prior Goal entry>` line. The latest `## Goal — Locked` entry governs; no other entry amends the goal, criteria, or assumptions.
5. Compose the `## Goal — Locked` entry below, the mandatory first entry of every fresh log. Stage 0 composes it but does not write it — the fresh log doesn't exist yet — so Stage 1 appends it once the archive is done.

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

If `COMPUTE_SQUAD_LOG.md` already contains entries for this same goal — read the goal from its latest `## Goal — Locked` entry, not from memory — offer the user a resume from the last logged entry instead of a fresh run, and archive only if they choose the fresh run.

One active run per worktree. When a new run would start over a non-empty log whose latest `Next:` line is not `Next: none`, do not spawn the archive. Append nothing to that log until the user chooses. If it is this same goal, offer the resume above; a user who chooses a fresh run instead parks or abandons this one. Otherwise ask the user to resume that run, park it (archive it now, restore it later), abandon it, or start the new goal in a separate git worktree. Record a park or abandon as a `## Decision`, then a `## Status` with `Next: none`, then run Stage 1. An unattended run stops here instead and appends nothing. To resume a parked run, restore it only onto an empty log: `test ! -s COMPUTE_SQUAD_LOG.md && cp <archive> COMPUTE_SQUAD_LOG.md && cmp <archive> COMPUTE_SQUAD_LOG.md`, then recompute `Next:` from the resume table as if the park entries were absent and append a fresh `## Status`. The archive stays.

## Modes, grants, and the Status entry

Every invocation has one mode: the first word of a `/squad` request, or what the user's own words ask for. The default is `full`.

- `full`: Stages 0 to 5. The request is the execution grant for every plan revision and work order of this run.
- `plan`: Stages 0 to 3, then stop. A plan-mode run succeeds with a plan in the log and no product edits.
- `execute <work order>`: continue the run in this worktree. The request grants that work order of the governing plan revision: record it as a `## Decision`, then revalidate, execute it, accept it, and stop.
- `accept`: accept an implementation made outside this run against the governing plan revision, then stop.

The governing plan revision is the latest one (Hard rules). Revision r<N> is the `## PM — Plan` entry whose `Attempt:` line reads N, the Nth such entry without ` (cont.)`, which is how the grant hook counts. A plan that does not split its tasks into work orders is one work order, `all`.

Resume is not a mode and grants nothing: it performs the `Next:` action of the latest `## Status` entry. If stage entries follow that entry, first recompute `Next:` from `references/resume.md` and append a fresh `## Status`. If the log has no `## Status`, ask the user what to do next.

Only the main session writes `## Status` and `## Decision`. Stage 1 appends the Goal entry and the first `## Status` in one command. After that, append a `## Status` after every stage entry and every `## Decision`, and before you stop, except after a PASS that cleared the log and at the stops that append nothing: the one-active-run rule's, an `ARCHIVE FAILED` or `ARCHIVE REFUSED` report, and a resume stop whose state the latest `## Status` already records (`references/resume.md` steps 2 and 3). The latest one is the current state; everything above it is history. Print it with `awk '/^## /{s=($0=="## Status"); if(s) b=""} s{b=b $0 "\n"} END{printf "%s", b}' COMPUTE_SQUAD_LOG.md`. A re-lock `## Decision` gets its `## Status` after the new `## Goal — Locked` entry that directly follows it.

```markdown
## Status
Timestamp: <output of date -u +%Y-%m-%dT%H:%M:%SZ>
Run: <run ID from the Goal entry>
Mode: <full | plan | execute | accept>
Worktree: <repo root path and branch>
Base: <commit SHA the governing plan was mapped against>
Plan: <none | r<N>, work order <ID or all>>
Grant: <none | r<N> <work order or all>, per Decision <timestamp> | all revisions, full-mode request>
Next: <the one permitted next action, or none when the run is closed>
Stop: <where this invocation ends>
```

A `## Decision` entry quotes words the user actually wrote, in the request or in answer to a question. It never records an assumption, so an unattended run can record only the words that started it. When the request itself grants execution, record it this way instead of asking. `plan-approved` never grants execution.

```markdown
## Decision
Timestamp: <output of date -u +%Y-%m-%dT%H:%M:%SZ>
Type: <grant | plan-approved | waiver | re-lock | park | abandon>
Covers: <plan revision and work order, or criterion ID>
User's words: "<verbatim>"
```

Spawn an executor only when the latest `## Status` grants the plan revision and work order about to run. A new plan revision voids a grant made for an earlier one, except in `full` mode. Never ask for a grant the log already records. A grant covers only the work orders it names: after their verdict, append a `## Status` and stop. On Claude Code a PreToolUse hook refuses an executor spawn whose plan revision the latest `## Status` does not grant; on Codex this rule is prose, checked by reading the log.

## Resume and handoff

When `COMPUTE_SQUAD_LOG.md` is non-empty at invocation, or the user says resume, read `references/resume.md` and route by it before any spawn. A resumed or handed-over session continues the same run: it never runs Stage 1 on that log, and FAILs logged by earlier sessions count toward the three-FAIL stop.

The latest `## Status` is the handoff record. To hand the run to another session or host, append a `## Status` whose `Next:` names the action and who performs it (for example `Next: execute WO-2 in Claude Code, then accept in Codex`) and whose `Stop:` names where the receiving session ends, then stop. When `Next:` hands over acceptance, it also names the tree to accept as `<commit SHA>, working tree <clean | N changed files>`. The receiving session takes the allowed scope and required checks from the plan attempt the latest `## Status` names.

## Stage 1 — Archive (squad-mech)

When this invocation starts a new run, spawn `squad-mech` to archive any non-empty `COMPUTE_SQUAD_LOG.md` to a timestamped file in `compute-squad-archive/` in the repo root, and start with an empty active log. Never discard a prior or failed run. After squad-mech reports an archive path or an already-empty log, append the `## Goal — Locked` entry composed in Stage 0 and the first `## Status` in one Bash command, before spawning Recon. If it reports `ARCHIVE FAILED` or `ARCHIVE REFUSED`, append nothing, give the user its message, and stop.

## Stage 2 — Recon (squad-recon)

Spawn `squad-recon` with the locked goal and criteria. It maps files, functions, line ranges, call sites, and invariants, and appends its entry to the log.

## Stage 3 — Plan (squad-pm in PLAN mode)

Spawn `squad-pm` with mode PLAN. It produces the spec and ordered task breakdown, and classifies execution as MECHANICAL, STANDARD, or COMPLEX.

If the PM logs a `needs-human:` blocker, follow the blocker rule under Escalation rules. Do not guess past it.

## Stage 4 — Execute (squad-executor)

Check the grant (Modes, grants, and the Status entry), then route by the `Classification:` line of the governing plan revision, never by the PM's final message. A missing line, or any value other than these three, routes as COMPLEX:

- **MECHANICAL** → spawn `squad-executor-mechanical` (bottom rung).
- **STANDARD** → spawn `squad-executor` (mid rung).
- **COMPLEX** → spawn `squad-executor-complex` (top rung), the same protocol on the strongest rung.

When unsure, route up: a wrong answer that forces a re-run costs more than running the stage one rung higher.

## Stage 5 — Accept (squad-pm in ACCEPT mode)

Spawn `squad-pm` with mode ACCEPT. It runs on the top rung, so it is never below the execution it reviews and is a rung above it by default. When execution ran on the top rung (COMPLEX work, or after escalation), acceptance shares that rung, and four controls stand in for the missing one: ACCEPT is a fresh spawn that never saw the Executor's working context, it derives its expectations from the locked criteria before it reads the Executor's entry, every criterion it marks met is reproduced rather than inspected, and a high-stakes change still gets the main-session review before archive. Its spawn prompt names the mode and the repo root and nothing else: no reading list, no checklist, and no summary of the plan or of the Executor's account.

- **PASS:** the PM appends its PASS entry, archives the full log to `compute-squad-archive/` with the archive command (Hard rules), which verifies the copy with `cmp`, then clears the active log only if the change is not high-stakes. If it flagged the change high-stakes (auth, payments, migrations, privacy, production config), the PM leaves the active log intact: do the final review directly in the main session, then close the run by running the archive command yourself, which archives the log as it then stands and clears it only after `cmp` succeeds, before declaring the run complete. This closing archive is the main session's own step, not a stage's work, so the Hard rule against doing a stage's work yourself does not cover it. Report outcome and evidence to the user either way. A PASS on a work order that is not the last of the governing plan revision archives and clears nothing, whatever its stakes: append a `## Status` naming the next work order, which outside `full` mode needs its own grant. After a high-stakes review of such a PASS, the closing archive waits for the PASS on the last work order.
- **FAIL:** the FAIL entry's `Rerun:` line names exactly one stage (Recon, Plan, or Executor). Re-run that stage and all stages after it with the log intact; each re-run is a new attempt (Hard rules).
- **PM — Accept (pending):** the PM needed delegated work before it could decide. Run the `DELEGATE:` block, append the results, and re-spawn the PM in ACCEPT mode for the verdict.

## Intra-stage delegation (the DELEGATE protocol)

The role hierarchy is fractal: every level pushes its own busywork down a tier. Stages do not spawn agents themselves: no squad agent is given a tool for it, and some hosts disable nested spawning. So the orchestrating session acts as the switchboard:

1. Any stage may end its log entry with a `DELEGATE:` block listing subtasks below its tier, each with an exact procedure and a target tier (`intern` for zero-judgment work, `execution` for tightly-specced work).
2. On seeing a `DELEGATE:` block, spawn the requested helpers (`squad-mech` for intern tasks; `squad-helper` for execution tasks). Helpers return their results in their final message; you append those results to the log under `## Delegated — <stage>`, then continue the pipeline. If a helper refused a step or reports one that did not run as the procedure says, append that report the same way and re-spawn the requesting stage even if its request was not `BLOCKING`; the stage does that step itself or ends its entry with a `BLOCKER:` block. A stage whose request was not `BLOCKING` appends a new, complete entry under its plain heading, never `(cont.)`. If the requesting stage said it needs the results to finish (marked `BLOCKING`), re-spawn that stage. The stage then appends a `(cont.)` entry covering only the remainder of its work (Hard rules); the one-entry rule is per spawn, not per run.
3. Delegation only flows downward. A stage that needs a stronger model ends its entry with a `BLOCKER:` block naming its own stage (`rerun: Recon`, `rerun: Plan`, or `rerun: Executor`); treat it as a FAIL of that stage under the escalation rules. A stage on the top rung asks with `needs-human:` instead.
4. Spawn at most 5 helpers per stage per run, counted from that stage's `## Delegated — <stage>` entries. Never spawn a sixth: append `## Delegated — <stage>` listing each subtask left undone as `not run: helper cap reached`, and re-spawn the stage, which does those subtasks itself under step 2's heading rule.

Typical uses: Recon delegates bulk file inventories or dependency listings to the intern; the PM delegates boilerplate collection or changelog assembly; the Executor delegates formatting normalization or fixture generation.

## Escalation rules

- Count FAILs from the log, never from memory: the FAIL total is the number of lines matching `^(Rerun: |- rerun: )`, and each such line charges one FAIL to the stage it names.
- Escalate a stage only on the PM's COMPLEX classification or under the FAIL rules below, never on vibes.
- A FAIL is charged to the stage its `Rerun:` or `- rerun:` line names, not to the stage that wrote it, and counts once toward the three-FAIL stop.
- The named stage's next attempt runs one rung above its previous attempt: bottom to mid, mid to top. A stage already on the top rung re-runs there. Stages that re-run only because they follow the named stage keep their rung.
- Execution runs on the higher of the latest plan's classification rung and the rung escalation has reached: `squad-executor-mechanical` (bottom), `squad-executor` (mid), `squad-executor-complex` (top). Within the three-FAIL stop, execution reaches the top rung from any classification.
- Recon escalates by model, not by agent. In Claude Code, spawn `squad-recon` with the Agent tool's `model` parameter set to the next rung's alias from the routing block. In Codex an agent's pinned model takes precedence over a spawn argument, so Recon re-runs on its own rung. Plan runs on the top rung and re-runs there.
- Three total FAILs on one run → stop, summarize the log history, and hand back to the user.
- Anything that would change the locked goal, acceptance criteria, or assumptions → back to Stage 0 with the user. Always. With no user present, the run stops (blocker rule below).

Blockers work the same way from any stage, not just the PM, and all of them use one grammar — a block at the end of a stage's own entry:

```
BLOCKER:
- rerun: <Recon|Plan|Executor>   (or)   needs-human: <the decision required>
- why: <one sentence, with evidence refs>
```

A `rerun:` blocker re-runs that stage and every stage after it, and it counts toward the three-FAIL stop. A `needs-human:` blocker stops the pipeline: spawn no stage until it is resolved. If the user can answer in this session, surface it, resolve it with them, record the answer as a re-lock (Stage 0 step 4), and re-spawn the stage that raised it. If the session is unattended, do not resolve it yourself, even when the answer looks obvious: append a `## Status` entry whose `Stop:` quotes the blocker and whose `Next:` names the stage to re-spawn, leave the log intact, and end the run by reporting both. Never tell a stage that the run is unattended or that it should prefer assumptions over a blocker. Freeform prose blockers are a protocol violation: never guess past a blocker, and never log one outside this grammar.

## Audit-grade runs

When the user asks for an audit, adversarial review, or says "be thorough": after execution, fan out parallel finder agents on the mid rung across dimensions (runtime integrity, security/privacy, dead code/slop, UI/accessibility, docs drift), then have skeptic passes on the top rung attempt to refute each finding. In Claude Code, finders and skeptics have no agent file, so pass each rung's alias from the routing block as the Agent tool's `model` parameter. Only skeptic-confirmed findings count as FAIL evidence. Use the ready-made briefs in `references/audit-prompts.md` for the five finders and the skeptic.

## Hard rules

- Coordination happens only through `COMPUTE_SQUAD_LOG.md`; every stage appends, no stage rewrites history, and it is cleared only after a PASS on the last work order of the governing plan revision: by the PM itself, or by the main session once a high-stakes review is done.
- Every append is a single Bash heredoc (`cat >> COMPUTE_SQUAD_LOG.md <<'EOF' ... EOF`), never a Read-then-Write of the whole file — that race can silently drop entries another stage appended in between. Clearing the active log is legitimate in exactly three places, each chained after a successful `cmp` in the archive command below: `squad-mech` at Stage 1, the PM on an ordinary PASS of the last work order, and the main session when it closes a high-stakes run after its review.
- Every archive copy is written by this command and nothing else, in one Bash call. It names the copy from `date -u` and the run ID, refuses to overwrite an existing file (`set -C`), verifies the copy byte for byte with `cmp`, and clears the active log only after `cmp` succeeds. The PM's form inserts `test ! -e "$t" && echo "Archive target: $t" >> COMPUTE_SQUAD_LOG.md && ` at the start of the second line; on a high-stakes PASS it also ends with `echo "archived, log kept: $t"` in place of the clear and its message. An archive file is never overwritten, appended to, or edited once written. If the command does not print `archived and cleared:` (or `archived, log kept:` in the PM's high-stakes form), the agent reports `ARCHIVE FAILED:` and the error; append nothing, report it to the user, and stop.

```bash
run=$(sed -n 's/^Run: //p' COMPUTE_SQUAD_LOG.md | head -n 1); t="compute-squad-archive/COMPUTE_SQUAD_LOG_$(date -u +%Y-%m-%d_%H%M%S)_${run:-norun}.md"
mkdir -p compute-squad-archive && (set -C; cat COMPUTE_SQUAD_LOG.md > "$t") && cmp COMPUTE_SQUAD_LOG.md "$t" && : > COMPUTE_SQUAD_LOG.md && echo "archived and cleared: $t"
```

- Every entry's `Timestamp:` line is the output of `date -u +%Y-%m-%dT%H:%M:%SZ` from a Bash call made just before the append, never a typed or estimated time; the main session's entries follow the same rule.
- On Claude Code a plugin hook appends each subagent's model, elapsed seconds and token counts, plus a running total for the main session, to `compute-squad-archive/usage.jsonl`. When a run ends or stops, print this run's records with `grep '"run":"<run ID>"' compute-squad-archive/usage.jsonl | awk '!/"agent":"main"/ {print} /"agent":"main"/ {m=$0} END {print m}'` and report for each line the agent, model, elapsed seconds, billed input (input + cache_write + cache_read) and output. If no line matches, as in a Codex run, say usage is unavailable; never estimate it.
- Every fresh log opens with a `## Goal — Locked` entry and a `## Status` entry, appended together by Stage 1 before Recon spawns. A re-lock appends another `## Goal — Locked` entry. No stage acts on a goal it did not read from the latest `## Goal — Locked` entry.
- Log entries use only these headings: `## Goal — Locked`, `## Status`, `## Decision`, `## Recon`, `## PM — Plan`, `## Executor`, `## PM — Accept (pending)`, `## PM — PASS`, `## PM — FAIL`, `## Delegated — <stage>`. Only `## Recon`, `## PM — Plan`, and `## Executor` may add ` (cont.)`, and only for a stage continuing after its own `BLOCKING` `DELEGATE:` block; that entry covers only the remainder and extends the stage's latest attempt. Any other heading or suffix is a protocol violation.
- A re-run after a FAIL or a `rerun:` blocker is a new attempt under the plain heading, never `(cont.)`, and complete on its own. The latest attempt of each stage governs; earlier attempts are history no stage acts on. The governing plan revision is the latest `## PM — Plan` entry with its `(cont.)` entries, and the next `## Status` names it on its `Plan:` line.
- Routing values sit on fixed lines at the top of an entry, one value each, in this order under the `Agent:` line: `Attempt:` on every stage entry (a plan's attempt number is its revision); `Plan:` on Executor entries; `Classification:` and `High-stakes:` on PM Plan entries; `Rerun:` on PM FAIL entries. Route and count from these lines and from `- rerun:` blocker lines, never from prose or a final message.
- A run is high-stakes once any line in the log reads `High-stakes: yes`; no later entry lowers it.
- No stage skips within a mode: even a one-line change gets Recon and Plan entries.
- The Executor never accepts its own work; the PM never writes product code; the intern never makes judgment calls.
- Anti-slop discipline everywhere: YAGNI, stdlib/native first, no speculative abstractions, no scaffolding.
- If a spawn fails because its model is unavailable to the account, stop and report the setup gap with the spawn's error text. Never run that stage on a lower rung, with a different agent, or in the main session.
- The orchestrating session spawns the named agent for every stage and never does a stage's work (archive, map, plan, execute, accept) itself in that agent's place. If a stage's named agent is not installed on this host, stop and report the setup gap instead of running a different pipeline. Every stage entry's `Agent:` line names the agent that wrote it, so an absorbed stage shows in the log.
