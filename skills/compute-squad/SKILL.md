---
name: compute-squad
description: >
  This skill should be used when the user asks to "run the squad", "run compute squad",
  "compute squad this", "squad run", or wants a code change executed through the
  Compute Squad delegation pipeline (Strategy → Archive → Recon → Plan → Execute → Accept)
  with COMPUTE_SQUAD_LOG.md coordination. Also use when the user names a goal and asks
  for the full pipeline treatment ("full pipeline on this", "recon-plan-execute-accept").
metadata:
  version: "4.6.0"
  author: "Nick Stafford"
---

# Compute Squad Protocol (v3)

Keep main-session entries and the final response concise: one evidence record per exact command and one risk/evidence row per applicable risk, without a second prose rendering. Preserve complete criteria, assumptions, decisions and usage reporting. Run the goal through the pipeline with the v3 role hierarchy. Each role runs on a rung of the host's model ladder (top, mid, bottom); the generated routing block below is the only place this skill names models.

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
Codex main session: `gpt-5.6-sol` (chosen separately from the tier models).
- Top: main session, `squad-pm`, `squad-executor-complex`, audit skeptic.
- Mid: `squad-recon`, `squad-executor`, audit finders; in Codex also `squad-helper`.
- Bottom: `squad-executor-mechanical`, `squad-mech`; in Claude Code also `squad-helper`.
Codex effort: `high` for the main session, `max` for every other role. Agent files already pin their models. To spawn on a rung (escalation, finders, skeptic), pass the rung's alias as the Agent tool's `model` in Claude Code; in Codex a named agent keeps its pinned model, so pass the rung's ID and effort only for finders and the skeptic.
<!-- routing:end -->

## Reference loads

Resolve references beside this candidate SKILL.md, never against the project cwd. Read only the marked section needed below; if its markers or complete instructions cannot be loaded, stop and report a setup gap.

| Section | Reference | Load before |
|---|---|---|
| `resume` | `references/resume.md` | any spawn on a non-empty invocation log or explicit resume |
| `decisions` | `references/resume.md` | any Decision append or resolution of a user answer |
| `verdict` | `references/resume.md` | interpreting or reporting any verdict, including an archived PASS |
| `delegation` | `references/resume.md` | acting on a DELEGATE block, helper or continuation |
| `escalation` | `references/resume.md` | acting on a FAIL/rerun or resolving a blocker |
| `high-stakes` | `references/audit-prompts.md` | opening any high-stakes PASS evidence, even when Audit is no |

For a section named `section` in its candidate reference path `ref`, read its exact begin/end markers in one Bash call:

```bash
awk -v name="$section" '
$0 == "<!-- " name ":begin -->" { b++; p=1; next }
$0 == "<!-- " name ":end -->" { e++; p=0; next }
p { out=out $0 "\n" }
END { if (b!=1 || e!=1 || p || out !~ /[^[:space:]]/) exit 1; printf "%s", out }
' "$ref"
```

A nonzero exit stops the run. Do not read all supplemental sections on a resume. Audit yes still loads the existing full finder/skeptic procedure at the audit step.

## Stage 0 — Strategy (main session, before anything spawns)

Do this directly in the main session; never delegate it:

1. Interrogate the goal: what outcome is actually wanted, what does done look like, what is out of scope, what could this break, is there a higher-leverage framing of the same problem.
2. Identify gaps: ambiguities, unstated constraints, decisions with irreversible or cost-bearing consequences, conflicts with known project invariants.
3. Clarify gaps WITH THE USER via the host's question mechanism (AskUserQuestion in Claude; request_user_input in Codex) before the pipeline starts. Batch the questions; do not drip them. If the session is unattended (the user said so, or the question mechanism is unavailable in this session), make the most reasonable call per gap, state each assumption explicitly, write `Attended: no` in the Goal entry, and proceed. This step is the only place an unattended run makes assumptions: once the Goal entry is written, only the user changes them. Recon reports a false goal fact in its entry; one that changes what a criterion checks is a `needs-human:` blocker.
4. Lock the goal (one sentence) and acceptance criteria (concrete, verifiable), numbered AC1, AC2, and so on. Once locked, no agent may redefine them; changes come back to Stage 0. Changing a command, test, or check that an acceptance criterion names counts as redefining that criterion. A re-lock needs the user: in one Bash command, append a `## Decision` entry of Type re-lock quoting their words, then a new `## Goal — Locked` entry with the full template and a `Supersedes: <timestamp of the prior Goal entry>` line. The latest `## Goal — Locked` entry governs; no other entry amends the goal, criteria, or assumptions.
5. Set `Audit: yes` when the user requests an audit, adversarial review, or says "be thorough"; otherwise set `Audit: no`. Preserve it on every re-lock. Compose the `## Goal — Locked` entry below, the mandatory first entry of every fresh log. Stage 0 composes it but does not write it — the fresh log doesn't exist yet — so Stage 1 appends it once the archive is done.

