# Resume

Read this before any spawn when `COMPUTE_SQUAD_LOG.md` is non-empty at invocation or the user says resume. Resuming continues the same run and grants nothing the log does not record.

1. Read the latest `## Goal — Locked` entry, the latest `## Status` entry, and every entry after that Status. If either entry is missing, ask the user what to do next; an unattended run stops. If the request names a different goal, apply the one-active-run rule in SKILL.md instead.
2. Count FAILs over the whole log, including those earlier sessions wrote, by the SKILL.md formula: lines matching `^(Rerun: |- rerun: )`. At three, stop and hand back to the user; append a `## Status` only when none follows the third FAIL.
3. If `Next:` names another host or session and the user's words do not hand that action to this one, report `Next:` and stop. `Next: none` means the run is closed; a new goal starts at Stage 1.
4. If no entry follows the latest `## Status`, perform its `Next:`. Otherwise recompute `Next:` from the last entry that is neither a `## Status` nor a `## Delegated — <stage>` entry, using the first row that matches, and append a fresh `## Status` before acting. A heading's row also covers its `(cont.)` entry. If no row matches, the entry breaks the closed heading list: show it to the user and stop.
5. Before any executor spawn, run the tree check and the base check below. In `accept` mode, the change under review is `git diff <Base>` against the tree the latest `Next:` names.

| Last entry | Next action |
|---|---|
| Ends in a `BLOCKER:` block | `needs-human:` goes to the user as in Escalation rules; an unattended run stops. `rerun:` re-runs the named stage, then every later stage. |
| Ends in a `DELEGATE:` block | If no `## Delegated — <stage>` entry follows it, run the helpers and append their results. Then, if the block is `BLOCKING`, continue or re-spawn that stage to finish (a `(cont.)` entry, or the verdict after a pending entry), as DELEGATE step 2 says; only the session that spawned the stage's agent can continue it, so any other session re-spawns it. If it is not, but a result reports a step `REFUSED:` or `not run:`, re-spawn that stage for a new, complete entry (DELEGATE steps 2 and 4). Otherwise use its heading's row. |
| `## Decision` | Append the `## Status` it implies, then perform that `Next:`. |
| `## Goal — Locked` | Spawn `squad-recon`. After a re-lock that answers a `needs-human:` blocker, re-spawn the stage that raised it instead. |
| `## Recon` | Spawn `squad-pm` in PLAN mode. |
| `## PM — Plan` | In `plan` mode, append a `## Status` whose `Next:` awaits a grant, and stop. Otherwise apply the grant rule and spawn the executor on the higher of the latest `Classification:` line's rung and the rung escalation has reached. |
| `## Executor` | In an audit-grade run, run the audit. Otherwise spawn `squad-pm` in ACCEPT mode. |
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

Base check, when `Base:` names a commit that differs from `git rev-parse HEAD`: run `git diff --name-only <Base> HEAD`. If no listed path is in the governing plan's must-NOT-change list or among the files and tests of the work order about to run, append a `## Status` with the new `Base:` and continue. If any is, spawn `squad-recon` to re-map those paths only, in a new attempt that names the earlier Recon attempt as the map for every other path, then `squad-pm` in PLAN mode for a complete new plan attempt, which needs its own grant unless the mode is `full`.
