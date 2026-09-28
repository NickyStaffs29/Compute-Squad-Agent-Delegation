<!-- resume:begin -->
# Resume

Read this before any spawn when `COMPUTE_SQUAD_LOG.md` is non-empty at invocation or the user says resume. Resuming continues the same run and grants nothing the log does not record.

1. Read the latest `## Goal — Locked` entry, the latest `## Status` entry, and every entry after that Status. If either entry is missing, ask the user what to do next; an unattended run stops. If the Goal lacks `Audit: yes` or `Audit: no`, ask the user to record that intent with a re-lock before resuming; an unattended run stops. If the request names a different goal, apply the one-active-run rule in SKILL.md instead.
2. Count FAILs over the whole log, including those earlier sessions wrote, by the SKILL.md formula: lines matching `^(Rerun: |- rerun: )`. At three, stop and hand back to the user; append a `## Status` only when none follows the third FAIL.
3. If `Next:` names another host or session and the user's words do not hand that action to this one, report `Next:` and stop. `Next: none` means the run is closed; a new goal starts at Stage 1.
4. If no entry follows the latest `## Status`, perform its `Next:`. Otherwise recompute `Next:` from the last entry that is neither a `## Status` nor a `## Delegated — <stage>` entry, using the first row that matches, and append a fresh `## Status` before acting. A heading's row also covers its `(cont.)` entry. If no row matches, the entry breaks the closed heading list: show it to the user and stop.
5. Before any executor spawn, run the tree check and the base check below. In `accept` mode, the change under review is `git diff <Base>` against the tree the latest `Next:` names.

| Last entry | Next action |
|---|---|
| Ends in a `BLOCKER:` block | `needs-human:` goes to the user as in Escalation rules; an unattended run stops. `rerun:` re-runs the named stage, then every later stage. |
| Ends in a `DELEGATE:` block | If no `## Delegated — <stage>` entry follows it, run the helpers and append their results. Then, if the block is `BLOCKING`, continue or re-spawn that stage to finish (a `(cont.)` entry, or the verdict after a pending entry), as DELEGATE step 2 says; only the session that spawned the stage's agent can continue it, so any other session re-spawns it. If it is not, but a result reports a step `REFUSED:` or `not run:`, re-spawn that stage for a new, complete entry (DELEGATE steps 2 and 4). Otherwise use its heading's row. |
| `## Decision` | Append the `## Status` it implies, then perform that `Next:`. A stale grant waits for a grant to the governing revision. A resolution preserves the grant and resumes its named blocker or held review, using the grant rule before any executor. |
| `## Goal — Locked` | Spawn `squad-recon`. After a re-lock that answers a `needs-human:` blocker, re-spawn the stage that raised it instead. |
| `## Recon` | Spawn `squad-pm` in PLAN mode. |
| `## PM — Plan` | In `plan` mode, append a `## Status` whose `Next:` awaits a grant, and stop. Otherwise apply the grant rule and spawn the executor on the higher of the latest `Classification:` line's rung and the rung escalation has reached. |
| `## Executor` | In an audit-grade run, run the audit. Otherwise spawn `squad-pm` in ACCEPT mode. Read audit intent from the locked Goal's `Audit:` field. |
| `## Audit Findings` | Spawn `squad-pm` in ACCEPT mode. |
| `## PM — Accept (pending)` | Resolve its `DELEGATE:` block or `needs-human:` question, then spawn `squad-pm` in ACCEPT mode for the verdict. |
| `## PM — FAIL` | Re-run the stage on its `Rerun:` line at the rung the escalation rules give, then every later stage. |
| `## PM — PASS` in a high-stakes run | Run the high-stakes review procedure (Stage 5) before anything else. Never spawn ACCEPT again for this verdict. |
| `## PM — PASS` in any other run | If the governing plan has work orders after this one, append a `## Status` naming the next one and apply the grant rule. Otherwise the PM's archive or clear did not finish: hand back to the user. |
| `## High-stakes review` reading `Result: upheld` | If the governing plan has work orders after the one its PASS accepted, append a `## Status` naming the next one and apply the grant rule. Otherwise spawn `squad-mech` to close the run. |
| `## High-stakes review` reading `Result: held` | Put its open items to the user, record each answer as a `## Decision`, then run a new review. An unattended run stops. |
| `## High-stakes review` reading `Result: overturned` | It counts as a FAIL: re-run the stage on its `Rerun:` line at the rung the escalation rules give, then every later stage. |

A run is high-stakes once any line in the log reads `High-stakes: yes` (Hard rules).

Tree check: run `git status --porcelain`. A listed path other than `COMPUTE_SQUAD_LOG.md` and `compute-squad-archive/` that no `Files changed:` line of this run names, and that no `## Recon` baseline line of this run names after `tree changed:`, means a stage edited files without logging. Show those paths to the user and stop. Never spawn an executor on edits no entry explains.

Base check, when `Base:` names a commit that differs from `git rev-parse HEAD`: run `git diff --name-only <Base> HEAD`. If no listed path is in the governing plan's must-NOT-change list or among the files and tests of the work order about to run, append a `## Status` with the new `Base:` and continue. If any is, spawn `squad-recon` to re-read those paths and affected dependencies, then append a complete updated map, copying unchanged parts from its earlier entry; only the new entry governs, then `squad-pm` in PLAN mode for a complete new plan attempt, which needs its own grant unless the mode is `full`.
<!-- resume:end -->

<!-- decisions:begin -->
## Decisions