```markdown
## Goal — Locked
Timestamp: <output of date -u +%Y-%m-%dT%H:%M:%SZ>
Run: <UTC date and a slug: lowercase letters, digits, hyphens>
Attended: <yes|no>
Audit: <yes|no>
Goal: <one sentence>
Acceptance criteria:
- AC1: <concrete, verifiable item>
Out of scope: <items>
Assumptions: <only for unattended runs; otherwise "none">
```

If `COMPUTE_SQUAD_LOG.md` already contains entries for this same goal — read the goal from its latest `## Goal — Locked` entry, not from memory — offer the user a resume from the last logged entry instead of a fresh run, and archive only if they choose the fresh run.

One active run per worktree. When a new run would start over a non-empty log whose latest `Next:` line is not `Next: none`, do not spawn the archive. Append nothing to that log until the user chooses. If it is this same goal, offer the resume above; a user who chooses a fresh run instead parks or abandons this one. Otherwise ask the user to resume that run, park it (archive it now, restore it later), abandon it, or start the new goal in a separate git worktree. Record a park or abandon as a `## Decision`, then a `## Status` with `Next: none`, then run Stage 1. An unattended run stops here instead and appends nothing. To resume a parked run, restore it only onto an empty log: `test ! -s COMPUTE_SQUAD_LOG.md && cp <archive> COMPUTE_SQUAD_LOG.md && cmp <archive> COMPUTE_SQUAD_LOG.md`, then recompute `Next:` from the resume table as if the park entries were absent and append a fresh `## Status`. The archive stays.

In the first tool round trip, batch the candidate skill read with independent permitted Stage 0 metadata (root log, README, one root listing, named files); do not make a separate skill-only call. If the host already supplied the skill text, do not reread it. Goal lock follows those reads. Stage 0 reads only what finding gaps in the goal needs: the user's request, the project instructions already in context, the README, at most one directory listing, files the user named, and `COMPUTE_SQUAD_LOG.md` for the checks above. It never reads product source to map it, never runs tests or builds, and never lists files or questions for Recon; mapping and the baseline run are Recon's.

## Spawn prompts and routing

Every stage spawn prompt is a pointer of at most 400 characters, in exactly this form:

```
Stage: <Archive|Recon|Plan|Execute|Accept>
Mode: <PLAN|ACCEPT|close|none>
Repo root: <absolute path>
Log: COMPUTE_SQUAD_LOG.md, run <Run of the latest ## Status entry, or none>
Since your last spawn: <new run | first spawn | the headings appended since your last entry>
```

Nothing else goes in it. It never restates, varies, or pre-decides what the agent's own file or the log defines (goal, criteria, assumptions, files or questions to map, entry format, archive name, classification, high-stakes, attendance, blocker policy, verdict), and it never tells a stage to read `CLAUDE.md` or `AGENTS.md`. Two exceptions, with no length bound: a helper spawned for a `DELEGATE:` subtask gets that subtask's exact procedure, copied from the log; an audit finder or skeptic gets its brief from `references/audit-prompts.md`. `Mode: close` is only for `squad-mech`'s closing archive after an upheld high-stakes review; at Stage 1 it gets `Mode: none` and `Since your last spawn: new run`. Anything else a stage needs that neither its file nor the log holds yet, such as the paths a base-check re-map covers (`references/resume.md`), goes on the `Next:` line of a `## Status` you append before the spawn, never in the prompt.

Route from the log, never from a stage's final message. After each log-writing stage spawn returns, run:

```bash
grep -n -E '^(## |DELEGATE:|BLOCKER:|Attempt: |Answers: |Plan: |Classification: |High-stakes: |Rerun: |Result: )' COMPUTE_SQUAD_LOG.md | tail -n 12
```

If a `DELEGATE:` or `BLOCKER:` line follows the newest heading, read that block before doing anything else. Route on those field lines, not on the entry's prose. The grep and any signaled BLOCKER/DELEGATE block are enough after Recon or Executor; do not read their whole map or implementation narrative just to route. After PLAN, read only enough of the governing attempt to establish the work-order identity/order as well as its fixed fields; expand any ambiguous read instead of inferring absence from truncated text. Acceptance and high-stakes review still read every applicable criterion and exact verification command, and the review reads the full diff. Inspect routing, append Status, then spawn sequentially; never parallelize these dependent actions. Stage 1 and closing `squad-mech` archive spawns write no stage entry: use their final archive report and guard, and do not route the empty active log. Read a final message only for what the log cannot hold: the reports of `squad-mech` and `squad-helper`, which write no log entries (Stage 1, DELEGATE step 2), an `ARCHIVE FAILED:` line (Hard rules), and the archive path of a PM that archived and cleared the log, where you read its PASS entry (Stage 5).

## Main-session efficiency

A child completion is a routing event, not a separate reporting turn. After each log-writing stage returns, run the required compact route command once, retain its output while appending Status and preparing the next pointer, and do not repeat the grep or reread unchanged log sections. Do not reread Recon's body after an unblocked route. Batch independent read-only checks into one tool call where the host permits it. When a high-stakes PASS is expected, combine that compact route command with loading the required reference sections, latest Goal, and governing Plan in one tool round trip; route only on the command's output, then derive risks from the Goal before opening PASS evidence. In the next tool round trip, batch the PASS criteria, full base diff, changed source and plan-named callers or stores, status, Decisions, and the plan's exact verification commands. Fetch more only for a specific unanswered risk. Get the timestamp, append the review with a quoted heredoc, and read it back in one sequential tool round trip when the host supports that; inspect the read-back before appending Status. These steps still check every applicable criterion, exact command, and full diff. After squad-mech reports a verified close, do not reread the archive or route the empty log.

Named stage roles already pin their model and effort. Do not spend a separate model-discovery turn or reread the routing block before each spawn; use the generated role pin and stop if the spawn reports that its model is unavailable. For an ad hoc finder or skeptic, pass the configured model and effort in the spawn itself.

On native Codex, `wait_agent` is an event subscription, not a polling loop. Do local routing work before waiting. In a non-interactive `codex exec` run, wait once for the stage with `timeout_ms: 600000`; if the host rejects that value, use its largest supported timeout. In an interactive session, wait at most 60 seconds so the user can steer. After a routine timeout, wait again without listing agents or rereading unchanged state; inspect the agent inventory only when the wait reports an error or there is concrete evidence of a stuck child.

## Modes, grants, and the Status entry

Every invocation has one mode: the first word of a `/squad` request, or what the user's own words ask for. The default is `full`.

- `full`: Stages 0 to 5. The request is the execution grant for every plan revision and work order of this run.
- `plan`: Stages 0 to 3, then stop. A plan-mode run succeeds with a plan in the log and no product edits.
- `execute <work order>`: continue the run in this worktree. The request grants that work order of the governing plan revision: record it as a `## Decision`, then revalidate, execute it, accept it, and stop.
- `accept`: accept an implementation made outside this run against the governing plan revision, then stop.

The governing plan revision is the latest one (Hard rules). Revision r<N> is the `## PM — Plan` entry whose `Attempt:` line reads N, the Nth such entry without ` (cont.)`, which is how the grant hook counts. A plan that does not split its tasks into work orders is one work order, `all`.