A `## Decision` entry quotes words the user actually wrote, in the request or in answer to a question. It never records an assumption, so an unattended run can record only the words that started it. When the request itself grants execution, record it this way instead of asking. `plan-approved` never grants execution. The `## Status` after it keeps the `Grant:` it had (`none` in a plan-mode run), and like every `## Status` it writes `Plan:` and `Grant:` only in the template's form, with any explanation on `Next:` or in prose. A `resolution` quotes the user's answer without changing locked facts or waiving criteria; `Covers:` names the pending blocker or held review as `<heading>, Timestamp: <timestamp>`. It preserves the current grant, then re-spawns the blocked stage (subject to the grant rule) or reruns the held review. A resolution never grants execution.

```markdown
## Decision
Timestamp: <output of date -u +%Y-%m-%dT%H:%M:%SZ>
Type: <grant | plan-approved | waiver | resolution | re-lock | park | abandon>
Covers: <plan revision and work order, criterion ID, or pending heading and Timestamp>
User's words: "<verbatim>"
```
<!-- decisions:end -->

<!-- verdict:begin -->
## Verdict criteria

Every PASS and FAIL entry, and every pending entry that asks the user about a criterion, carries the PM's criteria block, one row per criterion ID in the latest `## Goal — Locked` entry:

```
Tested: <commit SHA>, working tree <clean | N changed files>
| Criterion | Result | How | Evidence |
|---|---|---|---|
| AC1 | met | reproduced | <the check run and the refutation attempted, and what each showed> |
Regressions: <none | defects this change introduced>
Outside scope: <none | defects no criterion covers that also exist on the base commit>
Executor points:
- F1: <the check you ran> -> <what it showed>
```

Before reporting a PASS, read that block (in the archive if the PM cleared the log). If an ID has no row, a row reads anything but `met` or `waived` (or `not checked` for a criterion only a later work order covers), a `waived` row has no matching `## Decision` of Type waiver, or `Regressions:` is not `none`, report the run as not accepted and name the rows. PASS means local acceptance of the tested tree, not PR readiness, merge, deploy, or live verification.
<!-- verdict:end -->

<!-- delegation:begin -->
## Intra-stage delegation (the DELEGATE protocol)

The role hierarchy is fractal: every level pushes its own busywork down a tier. Stages do not spawn agents themselves: no squad agent is given a tool for it, and some hosts disable nested spawning. So the orchestrating session acts as the switchboard:

1. Any stage may end its log entry with a `DELEGATE:` block listing subtasks below its tier, each with an exact procedure, a target tier (`intern` for zero-judgment work, `execution` for tightly-specced work), and the most output lines the helper may return. Delegate only work too large to do in a few commands: a count, a listing, or an inventory of one directory costs less in-stage than the orchestrating session's spawn and append turns, so the stage does it and puts the result in its own entry. Each subtask is one item: `- [<intern|execution>] <exact procedure>; return at most <N> lines.`
2. On seeing a `DELEGATE:` block, spawn the requested helpers (`squad-mech` for intern tasks; `squad-helper` for execution tasks). Helpers return their results in their final message; you append those results to the log under `## Delegated — <stage>`, then continue the pipeline. Each appended result keeps to its subtask's line cap, plus one line saying how the procedure ran and how many lines were cut. If a helper refused a step or reports one that did not run as the procedure says, append that report the same way and re-spawn the requesting stage even if its request was not `BLOCKING` (a `BLOCKING` one is continued as below); the stage does that step itself or ends its entry with a `BLOCKER:` block. A stage whose request was not `BLOCKING` appends a new, complete entry under its plain heading, never `(cont.)`. If the requesting stage marked the block `BLOCKING`, continue that stage's agent with SendMessage (load it through ToolSearch if it is listed only by name) and point it at the new `## Delegated — <stage>` entry, in the pointer form of Spawn prompts and routing; re-spawn the stage only when the host cannot message a finished agent or the message fails. A continued or re-spawned `BLOCKING` requester appends a `## <Stage> (cont.)` entry covering only the remainder of its work (Hard rules); the one-entry rule is per spawn or continuation, not per run.
3. Delegation only flows downward. A stage that needs a stronger model ends its entry with a `BLOCKER:` block naming its own stage (`rerun: Recon`, `rerun: Plan`, or `rerun: Executor`); treat it as a FAIL of that stage under the escalation rules. A stage on the top rung asks with `needs-human:` instead.
4. Spawn at most 5 helpers per stage per run, counted from that stage's `## Delegated — <stage>` entries. Never spawn a sixth: append `## Delegated — <stage>` listing each subtask left undone as `not run: helper cap reached`, and re-spawn the stage (or continue it, as step 2 does for a `BLOCKING` block); it does those subtasks itself under step 2's heading rule.

Typical uses: the Executor delegates regenerating dozens of fixture files from an exact template; the PM delegates assembling a long changelog from many commits; Recon delegates a full-repository inventory. Counts, listings, and single-directory inventories stay in-stage.
<!-- delegation:end -->

<!-- escalation:begin -->
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

The BLOCKER wire grammar is in SKILL.md.

A `rerun:` blocker re-runs that stage and every stage after it, and it counts toward the three-FAIL stop. A `needs-human:` blocker stops the pipeline: spawn or continue no stage until it is resolved. If the user can answer in this session, surface it, resolve it with them, record a re-lock only if locked goal, criteria, or assumptions change (Stage 0 step 4), a waiver for an explicitly waived criterion, or a resolution for any other answer, and re-spawn the stage that raised it. If the session is unattended, do not resolve it yourself, even when the answer looks obvious: append a `## Status` entry whose `Stop:` quotes the blocker and whose `Next:` names the stage to re-spawn, leave the log intact, and end the run by reporting both. Never tell a stage that the run is unattended or that it should prefer assumptions over a blocker. Freeform prose blockers are a protocol violation: never guess past a blocker, and never log one outside this grammar.
<!-- escalation:end -->