Resume is not a mode and grants nothing: it performs the `Next:` action of the latest `## Status` entry. If stage entries follow that entry, first recompute `Next:` from `references/resume.md` and append a fresh `## Status`. If the log has no `## Status`, ask the user what to do next.

Only the main session writes `## Status` and `## Decision`. Stage 1 appends the Goal entry and the first `## Status` in one command. After that, append a `## Status` after every stage entry and every `## Decision`, and before you stop, except once an archive has cleared the log (an ordinary PASS, or squad-mech's closing archive after an upheld high-stakes review) and at the stops that append nothing: the one-active-run rule's, an `ARCHIVE FAILED` or `ARCHIVE REFUSED` report, an audit whose `git status --porcelain` changed (`references/audit-prompts.md` step 4), and a resume stop whose state the latest `## Status` already records (`references/resume.md` steps 2 and 3). The latest one is the current state; everything above it is history. Print it with `awk '/^## /{s=($0=="## Status"); if(s) b=""} s{b=b $0 "\n"} END{printf "%s", b}' COMPUTE_SQUAD_LOG.md`. A re-lock `## Decision` gets its `## Status` after the new `## Goal — Locked` entry that directly follows it.

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

Only words the user actually wrote form a `## Decision`, never assumptions. `plan-approved` and `resolution` never grant execution. Before recording any Decision or resolving a user answer, load the `decisions` section of `references/resume.md`; it defines the unchanged template and response procedure.

Spawn an executor only when the latest `## Status` grants the plan revision and work order about to run. A scoped `Grant: r<N> <G>, per Decision <T>` grants execution only when N is the governing plan revision, the same `## Status` reads `Plan: r<N>, work order <P>`, and the one `## Decision` with `Timestamp: <T>` comes before that Status and reads `Type: grant` and `Covers: r<N>, work order <D>`, where D is G or `all` and G is P or `all`. No other Decision type grants execution, and only the exact `Grant: all revisions, full-mode request` needs no Decision. A new plan revision voids a grant made for an earlier one, except in `full` mode. Never ask for a grant the log already records. A grant covers only the work orders it names: after their verdict, append a `## Status` and stop. On Claude Code a PreToolUse hook refuses an executor spawn whose plan revision the latest `## Status` does not grant; on Codex this rule is prose, checked by reading the log.

## Resume and handoff

When `COMPUTE_SQUAD_LOG.md` is non-empty at invocation, or the user says resume, read `references/resume.md` and route by it before any spawn. A resumed or handed-over session continues the same run: it never runs Stage 1 on that log, and FAILs logged by earlier sessions count toward the three-FAIL stop.

The latest `## Status` is the handoff record. To hand the run to another session or host, append a `## Status` whose `Next:` names the action and who performs it (for example `Next: execute WO-2 in Claude Code, then accept in Codex`) and whose `Stop:` names where the receiving session ends, then stop. When `Next:` hands over acceptance, it also names the tree to accept as `<commit SHA>, working tree <clean | N changed files>`. The receiving session takes the allowed scope and required checks from the plan attempt the latest `## Status` names.

## Stage 1 — Archive (squad-mech)

When this invocation starts a new run, spawn `squad-mech` to archive any non-empty `COMPUTE_SQUAD_LOG.md` to a timestamped file in `compute-squad-archive/` in the repo root, and start with an empty active log. Never discard a prior or failed run. After squad-mech reports an archive path or an already-empty log, append the `## Goal — Locked` entry composed in Stage 0 and the first `## Status` in one Bash command, before spawning Recon. If it reports `ARCHIVE FAILED` or `ARCHIVE REFUSED`, append nothing, give the user its message, and stop.

## Stage 2 — Recon (squad-recon)

Spawn `squad-recon`; it reads the locked goal and criteria from the log. It maps files, functions, line ranges, call sites, and invariants, and appends its entry to the log. It also checks the evidence prerequisites (the goal's stated facts, one baseline run of the test or verify command, and the tools the criteria's evidence needs) and raises a `needs-human:` blocker when the criteria cannot be met as locked.

## Stage 3 — Plan (squad-pm in PLAN mode)

Spawn `squad-pm` with mode PLAN. It produces the spec and ordered task breakdown, and classifies execution as MECHANICAL, STANDARD, or COMPLEX. It starts from Recon's Checks block, reconciles the plan's counts, marks unverified decisions `Assumed:`, and raises a `needs-human:` blocker before removing existing behavior that no Out of scope line or Decision covers.

If the PM logs a `needs-human:` blocker, follow the blocker rule under Escalation rules. Do not guess past it.

## Stage 4 — Execute (squad-executor)

Check the grant (Modes, grants, and the Status entry), then route by the `Classification:` line of the governing plan revision, never by the PM's final message. A missing line, or any value other than these three, routes as COMPLEX:

- **MECHANICAL** → spawn `squad-executor-mechanical` (bottom rung).
- **STANDARD** → spawn `squad-executor` (mid rung).
- **COMPLEX** → spawn `squad-executor-complex` (top rung), the same protocol on the strongest rung.

When unsure, route up: a wrong answer that forces a re-run costs more than running the stage one rung higher.

## Stage 5 — Accept (squad-pm in ACCEPT mode)

Spawn `squad-pm` with mode ACCEPT. It runs on the top rung, so it is never below the execution it reviews and is a rung above it by default. When execution ran on the top rung (COMPLEX work, or after escalation), acceptance shares that rung, and four controls stand in for the missing one: ACCEPT is a fresh spawn that never saw the Executor's working context, it derives its expectations from the locked criteria before it reads the Executor's entry, every criterion it marks met is reproduced rather than inspected (its criteria block's How column), and a high-stakes change still gets the main-session review before archive. Its spawn prompt is the pointer (Spawn prompts and routing) and nothing else: no reading list, no checklist, and no summary of the plan or of the Executor's account.

- **PASS, ordinary:** when no line in the log reads `High-stakes: yes` and no work orders remain, the PM appends its PASS entry and runs the archive command, which clears the active log only after `cmp` verifies the copy. Report outcome and evidence to the user.
- **PASS, high-stakes:** when any line in the log reads `High-stakes: yes`, the PM appends its PASS entry and archives and clears nothing. Run the high-stakes review below before anything else. The log is archived only after an upheld review is in it.
- **PASS, earlier work order:** a PASS on a work order that is not the last of the governing plan revision archives and clears nothing, whatever its stakes: append a `## Status` naming the next work order, which outside `full` mode needs its own grant. In a high-stakes run that Status follows an upheld review of this PASS, and the closing archive waits for an upheld review of the last work order's PASS.
- **FAIL:** the FAIL entry's `Rerun:` line names exactly one stage (Recon, Plan, or Executor). Re-run that stage and all stages after it with the log intact; each re-run is a new attempt (Hard rules).
- **PM — Accept (pending):** the PM needed delegated work or a user decision before it could decide. Run its `DELEGATE:` block and append the results, or put its `needs-human:` question to the user and record the answer as a `## Decision` followed by a `## Status`; then continue or re-spawn the PM in ACCEPT mode for the verdict (DELEGATE step 2).

Before interpreting or reporting any verdict, load the `verdict` section of `references/resume.md` and read the PM's criteria block (from the archive if it cleared the log). Check every locked criterion, waiver Decision, and regression; PASS means only local acceptance of the tested tree.

### High-stakes review procedure

On every high-stakes PASS, even when `Audit: no`, load the `high-stakes` section of `references/audit-prompts.md` before opening the PASS evidence. Derive risks from the latest Goal first. Run its complete review in the main session, never delegate it; only an upheld final-work-order review permits squad-mech's closing archive.

## Intra-stage delegation (the DELEGATE protocol)

Stages do not spawn agents themselves: no squad agent is given a tool for it. Delegation flows only downward, at most 5 helpers per stage per run. Small counts/listings stay in-stage. On a `DELEGATE:` block, load the `delegation` section of `references/resume.md` before any helper or continuation. Each subtask is one item: `- [<intern|execution>] <exact procedure>; return at most <N> lines.` Each appended result keeps to its subtask's line cap, plus one line saying how the procedure ran and how many lines were cut.

## Escalation rules

Count FAILs from the log, never from memory: the FAIL total is the number of lines matching `^(Rerun: |- rerun: )`, and each such line charges one FAIL to the stage it names. A FAIL is charged to the stage its `Rerun:` or `- rerun:` line names, not to the stage that wrote it, and counts once toward the three-FAIL stop. Three total FAILs on one run → stop, summarize the log history, and hand back to the user. On any FAIL or rerun, load the `escalation` section of `references/resume.md` before selecting a rung or next stage.

A `needs-human:` blocker stops the pipeline: spawn or continue no stage until it is resolved. Changes to locked facts, criteria or assumptions require the user at Stage 0; never guess past a blocker. Before resolving one, load `escalation` and `decisions`. All blockers use this grammar at the end of their stage entry:

```
BLOCKER:
- rerun: <Recon|Plan|Executor>   (or)   needs-human: <the decision required>
- why: <one sentence, with evidence refs>
```

## Audit-grade runs

When the locked Goal reads `Audit: yes`: after execution, fan out parallel finder agents on the mid rung across dimensions (runtime integrity, security/privacy, dead code/slop, UI/accessibility, docs drift), then have skeptic passes on the top rung attempt to refute each finding, for at most 10 findings. In Claude Code, finders and skeptics have no agent file, so pass each rung's alias from the routing block as the Agent tool's `model` parameter. The main session runs the fan-out after execution and before it spawns `squad-pm` in ACCEPT mode, following the procedure in `references/audit-prompts.md`, and records the result in one `## Audit Findings` entry. CONFIRMED and UNREVIEWED findings are FAIL evidence, a NEEDS-HUMAN finding stops for the user, and a REFUTED finding is not evidence. That stop runs through the PM: spawn it in ACCEPT mode as usual, and it rules on every CONFIRMED, UNREVIEWED, and NEEDS-HUMAN finding the entry lists, settles a NEEDS-HUMAN finding only by showing the guard or check that makes it false, and otherwise ends a `## PM — Accept (pending)` entry with a `needs-human:` blocker, which stops the pipeline under the blocker rule. Use the ready-made briefs in `references/audit-prompts.md` for the five finders and the skeptic.

## Hard rules

- Coordination happens only through `COMPUTE_SQUAD_LOG.md`; every stage appends and no stage rewrites history. Exactly two agents clear it, each only after its verified archive: `squad-mech` at Stage 1 and for the closing archive after an upheld high-stakes review, and the PM after an ordinary PASS on the last work order of the governing plan revision.
- Every append is a single Bash heredoc (`cat >> COMPUTE_SQUAD_LOG.md <<'EOF' ... EOF`), never a Read-then-Write of the whole file — that race can silently drop entries another stage appended in between. Clearing the active log is legitimate in exactly two places, each chained after a successful `cmp` in the archive command below: `squad-mech` (Stage 1, and the closing archive after an upheld `## High-stakes review`) and the PM (an ordinary PASS of the last work order).
- Every archive copy is written by this command and nothing else, in one Bash call. It names the copy from `date -u` and the run ID, refuses to overwrite an existing file (`set -C`), verifies the copy byte for byte with `cmp`, and clears the active log only after `cmp` succeeds. The PM's form inserts `{ test ! -e "$t" || { echo "ARCHIVE FAILED: destination exists: $t" >&2; false; }; } && echo "Archive target: $t" >> COMPUTE_SQUAD_LOG.md && ` at the start of the second line. An archive file is never overwritten, appended to, or edited once written. If the command does not print `archived and cleared:`, the agent reports `ARCHIVE FAILED:` and the error; append nothing, report it to the user, and stop.

```bash
run=$(sed -n 's/^Run: //p' COMPUTE_SQUAD_LOG.md | head -n 1); t="compute-squad-archive/COMPUTE_SQUAD_LOG_$(date -u +%Y-%m-%d_%H%M%S)_${run:-norun}.md"
mkdir -p compute-squad-archive && (set -C; cat COMPUTE_SQUAD_LOG.md > "$t") && cmp COMPUTE_SQUAD_LOG.md "$t" && : > COMPUTE_SQUAD_LOG.md && echo "archived and cleared: $t"
```

- Every entry's `Timestamp:` line is the output of `date -u +%Y-%m-%dT%H:%M:%SZ` from a Bash call made just before the append, never a typed or estimated time; the main session's entries follow the same rule.
- On Claude Code a plugin hook appends each subagent's model, elapsed seconds and token counts, plus a running total for the main session, to `compute-squad-archive/usage.jsonl`. An agent continued with SendMessage (DELEGATE step 2) gets a line at each stop, each a running total for that agent. When a run ends or stops, print this run's records with `grep '"run":"<run ID>"' compute-squad-archive/usage.jsonl | awk '{match($0, /"agent_id":"[^"]*"/); k = substr($0, RSTART + 12, RLENGTH - 13); if (!(k in l)) o[++n] = k; l[k] = $0} END {for (i = 1; i <= n; i++) if (o[i] != "main") print l[o[i]]; if ("main" in l) print l["main"]}'`, which keeps the last line for each agent and prints the main session's last, and report for each line the agent, model, elapsed seconds, billed input (input + cache_write + cache_read) and output. Label output a transcript lower bound; a budget ceiling remains unverified unless an authoritative host upper bound proves it. If no line matches, as in a Codex run, say usage is unavailable; never estimate it.
- Every fresh log opens with a `## Goal — Locked` entry and a `## Status` entry, appended together by Stage 1 before Recon spawns. A re-lock appends another `## Goal — Locked` entry. No stage acts on a goal it did not read from the latest `## Goal — Locked` entry.
- Log entries use only these headings: `## Goal — Locked`, `## Status`, `## Decision`, `## Recon`, `## PM — Plan`, `## Executor`, `## PM — Accept (pending)`, `## PM — PASS`, `## PM — FAIL`, `## Delegated — <stage>`, `## High-stakes review`, `## Audit Findings`. Only `## Recon`, `## PM — Plan`, and `## Executor` may add ` (cont.)`, and only for a stage continuing after its own `BLOCKING` `DELEGATE:` block; that entry covers only the remainder and extends the stage's latest attempt. Any other heading or suffix is a protocol violation.
- A re-run after a FAIL, a `rerun:` blocker, or an overturned high-stakes review is a new attempt under the plain heading, never `(cont.)`, and complete on its own. The latest attempt of each stage governs; earlier attempts are history no stage acts on. The governing plan revision is the latest `## PM — Plan` entry with its `(cont.)` entries, and the next `## Status` names it on its `Plan:` line.
- Routing values sit on fixed lines at the top of an entry, one value each, in this order under the `Agent:` line: `Attempt:` on every stage entry (a plan's attempt number is its revision), then `Answers:` from attempt 2; `Plan:` on Executor entries; `Classification:` and `High-stakes:` on PM Plan entries; `High-stakes:` on PM PASS and FAIL entries, followed on a FAIL by `Rerun:`; `Result:`, plus `Rerun:` when overturned, on high-stakes reviews. Route and count from these lines and from `- rerun:` blocker lines, never from prose or a final message.
- A run is high-stakes once any line in the log reads `High-stakes: yes`; no later entry lowers it.
- No stage skips within a mode: even a one-line change gets Recon and Plan entries.
- The Executor never accepts its own work; the PM never writes product code; the intern never makes judgment calls.
- Anti-slop discipline everywhere: YAGNI, stdlib/native first, no speculative abstractions, no scaffolding.
- If a spawn fails because its model is unavailable to the account, stop and report the setup gap with the spawn's error text. Never run that stage on a lower rung, with a different agent, or in the main session.
- The orchestrating session spawns the named agent for every stage and never does a stage's work (archive, map, plan, execute, accept) itself in that agent's place. If a stage's named agent is not installed on this host, stop and report the setup gap instead of running a different pipeline. Every stage entry's `Agent:` line names the agent that wrote it, so an absorbed stage shows in the log.
