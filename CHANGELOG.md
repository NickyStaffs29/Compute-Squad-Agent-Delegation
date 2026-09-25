# Changelog

## 4.2.0 — 2026-09-24

Lands work order WO-3d of the 3.9.2 analysis: wire format, resume, handoff, and one active run
(finding 9's fixed fields, attempts, and governing-plan pointer, finding 10, and finding 11's
one-active-run rule), plus the seeds and harness scenarios finding 26 needs for them. Stage
entries now carry fixed routing lines, a re-run is a new complete attempt, a resumed session
routes by a written table, and a second run can no longer archive a live one. The archive command
from WO-2 is byte-identical. This release closes the WO-1 `(cont.)` inconsistency, the WO-3c risk
that a PASS on WO-1 cleared a log still holding WO-2, and leftover finding N9 (the resume branch
had no defined routing consequence).

- **Fixed routing lines (finding 9).** A new Hard rule in `skills/compute-squad/SKILL.md` puts
  routing values on fixed lines directly under `Agent:`, one value each: `Attempt:` on every stage
  entry, `Plan: r<N>, work order <ID or all>` on Executor entries, `Classification:` and
  `High-stakes:` on PM Plan entries, and `Rerun:` on PM FAIL entries. The session routes and counts
  from these lines and `- rerun:` blocker lines, never from prose or a final message. A run is
  high-stakes once any line reads `High-stakes: yes`, and no later entry lowers it; PM PASS step 2
  now also runs its high-stakes form when any line reads `High-stakes: yes`. There is no separate
  `Revision:` field: a plan's `Attempt:` number is its revision r<n>, as finding 9 defines it.
  Stage 4 routes by the governing plan's `Classification:` line, and a missing or unknown value
  routes as COMPLEX ("When unsure, route up" stays). The FAIL bullet reads the `Rerun:` line, and
  the first escalation bullet counts FAILs as the lines matching `^(Rerun: |- rerun: )`. The charge
  rule is restored to finding 7's wording: "charged to the stage its `Rerun:` or `- rerun:` line
  names". `codex/SKILL.md` mirrors each rule.
- **Attempts and `(cont.)` (finding 9).** The closed heading list's bullet now says a stage may add
  ` (cont.)` only when continuing after its own `BLOCKING` `DELEGATE:` block, and that entry
  extends the stage's latest attempt. A re-run after a FAIL or a `rerun:` blocker is a new,
  complete attempt under the plain heading, and the latest attempt of each stage governs. DELEGATE
  step 2 points to that rule, which resolves the WO-1 inconsistency: `agents/squad-recon.md`,
  `agents/squad-pm.md`, and the three executor bodies now say the same, with one clause added to
  the report's body sentences ("any other re-spawn also appends a new, complete entry") so they
  match DELEGATE step 2's non-`BLOCKING` case. The re-run sentences drop "or an overturned
  high-stakes review", since that entry is finding 3's (WO-3e). `codex/README.md`'s On FAIL
  paragraph gains "Each re-run is a new, complete entry, never `(cont.)`".
- **The governing plan revision (finding 9).** The sentence WO-3c added to the Modes section now
  points to the Hard rule: the governing revision is the latest `## PM — Plan` entry with its
  `(cont.)` entries, the next `## Status` names it on its `Plan:` line, and revision r<N> is the
  plan whose `Attempt:` line reads N, the Nth without ` (cont.)`, "which is how the grant hook
  counts". `skills/compute-squad/hooks/grant-gate.sh` still counts `^## PM — Plan$` headings, so a
  mislabeled `Attempt:` line cannot move the revision; it gains only a comment.
- **Stage templates (findings 9 and 28 part T).** The PM PLAN template carries `Attempt:`,
  `Classification:`, `High-stakes:`, and `Totals:` under `Agent:`, one classification covers the
  whole revision (any COMPLEX task makes it COMPLEX), and a FAIL or `rerun: Plan` gets a new,
  complete plan classified from scratch. The ACCEPT template gains `Attempt:` (counting PASS and
  FAIL entries; a pending entry takes the number of the verdict it waits for) and `Rerun:
  <Recon|Plan|Executor>`. The report defines no verdict count, and verdicts count over the whole
  log rather than per work order as the Executor's attempts do: finding 9 gives a verdict no
  `Plan:` line, so a per-work-order count would rest on the Status entries between verdicts, while
  the whole-log count is one grep that the linter checks exactly; PASS and pending entries have no
  `Rerun:` line. Recon gains `Attempt:`. The three executors gain `Attempt:` and `Plan:` lines and
  now work only the plan revision and work order the latest `## Status` names, stopping at the end
  of that work order. The generated `codex/02-recon.md` to `codex/05-pm-accept.md` and the matching
  `codex/agents/*.toml` were regenerated.
- **One work order at a time (finding 9, closing WO-3c's risk).** ACCEPT judges only the plan
  revision and work order the latest `## Status` names. PM PASS step 1 stops when the governing
  revision has a later work order: it archives nothing and clears nothing. SKILL.md Stage 5 says
  such a PASS archives and clears nothing whatever its stakes, appends a `## Status` naming the
  next work order (which needs its own grant outside `full` mode), and that a high-stakes closing
  archive waits for the last work order's PASS. The Hard rules now clear the log only after a PASS
  on the last work order. Finding 9's replacement clearing clause is written on finding 3's
  squad-mech closing archive (WO-3e), so only the work-order condition was added to WO-2's three
  clearers, including squad-mech's list of them and the PM's closing sentence ("an ordinary PASS of
  the last work order"). `codex/README.md`'s On PASS, `codex/SKILL.md`'s Stage 5 PASS bullet and
  log rule, and `README.md`'s ACCEPT and executor text say the same.
- **Resume and handoff (finding 10).** New `skills/compute-squad/references/resume.md` holds five
  resume steps, an 11-row next-action table keyed on the last entry that is neither a Status nor a
  Delegated entry, a tree check, and a base check. SKILL.md gains a "Resume and handoff" section: a
  session reads resume.md only when the log is non-empty at invocation or the user says resume,
  never runs Stage 1 on that log, and counts FAILs earlier sessions logged. The latest `## Status`
  is the handoff record; a handover of acceptance names the tree as `<commit SHA>, working tree
  <clean | N changed files>` rather than finding 2's `Tested:` form, which is WO-3e's. Finding 1's
  wording WO-3c had to drop is restored: resume recomputes `Next:` "from `references/resume.md`",
  and the `execute` bullet says "then revalidate, execute it, accept it, and stop". Changes to the
  report's table, each forced by the tree: step 2 appends a Status only when none follows the third
  FAIL; step 4 skips Status entries (WO-3c puts one after every stage entry) and stops on an
  unmatched heading; the DELEGATE row also covers helpers that already ran, and, as DELEGATE steps
  2 and 4 require, re-spawns the stage for a new, complete entry when a result reports a step
  `REFUSED:` or `not run:` even if the block is not `BLOCKING`; the Plan row names the executor's
  rung as the escalation rules do (the higher of the `Classification:` line's rung and the rung
  escalation has reached); the base check's scoped re-map is a new Recon attempt that names the
  earlier attempt as the map for every other path, so the latest-attempt rule does not drop that
  map; the Goal row re-spawns the stage whose `needs-human:` blocker a re-lock answers; the `##
  High-stakes review` and `## Audit Findings` rows are left out (WO-3e and WO-3f), so the PASS rows
  split on whether any line reads `High-stakes: yes`; and the tree check uses the run's Executor
  entries in place of `Files changed:` lines (finding 16, WO-3e). Mirrored in `codex/SKILL.md`, a
  takeover paragraph in `codex/README.md`, `README.md`'s FAQ and repo tree, and the packaged
  `dist/compute-squad.plugin`, which now contains resume.md.
- **One active run per worktree (finding 11).** SKILL.md gains the rule: a new run over a non-empty
  log whose latest `Next:` is not `Next: none` does not spawn the archive, and asks the user to
  resume, park (archive now, restore later), abandon, or use a separate git worktree; a park or
  abandon is recorded as a `## Decision` and a `## Status` with `Next: none`, then Stage 1 runs.
  Additions to the report's text, each reconciling it with the tree: an unattended run stops there
  and appends nothing, so the other run's log is unchanged; nothing is appended to that log until
  the user chooses; a user who declines the same-goal resume for a fresh run parks or abandons the
  open run first, so Stage 0's "archive only if they choose the fresh run" no longer ends in
  `ARCHIVE REFUSED`; and the Status rule's exceptions name the stops that append nothing (the
  one-active-run rule's, as finding 11 notes, an `ARCHIVE FAILED` or `ARCHIVE REFUSED` report, and
  a resume stop whose state the latest `## Status` already records, resume.md steps 2 and 3, so
  S7b's log stays unchanged).
  `codex/SKILL.md` mirrors each but the last, since its Status rule has no before-you-stop clause
  to except these stops from. `agents/squad-mech.md` step 2 opens with finding 11's guard, which
  reads the latest `Next:` line and reports `ARCHIVE REFUSED: open run` without changing anything,
  and Stage 1 in both SKILL.md files and `codex/README.md` stops on `ARCHIVE FAILED` or `ARCHIVE
  REFUSED`. `codex/01-archive.md` and `codex/agents/squad-mech.toml` were regenerated. `README.md`
  gains "one per git worktree" and the park, abandon, or separate-worktree sentence.
- **Mirrors (findings 9, 10, and 11).** `docs/example-log.md` gains Recon `Attempt: 1`, the plan's
  `Attempt:`, `Classification:`, and `High-stakes: yes` lines (the prose drops "Classification:
  STANDARD."), the Executor's `Attempt:` and `Plan:` lines, the PASS's `Attempt: 1`, and its
  closing note says a FAIL has a `Rerun:` line naming exactly one stage. `CONTRIBUTING.md`'s check
  8 sentence names the resume table and the live-scenario setup check. `codex/SKILL.md` mirrors
  each rule, though the report expected it retired, because WO-2 kept it as a reading copy.
- **Check 7 (findings 9, 10, and 11).** In `scripts/verify.sh`, 7i pins the heading bullet's
  `(cont.)` clause word for word and holds every log template in `agents/*.md` and `codex/0*.md` to
  the linter's field table (`tests/check_logs.py --fields`): the exact fixed lines, in order, under
  `Agent:`, and no field line elsewhere; both SKILL.md files must carry the `Classification:` route
  and the FAIL-count formula. 7p's per-spawn row is split in two and gains rows for the executor
  plan read, verdict scope, work-order stop, plan attempt, verdict attempt, classification route,
  FAIL count, and squad-mech's open-run guard (27 rows); its "refused" row now pins `` `REFUSED: ``
  with the backtick, because squad-mech's new `ARCHIVE REFUSED:` text satisfied it and broke its
  one-character self-test. New 7v (the report's 7x, a placeholder its findings 4, 5, 7, 9, 10, and
  others each use for a new check) requires resume.md to be tracked and its table to route from
  every listed heading but Status and Delegated, both SKILL.md files to carry the pointer, the
  one-active-run rule, and the `ARCHIVE REFUSED` stop, SKILL.md to carry the resume-stop Status
  exception, and the guard to be in squad-mech's body, prompt, and TOML.
- **Check 8 (findings 9, 10, 11, and 26).** The log linter gains six rules: `fields`, `attempt`,
  `governing-plan`, `high-stakes`, `cont`, and `next-line`, and exits 2 if SKILL.md loses the
  `(cont.)` clause, a field name, or the high-stakes rule. `next-line` confines `Next:` lines to
  `## Status` entries, which finding 11's guard relies on ("8a confines the field"). One fix beyond
  the report: the heading rule's search for a Delegated entry's requester skips `## Status`
  entries, which WO-3c's Status rule otherwise made reject valid delegations. Every existing
  fixture gained the fields; four re-lock fixtures' `## Recon (cont.)` after a needs-human re-lock
  became a complete `## Recon` with `Attempt: 2`. New passing fixtures: `fail-reruns`,
  `fail-names-plan` (a FAIL naming Plan, then a complete plan with `Attempt: 2`), `plan-cont`,
  `s3`, `s4`, `s7b`, `run-parked`, and `resume-delegate`, `resume-refused`, `resume-helper-cap`,
  `resume-decision`, `resume-relock`, `resume-pending`, `resume-fail`, `resume-fail-plan`; new
  failing fixtures: `fields-prose`, `fail-no-rerun`, `attempt-not-bumped`, `high-stakes-lowered`,
  `cont-after-fail`, `executor-stale-plan`, and `next-outside-status`. New 8b runs
  `tests/resume_next.py` (Python 3.9 stdlib), which reads the table from resume.md, over every
  fixture log's `resume` cases in its `.expect.json`, requires every row, step, and check, and the
  DELEGATE row's refusal case, to be exercised on a log that lints clean, and pins the static twins
  of S1, S2, S2b, S2c, S3a, S3b, S4, S4b, S7b, and the second run. It builds each live scenario's
  repo with `tests/live/run.sh --setup-only` (with a stub `claude` that fails if called) and holds
  its HEAD, dirty paths, and next action to the twin; S2c's twin is now its dirty-tree case, to
  match that setup. It also runs squad-mech's guard, taken from its body, under sh, dash, and bash
  over every fixture log and requires it to refuse exactly where the one-active-run rule does. 8c
  gains cases for a plan whose `Attempt:` line misstates its revision, and verdicts for the `s3`
  (allow), `s4` (deny), and `s7b` (allow) seeds. Check 8a now reports 27 passing and 27 failing
  fixtures, 8b checks 69 resume cases over 54 fixture logs and 162 guard runs, and 8c makes 1535
  grant-hook decisions.
- **The live tier (findings 10, 11, and 26).** `tests/live/run.sh` gains scenarios `s2o` (the
  second run), `s3a`, `s3b`, `s4`, `s4b`, and `s7b`, with new patches
  `tests/live/repo-reset-b-store.patch`, `repo-reset-b-notes.patch`, and
  `repo-reset-wo2-event.patch` that are committed after seeding, and `tests/live/check_live.py`
  gains a check for each; S3a's also requires the new Recon entry to name fewer `src/` files than
  the seed's full map. `check_s2` and `check_s2c` now assert the log is kept and no archive is
  written after WO-1's PASS, and the no-WO-2 check allows a Status whose `Plan:` line names WO-2 as
  the next work order, which Stage 5 now requires. `--list` prints each scenario's seed and
  patches, and node is required only for a live run, so check 8b can build the repos without it.
  The S2c seed's WO-1 PASS no longer has an `Archive target:` line, since it now archives nothing.
- **Not landed, or not run.** No live scenario ran (the run rules forbid it), so these WO-3d
  acceptance items are unverified: S2b, S2c, S3a, S3b, S4, S4b, and S7b passing live. S4's
  assertion that the verdict's `Tested:` line names commit C waits for finding 2 (WO-3e). The
  squad-mech guard was probed with a Haiku main session spawning squad-mech, about $0.21 in total:
  over the open S2 log it reported `ARCHIVE REFUSED` with the log and archive folder unchanged, and
  over `run-parked` it archived and cleared with the copy equal to the log. A full `/squad`
  invocation over an open log, which exercises the main session's park-or-abandon step, was not
  run. Parts of finding 9 left to later work orders: `Answers:` and the ACCEPT template's
  `High-stakes:` and `Tested:` lines and criterion table (WO-3e). Until the ACCEPT line lands, a PM
  that judges a change high-stakes at ACCEPT when the plan's line reads `High-stakes: no` records
  that only in its PASS prose (PM PASS step 2's "or the change IS high-stakes", and Stage 5's "If
  it flagged the change high-stakes"), with no field line behind it; it keeps the log, so a resumed
  session finds no `High-stakes: yes` line, takes the ordinary PASS row, and hands back to the
  user, which fails closed. Also left: `Result:` and a review's `Rerun:` (finding 3, WO-3e), the
  `## High-stakes review` and `## Audit Findings` headings and resume rows (WO-3e and WO-3f), and
  finding 5's route-from-log grep, which is not in the tree (WO-3f). The example log's inline
  "HIGH-STAKES: yes" and "Verdict: PASS." stay until WO-3e.

## 4.1.0 — 2026-09-24

Lands work order WO-3c of the 3.9.2 analysis: modes, execution grants, unattended runs, and the
usage ledger (findings 1, 4, and the ledger part of 21), plus finding 21's Goal-template timestamp
line, which WO-1 could not land, and the live test tier from finding 26 that these scenarios need.
Claude Code gains its first plugin hooks, all declared inline under the `hooks` key of
`.claude-plugin/plugin.json`; there is no root `hooks/hooks.json`, and `.codex-plugin/plugin.json`
still has no `hooks` key. The stage order within a full run is unchanged. This release closes
leftover finding N7 (the example log credited squad-mech with appending the Goal entry).

- **`/squad` takes a mode (finding 1).** `commands/squad.md` reads a first word of `plan`,
  `execute`, or `accept` as the mode, with `full` as the default, and its `argument-hint` is
  `[plan|execute|accept] <goal or work order>`. It tells the session to read the latest
  `## Status` first, run only the stages the mode permits, and never spawn an executor without a
  grant the log records. The `description` line is unchanged.
- **Modes, grants, and the Status entry (finding 1).** `skills/compute-squad/SKILL.md` gains a
  section defining the four modes, the governing plan revision, resume (which grants nothing),
  and the new `## Status` and `## Decision` templates, which only the main session writes. A
  `## Decision` quotes the user's own words, and `plan-approved` never grants execution. An
  executor spawns only when the latest `## Status` grants the plan revision and work order about
  to run. Stage 1 now archives only when the invocation starts a new run, and appends the Goal
  entry and the first `## Status` in one Bash command; it keeps WO-2's `ARCHIVE FAILED` stop.
  Stage 4 checks the grant before routing. The Hard rules say every fresh log opens with a Goal
  and a Status, stages read the latest Goal entry, and no stage skips within a mode. Both new
  headings join the closed heading list (7i now counts 10). Adaptations the tree forced: the
  templates use the `Timestamp:` line, not `<timestamp line>`; the resume sentence does not cite
  `references/resume.md` and the `execute` bullet drops "revalidate", both of which arrive with
  finding 10 in WO-3d; and one added sentence defines revision r<N> as the count of
  `## PM — Plan` entries without ` (cont.)` and a plan with no work orders as work order `all`,
  since finding 9's revision fields are not in the tree yet. WO-3d's governing-plan pointer
  (finding 9) must replace or agree with that sentence in both SKILL.md copies. One sentence
  after the Status rule places a re-lock Decision's `## Status` after the new Goal entry that
  directly follows it, so the Status rule and the re-lock rule agree when read literally.
- **Goal template: Run, Attended, and Timestamp lines (findings 1, 4, and 21).** The Goal
  template in `skills/compute-squad/SKILL.md`, `codex/SKILL.md`, and `codex/README.md` changed
  once, in all three copies, and they stay byte-identical (7a): `<timestamp line>` becomes
  `Timestamp: <output of date -u +%Y-%m-%dT%H:%M:%SZ>` (finding 21's mirror carried over from
  WO-1), then new `Run:` and `Attended: <yes|no>` lines.
- **The grant gate (findings 1 and 4).** New POSIX sh hook
  `skills/compute-squad/hooks/grant-gate.sh` runs on PreToolUse with the matcher `Agent|Task`
  (Claude Code 2.1.282 reports the spawn tool as `Task`). It denies `squad-executor`,
  `squad-executor-mechanical`, and `squad-executor-complex`, with or without the
  `compute-squad:` prefix, unless the latest `## Status` grants the current plan revision or all
  revisions. It also holds every executor and `squad-recon`, `squad-pm`, and `squad-helper`
  while a `needs-human:` blocker has no `## Decision` after it; `squad-mech` stays exempt so
  Stage 1 can archive. Two deviations from finding 4's text: the hold covers any open
  `needs-human:` blocker, not only the last BLOCKER, which matches the linter's rule and fails
  closed; and executors get the grant check before the hold. On Codex the grant rule stays
  prose, checked by reading the log. The hook checks plan revisions, not work orders.
- **Unattended runs and re-locks (finding 4).** In `skills/compute-squad/SKILL.md`, Stage 0
  step 3 defines an unattended session, writes `Attended: no`, and makes that step the only
  place a run makes assumptions; a false goal fact that changes a criterion is a `needs-human:`
  blocker. The sentence does not name Recon's `goal facts:` line, which finding 14 adds in
  WO-3e. Step 4 says changing a command, test, or check that a criterion names redefines the
  criterion, and a re-lock needs the user: in one Bash command, a `## Decision` of Type re-lock
  quoting them, then a new full Goal entry with a `Supersedes:` line; the latest Goal entry
  governs. "In one Bash command" is added to the report's text so the Status-after-every-Decision
  rule does not separate the Decision from its Goal entry. A `needs-human:` blocker now stops
  the pipeline: with the user present, resolve it and re-spawn the stage that raised it;
  unattended, append a `## Status` whose `Stop:` quotes the blocker and end the run. The main
  session never tells a stage the run is unattended. `codex/SKILL.md` mirrors each rule.
- **Stage bodies read the latest Goal (finding 4).** `agents/squad-recon.md`,
  `agents/squad-pm.md`, and the three executor bodies read the goal from the latest
  `## Goal — Locked` entry instead of the entry "at the top of the log". The PM body adds that
  no adjustment is allowed however narrow, the criterion-command sentence, and that whether the
  run is attended never changes what it logs. Each executor gains a STOP bullet: a task that
  would change a criterion's command without the latest Goal stating it ends in a
  `needs-human:` blocker. Recon, which cannot change a command, gets no such sentence. The
  generated `codex/02-recon.md` to `codex/05-pm-accept.md` and the five matching
  `codex/agents/*.toml` were regenerated.
- **The usage ledger (finding 21).** New POSIX sh hook
  `skills/compute-squad/hooks/usage-ledger.sh` runs on SubagentStop and Stop, with no matcher,
  and appends one JSON line per subagent, plus a running total for the main session, to
  `compute-squad-archive/usage.jsonl`. It prints nothing. A SKILL.md Hard rule gives the
  end-of-run command that prints a run's lines and says a run with no lines, as on Codex,
  reports usage as unavailable. One forced change to the report's script: its `field()` helper
  returns a key's first value, not its last, because the SubagentStop payload lists
  `background_tasks` entries with their own `agent_type` after the top-level fields. One
  addition: Claude Code flushes transcript writes every 100 ms, so an agent's final message can
  reach its transcript after SubagentStop fires (a review probe's ledger missed a background
  executor's last call that way), and the script now waits, at most five seconds, while the
  relevant transcript's last assistant record still ends in a tool call or has no stop reason:
  the agent's at SubagentStop, the main session's at Stop. `.gitignore` already covers the
  path.
- **Mirrors (findings 1, 4, and 21).** `codex/README.md` gains a "Modes and grants" paragraph with
  both templates, byte-identical to SKILL.md's, and the re-lock record in its On FAIL paragraph. Its
  manual-fallback step now has the operator append the first `## Status` with the Goal entry.
  `codex/SKILL.md` gains a condensed modes section, though the report expected this file to be
  retired, with the same grant and resume rules as SKILL.md; it says no Codex hook enforces the
  grant. `README.md` gains the Modes paragraph, the unattended-run sentence, the `usage.jsonl` line
  (under the `compute-squad-archive/` bullet) and cost-FAQ sentence, "Resuming never grants
  execution of a shelved plan", and tree lines for `hooks/`, `tests/`, and the `/squad` modes; "Six
  stages run in order, every time" now applies to a full run, and the cost FAQ's five-spawn floor to
  a full run, with three for a plan run. `docs/example-log.md` fixes the Stage 0 line (N7), adds
  `Run:` and `Attended: yes` lines and three `## Status` entries, and names its archive by run ID.
  `CONTRIBUTING.md` lists `skills/compute-squad/hooks/` in the sync list and names both hooks in the
  check 8 sentence.
- **New and extended checks (findings 1, 4, and 21).** In `scripts/verify.sh`: 7f requires the
  `## Status` and `## Decision` templates to be byte-identical in SKILL.md and
  `codex/README.md`; two new 7p rows pin the latest-Goal read across the stage bodies and
  `codex/02` to `05`, and the criterion-command sentence across SKILL.md, the PM, the executors,
  and `codex/03` to `05`; new 7u fails if any tracked file under `agents/`, `codex/`, or
  `skills/` reads the goal from the entry "at the top of the log" (the report's "7x"). 8c pipes
  synthetic PreToolUse JSON into the grant gate under sh, dash, and bash (1412 decisions),
  including a `Grant: r0` line before any plan, runs it over the live seeds (`s1` and `s2b`
  deny, `s2` and `s2c` allow; S2c's zero spawns rest on work-order scope, which 8b covers in
  WO-3d), requires the hook wired once for `Agent` and `Task`, and bans a tracked root
  `hooks/hooks.json`. 8f runs the ledger hook on synthetic transcripts in
  `tests/fixtures/ledger/`: exact token sums, a repeated message ID counted once, a final
  message written 0.5 s after the hook starts (at SubagentStop and at Stop) that the hook waits
  for, silent exit on malformed input, and the end-of-run command.
- **The log linter learns grants, re-locks, and the needs-human stop (findings 1 and 4).**
  `tests/check_logs.py` gains three rules: `grant` runs the gate over the log above every
  Executor entry, `re-lock` requires every later Goal entry to follow a re-lock Decision
  directly with `Attended: yes` and the right `Supersedes:`, and `needs-human` rejects any stage
  entry between an open `needs-human:` blocker and a Decision. The seven fixtures with Executor
  entries gain a Run line and a granting Status. New fixtures under `tests/fixtures/logs/`:
  `plan-shelved`, `execute-granted`, `needs-human-stop`, and `relock-recorded` pass;
  `executor-no-grant`, `executor-stale-grant`, `status-invented`, `relock-self-authorized`,
  `relock-status-between`, `relock-wrong-type`, `relock-unattended`,
  `relock-wrong-supersedes`, and `needs-human-ignored` fail with exactly their rule. Each part
  of the re-lock rule has a fixture that fails it alone: a Status between the re-lock Decision
  and the new Goal entry, a Decision of Type waiver directly above it, `Attended: no`, and the
  wrong `Supersedes:` timestamp. Check 8a now reports 12 passing and 20 failing fixtures.
- **The live tier (finding 26).** New `tests/live/run.sh` and `tests/live/check_live.py` (Python
  3.9 stdlib) run the section 6 scenarios S1, its plain-words variant s1n, S2, S2b, and S2c:
  copy the fixture, commit a base, seed the log, run `claude -p`, then assert spawns by type,
  permission denials, the diff, the log, archive hashes, and ledger billed input within 1% of
  `modelUsage` (output at or below it). It has `--list`, `--dry-run`, and `--setup-only` modes that call no model,
  refuses a live run when `CI` is set, and is never run by `verify.sh`. It adds `Task` to
  `--allowedTools` and unsets inherited Claude session variables. New
  `tests/fixtures/repo-reset/` is an 11-file Node password-reset repo mirroring the example log,
  whose `npm test` passes 6 of 6; `tests/live/repo-reset-wo1.patch` is the WO-1 change S2c
  starts from. Seed logs `s1`, `s2`, `s2b`, and `s2c` in `tests/fixtures/logs/` lint clean.
- **Not landed, or not run.** No live scenario ran (the run rules forbid it), so these WO-3c
  acceptance items are unverified: S1, S2, S2b, and S2c passing live; the grant gate over five
  repeats with a clean `git status --porcelain`; and a reference run's ledger within 1% of
  `modelUsage`. Finding 4's live S5c detection was not run either. The static twin 8b arrives with
  WO-3d. Cheap Haiku probes, about $0.36 in total, did confirm that the gate denies an executor
  spawn with no log and allows it with a granting Status, that the ledger matched `modelUsage`
  exactly on a small run including a resume, and that the harness's CLI flags and result fields
  work. Review probes, about $0.44 more, found the late-flush gap the ledger now waits for, and one
  it cannot close: a message with parallel tool calls, whose transcript records the host writes
  before the stream ends, keeps the output count of its first record (3 where the host counted 193),
  so the ledger's output total can read low while billed input stays exact. The live tier
  therefore holds billed input to 1% of `modelUsage` and output to at most `modelUsage`, and prints
  the output shortfall; a reference run has not measured it. Until finding 9's work-order fields land in
  WO-3d, an ordinary PASS after `/squad execute WO-1` still clears a log that holds WO-2, and S2's
  PM may fail WO-1 over a criterion that belongs to WO-2.

## 4.0.0 — 2026-09-24

Lands work order WO-3b of the 3.9.2 analysis: the locked Claude ladder and Codex model currency.
This is a major version because two agents are renamed: `squad-executor-haiku` is now
`squad-executor-mechanical` and `squad-executor-opus` is now `squad-executor-complex`. Anything
that spawns either by its old name (a script, a saved prompt, a custom command) must use the new
name. To update an existing install, update the Claude Code plugin, which picks up the new agent
files, and run `codex/update.sh`, which removes `squad-executor-haiku.toml` and
`squad-executor-opus.toml` from `$CODEX_HOME/agents/` and installs the renamed TOMLs. The Codex
column of `models.conf` does not change: WO-0 has not been run, so every Codex ID stays
`gpt-5.6-*`. This release closes leftover findings N2 (the top executor was unreachable by
escalation) and N3 (the escalation rule implied a Recon agent on a higher tier that did not exist).

- **The locked Claude ladder (finding 7).** `models.conf`'s Claude column is now bottom `sonnet`,
  mid `opus`, top `fable`, and `squad-helper` moves to the Claude bottom rung while staying on the
  Codex mid rung. The file matches the report's locked manifest byte for byte, and `reviewed`
  stays 2026-09-24, the date of the appendix A alias measurements. The generator rewrote the
  agents' `model:` lines: `fable` for `squad-pm` and `squad-executor-complex`, `opus` for
  `squad-recon` and `squad-executor`, `sonnet` for `squad-executor-mechanical`, `squad-helper`,
  and `squad-mech`. The four generated routing blocks (`skills/compute-squad/SKILL.md`,
  `codex/SKILL.md`, `README.md`, `codex/README.md`) match the report's locked blocks byte for
  byte; SKILL.md's block now lists `squad-helper` on the mid rung in Codex and the bottom rung in
  Claude Code. `codex/profiles.toml` and every Codex model and effort are unchanged.
- **Executors named by classification, not by model (finding 7).** `agents/squad-executor-haiku.md`
  and `agents/squad-executor-opus.md`, and their `codex/agents/*.toml`, were renamed with `git mv`
  to `squad-executor-mechanical` and `squad-executor-complex`; each file's `name:`, example, and
  `Agent:` lines follow. Every tracked file that named them now uses the new names:
  `agents/squad-pm.md` (COMPLEX routes to `squad-executor-complex`), `README.md`,
  `codex/README.md`, `codex/SKILL.md`, `skills/compute-squad/SKILL.md`, the generated
  `codex/03-pm-plan.md` and `codex/agents/squad-pm.toml`, and the executor `Agent:` lines of
  `tests/fixtures/logs/accept-delegation.log.md` and `accept-needs-human.log.md`, which now name
  the bottom-rung model, `claude-sonnet-5`, instead of `claude-haiku-5`. In
  `codex/build-agents.py`, `ROLE_LABELS`, `PROFILES`, and `MANUAL_STAGES` follow (the
  `compute-squad-mechanical` profile keeps its name); in `scripts/verify.sh`, check 6's
  `MECHANICAL` and `COMPLEX` constants and the 7c and 7p path lists follow. The agent
  descriptions keep finding 17's one-example form from 3.10.0 rather than finding 7's longer
  3.9.2-layout text, because finding 17 says phase 3 changes only the example lines.
- **Escalation moves a stage one rung per FAIL (finding 7).** In `skills/compute-squad/SKILL.md`
  and `codex/SKILL.md`, the rule that a stage failing twice escalates one tier is replaced by
  finding 7's bullets: a FAIL is charged to the stage it names and counts once toward the
  three-FAIL stop; the named stage's next attempt runs one rung up, and a top-rung stage re-runs
  there; execution runs on the higher of the plan's classification rung and the rung escalation
  has reached, so it reaches the top rung from any classification within the three-FAIL stop;
  Recon escalates by passing the next rung's alias as the Agent tool's `model` in Claude Code
  and re-runs on its own rung in Codex. The three-FAIL stop is unchanged. One adaptation: the
  charge rule names the stage "its `## PM — FAIL` entry or `- rerun:` line names" where the
  report says a `Rerun:` line, because today's FAIL template has no such line until finding 9
  lands in WO-3d. `codex/README.md`'s On FAIL paragraph states the same rule in finding 7's text.
- **Stage 4 and Stage 5 (finding 7).** SKILL.md's Stage 4 lines spawn the renamed executors with
  finding 7's rung words; finding 8's version of those lines omits the rung words, neither
  finding says it supersedes the other, and finding 7's text stays. Stage 5 gains finding 7's
  parity text in both SKILL.md files: when execution ran on the top rung, acceptance shares it,
  and four named controls stand in for the missing rung. One of them, that every criterion
  ACCEPT marks met is reproduced rather than inspected, anticipates the criterion table in WO-3e.
- **README and CONTRIBUTING (finding 7).** `README.md` gains finding 7's two sentences on where
  the ladder is placed and what it buys, before finding 8's prices sentence from 3.10.0, which
  stays; the executor heading and paragraph, the PLAN-mode paragraph, and the repo tree use the
  new names; the FAQ "Why is Sonnet execution safe?" becomes "Why is bottom-rung execution
  safe?" with finding 7's answer. `CONTRIBUTING.md`'s allowed-model list reads `sonnet`, `opus`,
  or `fable` and keeps finding 17's example-size wording.
- **Check 2 allows the new ladder; new checks 7m and 7t (finding 7).** `ALLOWED_MODELS` in
  `scripts/verify.sh` is `sonnet`, `opus`, `fable`, so a `haiku` rung now fails check 2. New 7m
  requires exactly three tracked `agents/squad-executor*.md` files whose bodies are identical
  once each file's own name is masked, and requires the MECHANICAL under-classification stop
  line exactly once in the mechanical body; that last test goes beyond the report so the line
  (section 3 item 23) cannot be deleted silently. New 7t is the report's ladder-text check
  (labelled 7x there): no tracked file outside `CHANGELOG.md`, `LEFTOVER_FINDINGS.md`,
  `codex/update.sh`, `scripts/verify.sh`, and `dist/` names an old executor, "two FAILs at a
  tier", or "top-tier main-session pass", compared with whitespace collapsed, and both SKILL.md
  files carry the FAIL charge rule and the setup-gap stop.
- **Codex catalog validation (finding 8; finding 6 item 9).** `codex/build-agents.py
  --validate-catalog PATH [--strict]` reads the JSON `codex debug models` prints and checks
  every model and reasoning effort pinned in `codex/agents/*.toml` and `codex/profiles.toml` (11
  pins over 3 models today). It fails, listing the catalog's visible slugs, when a pinned model
  is missing, lacks the pinned effort, or has a past retirement date. It warns when a model is
  superseded, with the report's text, or retires within 30 days, which fails under `--strict`. A
  catalog it cannot read as that format is reported as not validated, never as a pass, and exits
  0, or 1 under `--strict`. One deviation, from measurement: `upgrade.retirement_at` is optional,
  because Codex CLI 0.156.1's `codex debug models` omits it when no retirement is scheduled. On
  that real catalog the validator prints three superseded warnings and no failure, and exits 0
  under `--strict`.
- **The updater checks the catalog before installing (findings 7 and 8).** `codex/update.sh` runs
  `codex debug models` and the validator after `git pull` and before any `codex plugin` command,
  and on a refusal stops with `$CODEX_HOME` unchanged. Without `python3`, an awk and grep fallback
  checks model slugs only and warns that efforts were not validated; if `codex debug models`
  itself fails, the updater warns and proceeds. Its retired list gains
  `squad-executor-haiku.toml` and `squad-executor-opus.toml`.
- **Check 8e covers the catalog and the new prune (findings 7 and 8).** New POSIX sh stub
  `tests/stubs/codex` prints `$STUB_CATALOG` for `debug models`. 8e first runs the updater with a
  stub catalog that lacks one pinned model: it must exit 1, name the model, make no call after
  `codex debug models`, and leave `CODEX_HOME` byte for byte as it was. It then runs with every
  pinned model listed and asserts the prune of all five retired TOMLs, the install, the profiles,
  and the user's files. Last, it runs `--validate-catalog` directly, with and without `--strict`,
  on five stub catalogs that each change one entry: an effort the model lacks, a past retirement,
  a retirement within 30 days, an upgrade target, and an entry with no `upgrade` key. The report
  asks 8e only for the missing model; the other cases pin the validator's remaining rules.
- **Check 9 warns on stale dates (finding 8).** `scripts/verify.sh` check 9 reads `models.conf`'s
  `reviewed` date through `build-agents.py --parse-manifest` and every `Snapshot YYYY-MM-DD` in
  `README.md` and `codex/README.md`. A date over 90 days old prints a warning and never fails;
  the check fails only on a date that is not a calendar date or a manifest that does not parse.
- **Weekly model-currency job (finding 8).** `.github/workflows/ci.yml` gains a Monday 06:00 UTC
  schedule and a `model-currency` job that runs only on it: `verify.sh`, then `npm install -g
  @openai/codex`, `codex debug models --bundled`, and `--validate-catalog --strict`. Section 4
  does not list `ci.yml` for WO-3b; it lands here because it is the only caller of `--strict` and
  check 9's warn-only design relies on it.
- **Hand-written model names become pointers; Codex floor 0.144 (finding 8).** `README.md`'s Codex
  prerequisites (0.144 floor, a pointer to the routing table, the updater's refusal), its FAQ
  "Do the models auto-upgrade?", and its `codex/profiles.toml` tree comment use the report's
  text. `codex/README.md`'s install requirements (0.144 floor), its updater paragraph (the
  catalog check), and its routing sentence use the report's text. The two step-by-step lists of
  what the updater runs, in `README.md`'s update section and `codex/README.md`'s Updating
  section, now include the catalog check between the pull and the plugin commands, and
  `codex/README.md`'s scheduler notes say the check needs `python3` on the scheduler's `PATH`
  to validate efforts. The report gives no text for
  the rest, which now name rungs: `README.md`'s agent headings and tree comments
  (`squad-helper` gets no rung, since its rung differs by host) and its `ci.yml` tree comment;
  `codex/README.md`'s Luna section, renamed "Bottom-rung subagent fallback" and pointing to the
  generated table; and `codex/SKILL.md`, whose suffix and Sol/Terra/Luna shorthand sentences
  become one pointer sentence and whose stage headings, Stage 4 spawn lines, and audit paragraph
  say bottom, mid, or top rung. SKILL.md's intro says "the generated routing block".
- **Changing models (finding 8).** `CONTRIBUTING.md` gains the report's "Changing models"
  procedure, which the validator's superseded warning and the README FAQ point to. Section 4
  does not name it for WO-3b. Two steps are adapted: step 5 rebuilds `dist/` before running
  `verify.sh`, since the report's order fails check 5 whenever an agent's `model:` line changes,
  and step 7 compares each stage's `Agent:` line with `models.conf`, since the live regression
  scenarios and usage ledger it names do not exist until WO-3c.
- **Not landed in this release.**
  - The Codex column and the move to generation 6 wait on WO-0; `codex/profiles.toml`'s
    `0.134+` header stays, as the report says it is still correct.
  - `README.md`'s dated snapshot needed no edit: 3.10.0 already dated the cost FAQ
    `Snapshot 2026-09-24`, and check 9 now watches it.
  - `docs/example-log.md` and the log fixtures under `tests/fixtures/logs/` still show
    old-ladder model IDs on their other `Agent:` lines, such as `claude-sonnet-5` for
    `squad-recon` and `claude-opus-5-5` for `squad-pm`. They are synthetic and the linter does
    not read the ID; finding 21 owns the example log's `Agent:` lines.
- **Acceptance.** The gate passes under the default Python and Python 3.9. In scratch copies, a
  `haiku` rung failed check 2; 7m failed on a deleted MECHANICAL stop line, a one-word change in
  the complex body, and the stop line added to the standard body; 7t failed on an old name in
  docs, a wrapped old phrase, an old name in a fixture, and a missing charge rule; 8e failed when
  the validator call was dropped, moved after `plugin add`, or ignored a missing model, and when
  the validator's effort, past-retirement, near-retirement, upgrade-target, or `--strict` format
  rule was disabled; check 9
  printed warnings for old dates and still passed. Sixteen mutated catalogs behaved as specified
  under Python 3.9. The real-catalog run installed Codex CLI 0.156.1 in a temp prefix and ran
  only `codex debug models`, with no login and no model call. Not run, because each needs a live
  squad run with top- or mid-rung spawns or a logged-in Codex account: regression scenarios S7a
  (its updater refusal is covered statically by 8e) and S7b, the two-FAIL ladder-reach run from
  MECHANICAL, the per-stage model check against the manifest, the unavailable-model stop, and
  the `codex exec` probes. No `claude` CLI call was made.

## 3.12.0 — 2026-09-24

Lands work order WO-3a of the 3.9.2 analysis: the model manifest. It moves where models are named,
not which models run. Every agent, rung, and Codex effort keeps its 3.11.0 assignment, and every
generated file other than the four routing blocks is byte for byte what 3.11.0's generator wrote,
apart from the version string. The one addition is a Codex effort for the audit finders and
skeptic, which 3.11.0 did not give: the report's manifest sets both to `max`. The locked ladder,
the executor renames, and finding 8's pointer rewrites are WO-3b.

- **One manifest names the models (finding 6).** New root file `models.conf` holds a `reviewed`
  date, a `[rung]` table (bottom `haiku` and `gpt-5.6-luna`, mid `sonnet` and `gpt-5.6-terra`, top
  `opus` and `gpt-5.6-sol`), and a `[role]` table that gives each of the seven agents, plus
  `strategy`, `finder`, and `skeptic`, a Claude rung, a Codex rung, and a Codex effort. The values
  are today's assignments. Its header calls it the only file that names models; that is not yet
  fully true, because `README.md`'s Codex prerequisites, agent headings, tree comments, and FAQ,
  `codex/README.md`'s install and Luna sections, and `codex/SKILL.md`'s Sol/Terra/Luna shorthand
  still name models by hand until finding 8's pointers land in WO-3b.
- **The generator writes every routed file from it (finding 6).** `codex/build-agents.py` reads
  `models.conf` with a Python 3.9 stdlib parser that never defaults: it fails, naming the line
  where there is one, on an unknown rung, a duplicate row or section, a missing section or rung
  row, a wrong field count, a line outside a section, or a missing or invalid `reviewed` date. It
  now writes the `model:` line of each `agents/*.md`, the model and effort in each
  `codex/agents/*.toml`, `codex/profiles.toml`, and the four routing blocks, besides the five
  manual prompts, and `--check` covers all 24 files. Codex model and effort are keyed on the agent
  name; `MODEL_BY_TIER`, `TIER_TERMS`, and `translate_tiers` are gone. A model family name or
  `gpt-` ID in an agent description or body now fails the build. Not in the report: a
  `--parse-manifest PATH` mode prints the parsed manifest as JSON so `scripts/verify.sh` uses the
  same parser, and an unknown argument exits 2.
- **Four generated routing blocks (finding 6).** The blocks between `<!-- routing:begin -->` and
  `<!-- routing:end -->` in `skills/compute-squad/SKILL.md`, `codex/SKILL.md`, `README.md`, and
  `codex/README.md` are now written from the manifest; only SKILL.md had markers before. SKILL.md's
  block gains a generated-from line and a sentence on spawning on a rung (the rung's alias as the
  Agent tool's `model` in Claude Code; in Codex, the rung's ID and effort only for finders and the
  skeptic), and the paragraph after it on Codex loading and per-host sources of truth is deleted,
  per the report's replacement range. `codex/SKILL.md`'s table lists each role with its rung and
  adds the audit finder and skeptic rows; its "source of truth" sentence is deleted, and its
  suffix and Sol/Terra/Luna shorthand sentences stay, because the report assumed the file retired
  while WO-2 kept it as a reading copy whose stage headings use the shorthand. `README.md`'s role
  table gives Recon, Execution, and Delegated execution their own rows under a snapshot line, and
  `codex/README.md`'s manual-session table names each model's rung.
- **Check 2 ties each agent to the manifest (finding 6).** `scripts/verify.sh` check 2 requires
  each agent's `model:` to equal the Claude alias `models.conf` assigns its rung, and its failure
  names the agent and says to edit `models.conf` and regenerate. It also requires every Claude
  rung alias in `ALLOWED_MODELS`, which stays `sonnet`, `opus`, `haiku`; the report's swap of
  `haiku` for `fable` belongs to finding 7's ladder in WO-3b.
- **Check 6 tests routing policy, not model IDs (finding 6).** The literal model table and profile
  tuples are gone. Check 6 now requires that the manifest parses; that its roles are the tracked
  agents plus `strategy`, `finder`, and `skeptic`; one TOML per agent; three different models per
  host; the PM on the top rung on both hosts; MECHANICAL below STANDARD below COMPLEX, with the PM
  above STANDARD and at or above every executor, and the skeptic above the finders; only the
  MECHANICAL executor, `squad-helper`, and `squad-mech` on the Claude bottom rung; and every effort
  in `low`, `medium`, `high`, `xhigh`, `max`. It also feeds the parser four malformed copies (a
  missing column, which the report names, plus an unknown rung, a duplicate row, and a missing
  section) and fails if any parses. Each policy holds for today's assignments and for WO-3b's
  ladder, so none waits on WO-3b; the executor names in check 6 and in the generator's label
  tables change when WO-3b renames the executors. The TOML shape tests, prompt markers, and
  `--check` call stay, and `--check`'s diff is now printed on failure, which the report's accuracy
  note assumes.
- **Check 7d checks markers in all four files (finding 6).** Each file must hold one begin line
  and then one end line, each alone on its line; check 6's `--check` holds the content. The test
  that the block names every pinned model, the `codex/SKILL.md` section scan, and the unused
  `extract_section` helper are removed. Section 4 names only checks 2 and 6; this change follows
  from the markers now appearing in four files.
- **Contributor docs (finding 6).** `CONTRIBUTING.md` moves `codex/profiles.toml` to the generated
  line of the sync list, adds the "Routing is one edit." paragraph, says the frontmatter `model` is
  written from `models.conf`, and says nothing `--check` covers is hand-edited. `README.md`'s tree
  lists `models.conf` and says what `build-agents.py` writes. `codex/README.md`'s Luna section now
  says `scripts/verify.sh` holds the TOMLs and profiles to `models.conf`, since check 6 no longer
  names `gpt-5.6-luna`.
- **Not landed in this release.**
  - `build-agents.py --validate-catalog` (finding 6 item 9) and check 9, the warning on a
    `reviewed` date older than 90 days: both are specified with finding 8 and land with it in
    WO-3b, where `codex/update.sh` starts calling the flag.
  - Finding 8's pointer rewrites of the model names outside the blocks, listed above, and the
    `codex/profiles.toml` tree comment.
  - The locked ladder, the executor renames, and `ALLOWED_MODELS` with `fable` (finding 7, WO-3b).
  - Every Codex model ID stays `gpt-5.6-*` until WO-0.
- **Acceptance.** Byte identity with WO-2's output was checked with `cmp` against a snapshot. In
  copies of the repo, each seeded violation (a duplicated rung model on each host, the PM below
  top on each host, Recon on the bottom rung, effort `maximum`, an inverted executor ladder, a
  skeptic not above the finders) failed check 6, 20 malformed manifests failed to parse, and a
  hand-edit to each class of generated file failed `--check`. Fed the report's WO-3b manifest, the
  generator reproduced the report's four blocks byte for byte. No live run was made; this work
  order's acceptance needs none, and the new spawn-on-a-rung sentence was not run on a model.
  Codex behavior is source-read only.

## 3.11.0 — 2026-09-24

Lands work order WO-2 of the 3.9.2 analysis: structural sync and CI pins. No stage gains a mode,
an entry type, or a routing decision, and no model assignment changes: every rung still maps to
the same Claude alias and Codex ID. The Codex no-hooks manifest check in `scripts/verify.sh` is
unchanged.

- **The routing reference is gone (finding 5).** `skills/compute-squad/references/routing-rules.md`
  is deleted. Its two unique lines moved: the escalation ban is now the first bullet under
  SKILL.md's Escalation rules ("never on vibes"), where its "FAIL rules below" reference holds,
  rather than in Hard rules as section 4 says; the heading list became finding 9's closed list.
  SKILL.md's pointer and audit-paragraph reference and `README.md`'s tree line are gone. Check 7c
  no longer reads the file, and new check 7o fails if any tracked file other than `CHANGELOG.md`
  and `LEFTOVER_FINDINGS.md` names it.
- **Closed heading list (finding 9, existing headings only).** A new Hard rule in SKILL.md lists
  the eight headings the log uses today and allows ` (cont.)` only on `## Recon`, `## PM — Plan`,
  and `## Executor`. New check 7i reads the list from that bullet and fails on any heading a
  template writes or a tracked doc names that is not on it, and on any listed heading no runtime
  file uses. The report's `## Status`, `## Decision`, `## High-stakes review`, and
  `## Audit Findings` headings, its Attempt-based `(cont.)` clause, and its other three bullets
  are left to the work orders that introduce them.
- **One archive command (finding 11, without the one-active-run rule).** SKILL.md's Hard rules
  hold the one command that writes every archive copy: it names the copy from `date -u` and the
  run ID, refuses to overwrite (`set -C`), verifies with `cmp`, and clears the log only after
  `cmp` succeeds. `agents/squad-mech.md` runs it without reading the log, `agents/squad-pm.md`
  runs a form that appends the `Archive target:` line first, and both report `ARCHIVE FAILED:`
  on failure; SKILL.md Stage 1, `codex/SKILL.md`, and `codex/README.md` stop the run on that
  line. The read-back check and the whole-file `Write` clear are gone. The report writes these
  steps on top of finding 3 (WO-3e); to keep today's high-stakes flow, the PM still archives
  without clearing on a high-stakes PASS (its form ends `archived, log kept:`), and the main
  session closes the run by running the archive command itself instead of clearing the log. A
  high-stakes run therefore leaves two archives, and the rules name three legitimate clears, not
  two. SKILL.md's Stage 5 and `codex/SKILL.md` say this closing archive is the main session's own
  step, not a stage's work, so it does not conflict with finding 19's no-absorption rule. `README.md`, `docs/example-log.md` (new archive name, `Archive target:` as the entry's last
  line), and `codex/SKILL.md` match. New check 7j requires every archive block in SKILL.md, the
  mech and PM bodies, their TOMLs, and `codex/01-archive.md` and `codex/05-pm-accept.md` to match
  SKILL.md's command, and bans the old read-back and whole-file `Write` wording in any case, with
  or without backticks, across line breaks.
- **One blocker grammar in every log-writing body (finding 13, phase 2).** `agents/squad-recon.md`,
  `agents/squad-pm.md`, and the three executor bodies carry SKILL.md's `BLOCKER:` block and the
  ban on prose blockers. Entry shapes gain an optional final `BLOCKER:` block and drop
  "blockers" from paragraph 2 and the PLAN template; Recon states that a goal that cannot be met
  is a `needs-human:` blocker, and `README.md` says the same. `docs/example-log.md` drops its
  prose "Blockers" lines and the Plan entry's closing "No blockers.". This closes N4. The shared-span row 7k holds the span byte-identical
  across the five bodies and `codex/02-recon.md` to `codex/05-pm-accept.md`.
- **Rungs, not models, in protocol text (finding 8, rung words and model-name ban).** SKILL.md's
  role list, stage headings, routing lines, ACCEPT paragraph, escalation bullet, DELEGATE step,
  and audit paragraph say top, mid, or bottom rung; `agents/squad-pm.md` and
  `references/audit-prompts.md` do the same. The old Codex routing section is now
  `## Model routing`, whose block between `<!-- routing:begin -->` and `<!-- routing:end -->` is
  the one place the skill names models, with today's ladder. The audit paragraph tells Claude
  Code to pass each rung's alias as the Agent tool's `model` parameter, which keeps finders on
  `sonnet` and the skeptic on `opus`. New check 7l fails on a model family name, a `gpt-` ID, a
  price pair, or a cost ratio in 16 protocol files outside that block. Check 7d now checks the
  markers and requires every model an agent file or TOML pins to appear in the block. The
  executor renames, `models.conf`, and the generated blocks are left to WO-3a and WO-3b.
- **The Codex prompts are generated and `codex/SKILL.md` is a reading copy (finding 19).**
  `codex/build-agents.py` now writes `codex/01-archive.md` to `codex/05-pm-accept.md` from the
  agent bodies (the PM body split at its PLAN and ACCEPT headings), each marked as generated on
  line 2, and `--check` covers them with the TOMLs. The prompts now carry finding 28's G1, G3,
  and G4 wording and finding 5's precedence clause, and say `Bash` where they said "shell".
  `codex/SKILL.md` loses its frontmatter and opens as a reading copy no host loads; its
  anti-absorption sentences move into a new SKILL.md Hard rule (never do a stage's work, stop on
  a missing agent, the `Agent:` line shows an absorbed stage), so the rule 3.8.0 added now
  loads. This corrects 3.9.0's description of `codex/SKILL.md` as runtime-loaded, and closes N5
  and F14. `README.md`, `codex/README.md`, and `CONTRIBUTING.md` (sync list gains
  `commands/squad.md`, so its count of places becomes eight; generated files marked, in the list
  and the pre-commit checklist; the version step names the `Version:` line) match.
  Check 3 reads the reading-copy title and `Version:` line, check 6 requires exactly the five
  prompts with their markers, and new check 7s keeps frontmatter out of any SKILL.md outside
  `skills/` and the no-absorption rule in both SKILL.md files.
- **Shared text stays inline, pinned by one table (finding 24).** `CONTRIBUTING.md` says a stage's
  rules live in its own body and shared text is a row in the shared-span table. New check 7p is
  that table, 16 rows: append-how, append-why, pointer, and per-spawn; finding 5's two
  precedence rows; the blocker grammar (7k); the executor and ACCEPT output forms and the check
  line (7n, finding 12); the three ACCEPT `awk` reads (finding 15); `REFUSED:` in
  `squad-helper.md` and `squad-mech.md` and SKILL.md's refusal route (finding 28); and the
  switchboard phrase (finding 18). A built-in self-test changes one character in every row's
  span in every file and fails if the row lets it through.
- **Pins deferred from WO-1 (findings 17, 18, 27, 28).** New check 7q caps each agent description
  at 500 bytes with no `<commentary>` and a mention of the compute-squad skill. New check 7r fails
  if any agent's one-line `tools:` list includes `Agent` or `Task`, or if the line is missing.
  Check 2 allows only the keys `name`, `description`, `model`, `color`, `tools`, and
  `omitClaudeMd`, with `omitClaudeMd` after `model`. Check 7c now also reads the Recon, PM, and
  three executor bodies. It keeps `codex/SKILL.md`, which the report drops on the premise that the
  file is retired; finding 19 keeps it as a reading copy that still states the cap.
- **Check 8, behavior without a model (finding 26, checks 8a and 8e).** `tests/check_logs.py`
  (Python 3.9 stdlib) lints a log against rules it reads from SKILL.md: headings on the closed
  list, the Goal entry first, one `date -u` timestamp per entry in order, and the `BLOCKER:`
  grammar with no prose blocker lines. Its heading rule also requires a `## Delegated — <stage>`
  entry to answer a `DELEGATE:` block in the nearest stage entry above it and to name that
  stage (its heading, or the heading's first or last part, with or without a suffix such as
  `(pending)`), from the `<requesting stage>` wording in `agents/squad-helper.md` and
  `agents/squad-mech.md`; the report does not name this rule. Check 8a lints
  `docs/example-log.md` clean and runs 15 fixtures in `tests/fixtures/logs/`: 4 must pass,
  among them an ACCEPT-mode delegation, and 11 must fail on exactly their listed rule, among
  them `invented-heading.log.md`; every fixture cites protocol text that must still exist, and
  every rule has a failing fixture. Check 8e runs `codex/update.sh` with the new stub
  `tests/stubs/ok` as `git` and `codex` in a temp `CODEX_HOME` and asserts the prune, the seven
  TOMLs installed byte for byte, the profiles, and untouched user files. `README.md`'s tree and
  `CONTRIBUTING.md` describe check 8. The report's wording for the verify.sh header, the
  `CONTRIBUTING.md` paragraph, and the README tree line also names 8b to 8d, 8f, the grant hook,
  the archive command, and the live harness; those do not exist yet, so the landed wording names
  only the log linter (8a) and `codex/update.sh` (8e), and the work orders that add the rest
  extend it.
- **Not landed in this release.**
  - The report pins `REFUSED:` in SKILL.md, but the G2 text WO-1 landed there never contains it;
    the "refusal route" row pins that G2 sentence instead.
  - Finding 11's steps assume finding 3. WO-3e removes the PM's high-stakes archive form and the
    main session's closing archive when squad-mech takes over the high-stakes close.
  - Checks 8b, 8c, 8d, and 8f, the repo fixtures, and the live harness; linter rules for text
    later work orders add; shared-span rows for findings 4, 9's fixed fields, 13's executor parts,
    14, and 18's delegation text; and finding 5's pins for WO-3f text.
  - The generated `codex/03-pm-plan.md` carries two preamble phrases that point at ACCEPT-only
    steps, a consequence of the report's preamble rule.
  - Known inconsistency, still open for WO-3d: the stage bodies say any re-spawn appends a
    `(cont.)` entry, while SKILL.md's DELEGATE step 2 says a re-spawn after a request that was not
    `BLOCKING` writes a complete entry.
  - Every Codex model ID stays `gpt-5.6-*` until WO-0.
- **Acceptance not run live.** No live reference run was made, so cost against WO-1's baseline and
  the absence of reads of the deleted file are unconfirmed. The archive command was checked in
  temp directories under bash and dash (a pre-existing target and an unwritable archive
  directory leave every file unchanged and truncate nothing) and by two single-stage Haiku
  `squad-mech` probes, which ran the command verbatim and reported `ARCHIVE FAILED:` on a forced
  collision without retrying. The PM's archive forms, the rung-word routing, and the audit alias
  line were not run on a model. Codex behavior is source-read only: the finding 19 live scenario
  and a manual Codex run need the Codex CLI, which is not installed here.

## 3.10.0 — 2026-09-24

Lands work order WO-1 of the 3.9.2 analysis: wording and description cuts that need no new
machinery. Agent names, tools, models, and colors are unchanged, and so is `scripts/verify.sh`.

- **Shorter agent descriptions (finding 17).** Each of the seven `agents/*.md` descriptions is now
  one or two sentences and one short `<example>`, with no `<commentary>` and no capitalized model
  family name (`Opus`, `Sonnet`, `Haiku`), and each defers to the compute-squad skill. On a Sonnet 5
  main session the plugin's per-session cost fell from 3,282 to 1,475 tokens (plugin on minus
  plugin off). The skill's trigger phrase
  `recon-plan-execute-verify` is now `recon-plan-execute-accept`, and `CONTRIBUTING.md` asks for
  one `<example>` of at most 500 bytes per description.
- **squad-mech no longer loads `CLAUDE.md` (finding 27).** `agents/squad-mech.md` sets
  `omitClaudeMd: true`. A probe spawn in a directory whose `CLAUDE.md` held a marker line could not
  quote the marker; the 3.9.2 agent quoted it.
- **Recon stops reading project instruction files itself (finding 22).** The step that read
  `AGENTS.md` and `CLAUDE.md` is gone from `agents/squad-recon.md` and `codex/02-recon.md`, and
  the later steps are renumbered. `codex/README.md` now says Codex injects `AGENTS.md` itself and
  explains `project_doc_fallback_filenames` for projects that keep their rules only in `CLAUDE.md`.
- **PM wording and the Codex agent generator (finding 23).** `agents/squad-pm.md` drops
  "Opus-tier" and "Sonnet-safe", names the log and its archive as the only files the PM authors in
  the repository, and runs refutation probes from stdin or from a `mktemp -d` directory outside
  the repository that it deletes; `codex/05-pm-accept.md` step 4 gets the same probe rule. The
  PM's last sentence now makes clearing the log on an ordinary PASS the one exception to "never
  clear". `codex/build-agents.py` drops the "RUN THIS AGENT" header and `MODEL_DEFAULTS` (so a
  changed model ID no longer raises `KeyError`), writes a version comment as the first line of
  each `codex/agents/*.toml`, and rejects a backslash in a body as it already rejected a triple
  quote. `CONTRIBUTING.md`'s release step says to regenerate the TOMLs.
- **Delegation gaps closed and one template per PM mode (finding 28).** In
  `skills/compute-squad/SKILL.md` and `agents/squad-recon.md`, a stage that needs a stronger model
  ends its entry with a `BLOCKER:` naming its own stage; `agents/squad-pm.md` says the PM, already
  on the top rung, uses `needs-human:`. The executor bodies get no such line, because finding 28
  leaves the Executor's route to finding 13. A helper that refuses begins its final message with
  `REFUSED:` (`squad-helper.md`, `squad-mech.md`), and the orchestrating session re-spawns the
  requesting stage even when its request was not `BLOCKING`; `README.md`'s helper and intern
  paragraphs now describe that route. The orchestrating session never spawns a sixth helper for a
  stage, and the Recon, PM, and three executor bodies state the 5-helper cap. The "entries can be
  short" rule moved from SKILL.md into the Recon and PM bodies as "Length follows the change". In
  `agents/squad-pm.md` the PLAN template moved from the common section into the PLAN section, and a
  new ACCEPT template before "Delegating before a verdict" replaces the three "(Bash heredoc form,
  as above)" references. The ACCEPT template carries only the fields the log has today (heading,
  `Timestamp:`, `Agent:`, and the body); the report's `Attempt:`, `Answers:`, `High-stakes:`,
  `Rerun:`, and `Tested:` lines are defined by findings 9 and 2 and land with them. The timestamp
  paragraph stays in the common section, since it governs entries in both modes. The Codex prompts
  already have one template per mode (`codex/03-pm-plan.md`, `codex/05-pm-accept.md`).
- **Command output capture (finding 12).** The three executor bodies and `codex/04-execute.md` run
  each verification command through a `set -o pipefail` form that prints the exit code and the
  last 40 lines and keeps the full output in a temp file. ACCEPT step 2 in `agents/squad-pm.md` and
  `codex/05-pm-accept.md` re-runs every verification command in the plan and the project's full
  suites with the same form plus a grep for failing lines, and records each command with its exit
  code. ACCEPT still re-runs everything itself.
- **ACCEPT reads the Executor's account last (finding 15).** ACCEPT step 1 reads the log in three
  `awk` passes: the goal alone, then everything except the goal and the Executor's entries, and the
  Executor's entries only after its own checks and refutations. SKILL.md's Stage 5 spawn prompt
  names only the mode and the repo root. Mirrored in `codex/05-pm-accept.md`, `codex/SKILL.md`,
  and `README.md`.
- **Plan `Totals:` line (finding 16, phase 1).** PLAN states every quantity the work produces once
  on a `Totals:` line, checks every task and test against it, and sizes the plan to the work.
  `agents/squad-pm.md` and `codex/03-pm-plan.md`.
- **Switchboard rationale corrected (finding 18, phase 1).** SKILL.md and
  `references/routing-rules.md` no longer claim subagents cannot spawn subagents. They now say no
  squad agent has a spawn tool and some hosts disable nested spawning. The switchboard is unchanged.
- **Real timestamps and model IDs in log entries (finding 21, phase 1).** Every stage template in
  the five log-writing agent bodies and in `codex/02-recon.md` to `codex/05-pm-accept.md` has a
  `Timestamp:` line taken from `date -u +%Y-%m-%dT%H:%M:%SZ` and an `Agent:` line carrying the
  model ID the agent's context states, in place of a free-form time and a fixed model name. A new
  hard rule in both SKILL.md files applies the timestamp rule to the main session too.
  `codex/04-execute.md` no longer lists Codex model IDs, `codex/SKILL.md`'s Agent-line description
  matches, and `docs/example-log.md` uses the new line forms. The paragraph after each template
  differs from the report's text: with the report's wording, 2 of 4 Haiku executor probes put
  `date` in the append command and switched to an unquoted heredoc, and 1 of 4 dropped the agent
  name. The landed text says to run `date` in a separate call, keep `<<'EOF'`, and keep the agent
  name; 4 of 4 Haiku probes and 1 Sonnet Recon probe followed it.
- **Stale cost figures removed (finding 8, phase 1).** `README.md` drops the 30 to 40% saving and
  the 1.67x Opus-to-Sonnet ratio. Its cost FAQ is now a dated 2026-09-24 snapshot of one measured
  3.9.2 run with that day's list prices, ending with finding 25's sentence on what drives cost.
  `references/routing-rules.md` drops its July 2026 price list, the 1.67x ratio, and the 30-40%
  estimate, and `README.md`'s repository tree now describes that file as holding cost posture, not
  cost math.
- **Protocol outranks the spawn prompt (finding 5, precedence clause).** The five log-writing
  agent bodies say their own protocol and the log outrank the spawn prompt and that a conflict is
  named in the entry. `squad-mech` gets the same rule for its procedures.
- **An unavailable model stops the run (finding 7).** A new hard rule in SKILL.md and
  `codex/SKILL.md`: if a spawn fails because its model is unavailable to the account, stop and
  report the setup gap with the spawn's error text, and never run that stage on a lower rung, with
  another agent, or in the main session. `codex/SKILL.md`'s setup paragraph now covers unavailable
  models as well as unavailable roles. `README.md`'s Claude Code install line and
  `codex/README.md`'s requirements paragraph state the stop.
- **The skeptic reads the locked goal and stops defaulting to REFUTED on security findings
  (finding 20, Goal read and skeptic default).** The skeptic brief in `references/audit-prompts.md`
  reads the Goal entry first, quotes the scope text it relies on to refute a finding as out of
  scope, and never treats a defect the change introduced as out of scope. A security or privacy
  finding whose reproduction needs credentials, production configuration, or an external service
  the run does not have now gets `NEEDS-HUMAN` with what reproduction would need, never `REFUTED`,
  once the skeptic has traced the configuration the repository holds. The concurrency and
  accessibility carve-out stays, reworded without em dashes. `SKILL.md`'s audit paragraph does not
  route `NEEDS-HUMAN` yet: it still counts only skeptic-confirmed findings as FAIL evidence, so a
  `NEEDS-HUMAN` finding reaches the main session in the skeptic's reply and waits for WO-3f's audit
  procedure to stop the run for the user.
- **Not landed in this release.**
  - Every `scripts/verify.sh` part of these findings (among them finding 17's description pins,
    finding 27's frontmatter-key allowlist, and finding 28's and finding 15's pins), because WO-1
    allows no change to the script.
  - The three `## Goal — Locked` templates keep `<timestamp line>`, since check 7a holds them
    byte-identical.
  - The manual Codex prompts `codex/02-recon.md` to `codex/05-pm-accept.md` do not yet carry
    finding 28's G1, G3, and G4 wording or finding 5's precedence clause. The generated
    `codex/agents/*.toml` files do. The prompts catch up when WO-2 generates them from the bodies.
  - Known inconsistency: the stage bodies still say a re-spawn appends a `(cont.)` entry, while
    SKILL.md's DELEGATE step 2 now says a re-spawn after a request that was not `BLOCKING` writes a
    complete entry under its plain heading. Finding 9 (WO-3d) aligns the bodies.
- **Acceptance not run live.** No full reference run was made. The `date -u` timestamps and model
  IDs were checked with single-stage probes only (Recon on Sonnet 5 and the Haiku executor, under a
  Haiku main session). The PM on Opus was not probed, and timestamp order across a full run is
  unconfirmed.

## 3.9.2 — 2026-08-17

Accuracy pass from an external-persona review: closes the last self-diagnosed claim errors and
scopes every unverifiable assertion to its evidence.

- **README FAQ tier claim corrected (F4, finally).** "Acceptance always reviews from a tier up"
  misstated the design — on COMPLEX work, execution and acceptance both run on Opus. The FAQ now
  matches `references/routing-rules.md`'s accurate phrasing: never below the work, a tier above by
  default. This was the one finding from `LEFTOVER_FINDINGS.md` still open in README prose.
- **`LEFTOVER_FINDINGS.md` marked as a historical snapshot.** A header now states it reflects the
  v3.6.0 tree, records which findings were since resolved (N1 in 3.9.0, F4 here), and notes N5
  stays open by choice. The file is an audit record, not a live punch list.
- **Pricing and cost claims scoped to their evidence.** The cost table is labeled as list prices
  observed on the author's account (July 2026) to verify before relying on, and the 30-40%
  figure is labeled a back-of-envelope estimate with its uniform-token-volume assumption stated,
  not a measurement.
- **Codex model IDs scoped to their evidence.** README's Codex prerequisites now state the three
  hard-coded model IDs resolve on the author's account as of August 2026 and are not stable
  public API guarantees.

## 3.9.1 — 2026-08-17

Aligns the product description across every surface, including the GitHub repository About text.

- **One description everywhere.** `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`, and
  `.claude-plugin/marketplace.json` now carry a byte-identical description, and the two trailing
  platform clauses are dropped — the sentence already names both platforms, so the clauses only
  created two strings that could drift. `README.md`'s opening tagline is the same sentence without
  the leading product name, which the `# Compute Squad` heading above it already supplies.
- **Short enough for GitHub.** The canonical sentence was shortened to 335 characters. GitHub
  rejects a repository description over 350 (HTTP 422), so the previous 384-character version could
  not be used as the About text and that surface had to be worded separately.
- **`scripts/verify.sh` check 7e.** Asserts the three manifest descriptions are byte-identical and
  that the canonical string still fits GitHub's 350-character About limit, so neither the wording
  nor the length can drift out of alignment again. The GitHub About text itself lives outside the
  repository and cannot be checked by CI — it must be updated by hand when this string changes.

## 3.9.0 — 2026-08-17

Applies every surviving finding from the documentation audit: the Rank 7 protocol consolidation, the
three-way naming gap, and the lower-priority findings. Follow-up to 3.8.0's Codex
delegation-guarantee pass.

- **Rank 7: one canonical protocol description.** `skills/compute-squad/SKILL.md` (Claude Code) and
  `codex/SKILL.md` (Codex) are the two canonical, runtime-loaded full descriptions of the pipeline.
  `README.md`'s "How a run works" and "The delegation structure", and `codex/README.md`'s "How to
  run it", no longer independently retell all six stages; they summarize and point at the canonical
  files, keeping only the human-only color and the content that is structurally load-bearing (the
  `## Goal — Locked` template). `scripts/verify.sh` gains check 7: byte-identical diffs for the
  Goal-Locked template (3 files) and the BLOCKER grammar block (2 files), plus presence checks for
  the 5-helper cap (4 files) and the three Codex model IDs (2 files), so the next silent drift fails
  CI instead of shipping. The BLOCKER grammar's existing drift between the two SKILL.md files (a
  dropped article and comma) is fixed as part of this pass.
- **Naming gap resolved.** "Squad Manager," "the orchestrating session," and `codex/SKILL.md`'s H1
  "Codex Manager Protocol" named the same actor three ways. All three collapse to "the orchestrating
  session" repo-wide (33 tracked "Squad Manager" occurrences plus one more in `docs/example-log.md`
  a plain grep missed because it line-wrapped mid-word). `CHANGELOG.md`'s own historical entries are
  left untouched as a historical record.
- **CONTRIBUTING.md rewritten.** Names all five version-bump locations explicitly, names
  `scripts/verify.sh` as the local pre-commit gate matching CI, and fixes the self-contradiction
  between its "five places" opening line and its own seven-item sync-rule list.
- **Canonical product description.** One description, varying only by a trailing platform clause,
  now lives in `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`, and
  `.claude-plugin/marketplace.json`; `.codex-plugin/plugin.json`'s
  `interface.shortDescription`/`longDescription` are updated to match. All copies name the
  MECHANICAL/STANDARD/COMPLEX three-way routing instead of flat "Sonnet executes."
  `.agents/plugins/marketplace.json` is confirmed to have no `description` field in its real schema
  and is left alone. `README.md`'s opening tagline and
  `skills/compute-squad/references/routing-rules.md`'s summary line, the last two places still
  describing a flat "four-tier" pipeline with "Sonnet executes", are brought in line with the same
  wording; the stale "Updated 2026-08-02" stamp is dropped from the routing reference.
- **Prerequisites documented.** Both install sections in `README.md`, and `codex/README.md`'s
  native-install section, now state their model-access prerequisite (Opus for Claude;
  `gpt-5.6-sol`/`terra`/`luna` for Codex) and the Codex CLI 0.134+ floor, previously only a comment
  in `codex/profiles.toml`.
- **Build and verify harden against stray files.** `scripts/build-plugin.sh` now zips the
  git-tracked file set (`git ls-files`) instead of `zip -r` over live directories, so an untracked
  file cannot enter `dist/compute-squad.plugin`. `scripts/verify.sh` check 2 asserts the agent set
  against `git ls-files agents/*.md` instead of a bare glob.
- **README repo-layout tree completed.** Adds the seven tracked paths it omitted, including
  `scripts/verify.sh` (the actual CI gate), `codex/README.md`, `codex/update.sh`,
  `codex/build-agents.py`, `.github/`, `.gitignore`, and `LICENSE`.
- **Lower-priority findings.** Fixed: `codex/SKILL.md` documents the `(cont.)` re-spawn convention
  (B3); `codex/README.md`'s updater-order sentence now matches `codex/update.sh`'s actual order
  (B4); the Codex CLI version floor is reader-facing (D6); the unused "Fable" row is removed from
  `routing-rules.md`'s cost table (D7); "Claude Cowork" is glossed at first use (D8); `codex/SKILL.md`
  glosses Sol/Terra/Luna where it first uses the shorthand (D10). Declined, with reasons logged:
  `codex/build-agents.py`'s unguarded tier-term substitution (D2, latent risk only, no live misfire,
  a word-boundary fix carries its own miss-risk); the duplicated Codex install command block in
  `README.md`/`codex/README.md` (C4, two lines of copy-paste-stable CLI syntax, not protocol prose).
- **GitHub repository metadata.** Replacement About description, homepage, and topics text produced
  for the user to paste by hand; this run does not change GitHub settings.

Version bumped to 3.9.0 in all five synced locations; `dist/compute-squad.plugin` rebuilt;
`codex/agents/*.toml` regenerated from `agents/*.md` via `python3 codex/build-agents.py`.

## 3.8.0 — 2026-08-17

Closes the Codex delegation-guarantee gap: explicit spawn wording, self-reporting log attribution, a documented Luna fallback, a safe agent prune, and an accurate README.

- **Codex spawn wording.** `codex/SKILL.md`'s Stage 4 routing table and Intra-stage delegation section use the explicit "spawn" verb on every branch, matching the Claude-side skill, plus a new anti-absorption sentence in Hard rules: the orchestrating session must spawn the named agent at every stage instead of doing the stage's work itself.
- **Log entry attribution.** `agents/squad-recon.md`, `agents/squad-pm.md`, `agents/squad-executor.md`, `agents/squad-executor-haiku.md`, and `agents/squad-executor-opus.md` add an `Agent: <name> (<tier>)` line to their log-entry heredoc templates, regenerated into `codex/agents/*.toml` and mirrored by hand in `codex/02-recon.md` through `codex/05-pm-accept.md` and one worked run in `docs/example-log.md`, so a collapsed single-session Codex run is visible in `COMPUTE_SQUAD_LOG.md` without external tooling.
- **Luna subagent fallback documented.** `codex/README.md` documents the reported Multi-Agent V2 restriction on `gpt-5.6-luna` as a subagent target and the manual, per-run workaround; this is documentation only, not a default routing change, since the restriction is unverified against official docs.
- **`codex/update.sh` prunes retired agents.** Removes the three known-retired agent TOMLs (`squad-design.toml`, `squad-manager.toml`, `squad-verifier.toml`) from `$CODEX_HOME/agents` by explicit name, leaving vibecheck's `vc-*.toml` files untouched.
- **README accuracy.** Removes the false "no agent-spawning at all" claim about the Codex path.

## 3.7.0 — 2026-08-02

Native Codex plugin packaging brings the Compute Squad workflow to Codex without dropping the existing Claude package.

- **Codex plugin.** Added a native `.codex-plugin` manifest, Codex marketplace registration, shared-skill Codex routing, generated Codex agent definitions, and model profiles.
- **Codex routing.** Maps the PM and COMPLEX execution to `gpt-5.6-sol`, standard execution to `gpt-5.6-terra`, and mechanical work to `gpt-5.6-luna`, with max reasoning pinned for worker profiles.
- **Sync and verification.** Added generation and validation gates so Codex agents stay aligned with the existing protocol and the Claude distribution remains independently packaged.

## 3.6.0 — 2026-08-02

A slash command entry point, true log appends, and skeptic guidance for concurrency and accessibility findings.

- **New: `/squad <goal>` slash command.** `commands/squad.md` starts the full pipeline at Stage 0 with `$ARGUMENTS` as the goal — same entry point as the trigger phrases, now also reachable as a command. Added to `scripts/build-plugin.sh`'s zip list and `scripts/verify.sh`'s dist content-diff, and documented in the README repo-layout tree and install section.
- **True appends, not Read-then-Write.** `squad-recon`, `squad-pm`, `squad-executor`, `squad-executor-haiku`, `squad-executor-opus`, and the matching Codex prompts (`02-recon.md` through `05-pm-accept.md`) now append log entries with a single Bash/shell heredoc (`cat >> COMPUTE_SQUAD_LOG.md <<'EOF' ... EOF`) instead of reading the file and writing it back whole, which could silently drop an entry another stage appended in between. `squad-recon` loses the `Write` tool entirely — its one permitted mutation is now the Bash append — and its Bash restriction carries the explicit carve-out (read-only inspection, plus exactly this one append form). Whole-file `Write` remains legitimate in exactly two places, now named as such everywhere they occur: `squad-mech`'s (and `01-archive.md`'s) truncate-after-verified-archive, and the PM's clear-on-PASS. `SKILL.md` and `references/routing-rules.md` state the same rule at the protocol level.
- **Skeptic guidance for concurrency and accessibility findings.** `references/audit-prompts.md`'s skeptic brief now says failure to reproduce is not refutation for these two dimensions — a race needs the right interleaving, an accessibility gap needs the right assistive-tech path — so refute only by demonstrating the guard, the serialization point, or the compliant attribute; otherwise CONFIRM. The default-REFUTED-when-uncertain rule is unchanged for every other dimension.

## 3.5.0 — 2026-08-02

MECHANICAL execution routes to Haiku. **Experimental, pending evidence from real runs** — this is a routing change, not a validated cost/quality result; watch FAIL rates on MECHANICAL-classified work before trusting the savings.

- **New agent: `squad-executor-haiku`.** The executor protocol verbatim (mirrors `squad-executor.md`), on Haiku, scoped to plans the PM classifies MECHANICAL. Carries one added discipline line beyond the shared protocol: if a task turns out to need more than transcribing an explicitly specified change, it stops and logs a `BLOCKER:` (`rerun: Plan`) naming the plan as under-classified, rather than pushing through.
- **Stage 4 routing is now three-way.** MECHANICAL → `squad-executor-haiku` (Haiku), STANDARD → `squad-executor` (Sonnet), COMPLEX → `squad-executor-opus` (Opus). Previously MECHANICAL and STANDARD both ran Sonnet.
- **Execution escalation ladder.** Same-stage-fails-twice escalation for execution now climbs `squad-executor-haiku` → `squad-executor` → `squad-executor-opus` (haiku → sonnet → opus) instead of starting at Sonnet; two FAILs at a tier moves execution up one tier. The general "escalate one tier on repeated FAIL" rule for other stages is unchanged.
- **Rationale.** The plan is required to carry the intelligence regardless of which model executes it, and the Opus PM still reviews every classification the same way — so pushing MECHANICAL work to the cheapest tier widens the gap between executor and reviewer rather than narrowing it, consistent with the pipeline's own verification-asymmetry thesis. This is a default, not a guarantee: it ships as the stated option pending evidence from real runs, not because MECHANICAL-on-Haiku has been run-tested here.
- **Docs.** `skills/compute-squad/SKILL.md` (role list, Stage 4, escalation rules), `skills/compute-squad/references/routing-rules.md` (role table, escalation rule, verification-asymmetry note), `README.md` (agent table, agents section, routing rule 1, repo layout), and `codex/README.md` (suggested-model table) all updated to the three-way routing.

## 3.4.1 — 2026-08-02

Copy hardening: no oversold claims, no past-tense claims about actions that haven't happened yet.

- **"Always a tier above" softened.** The README intro, README rule 2, and `references/routing-rules.md` now say the reviewer is "never below the work, and a tier above by default" — accurate once COMPLEX escalates execution to Opus and acceptance holds at the same tier instead of climbing further. The adjacent caveat about that COMPLEX case is unchanged.
- **README intro reframed.** Leads with what the pipeline actually sells — verification and auditability that don't depend on operator discipline, plus capacity from runs not occupying your session — then the decision-density routing, then the 30-40% cost arithmetic, now explicit that the comparison baseline is an all-Opus worker pool running the same stages, not a single session.
- **Repo-layout tree fixed.** Removed the duplicate `scripts/build-plugin.sh` line.
- **PASS entries no longer claim the future.** The PM's `## PM — PASS` entry (in `agents/squad-pm.md`, `codex/05-pm-accept.md`, and `docs/example-log.md`) now states the archive target as intent (`Archive target: compute-squad-archive/<name>`) instead of claiming the copy is already made and verified — that entry is written before the copy exists. The verified-archive confirmation moved to the PM's final summary message, which sits outside the append-only log.
- **plugin.json metadata.** Added `homepage`, `repository`, and `license: MIT`.

## 3.4.0 — 2026-08-02

Protocol hardening: the goal is now part of the record, and blockers have a grammar.

- **The Goal — Locked entry.** Every fresh log now opens with a mandatory `## Goal — Locked` entry (goal, acceptance criteria, out of scope, assumptions), composed by Stage 0 and appended by Stage 1 immediately after the archive, before Recon spawns. Every downstream stage — Recon, the PM in both modes, both Executors — now reads the goal and acceptance criteria from that entry instead of trusting its spawn prompt, and Stage 0's resume check ("is this the same goal?") reads it too. In Codex, the operator appends the entry by hand after running `01-archive.md`, and prompts 02-05 point at it instead of carrying `GOAL:` / `ACCEPTANCE CRITERIA:` placeholders.
- **The blocker grammar.** Mirroring the `DELEGATE:` block, a stage that hits a blocker mid-work now ends its own log entry with a `BLOCKER:` block — `rerun: <Recon|Plan|Executor>` or `needs-human: <the decision required>`, plus a one-line `why:` — instead of ad hoc prose. A `rerun:` blocker re-runs that stage and everything after it and counts toward the three-FAIL stop; a `needs-human:` blocker returns to Stage 0; freeform prose blockers are now a named protocol violation.
- **Docs.** `docs/example-log.md` gains a worked `## Goal — Locked` entry ahead of Recon and a BLOCKER commentary example. README's "How a run works" and delegation-structure sections, and every sync location, reflect both changes.

## 3.3.0 — 2026-07-25

Hardening pass so the pipeline runs correctly for a first-time user with no author setup.

- **Two new agents.** `squad-executor-opus` is the COMPLEX and escalation execution variant. It replaces a per-call Opus override the runtime never offered, so COMPLEX work now routes to a real Opus agent. `squad-helper` is the execution-tier DELEGATE worker, replacing a Sonnet helper the protocol named but never defined.
- **Log-write permissions fixed.** `squad-recon` and `squad-pm` now carry the `Write` tool, so the stages that must append to `COMPUTE_SQUAD_LOG.md` can actually do it. The log (and its archive copy) is their only permitted write target.
- **Archive on PASS, with high-stakes deferral.** The PM now appends its PASS entry, archives the full log to `compute-squad-archive/` and verifies the copy, and only then clears the active log. High-stakes changes leave the log intact for the main session's review, which clears it afterwards.
- **Blocker and delegation semantics.** A logged blocker naming an upstream stage re-runs that stage and everything after it and counts toward the three-FAIL stop; a blocker needing a human decision returns to Stage 0. Pre-verdict delegation uses a `## PM — Accept (pending)` entry, and `DELEGATE:` blocks are forbidden inside PASS and FAIL entries. Helpers return results and the Squad Manager writes them, ending the duplicate-writer race. A re-spawned stage appends a `## <Stage> (cont.)` entry; the one-entry rule is per spawn.
- **Audit prompt briefs shipped.** New `skills/compute-squad/references/audit-prompts.md` with the five finder briefs and the skeptic brief, including the required finding format and the default-REFUTED rule.
- **Build script.** New `scripts/build-plugin.sh` rebuilds `dist/compute-squad.plugin` from source; the README explains why the artifact is committed.
- **Docs corrections.** Stage count is six everywhere; the archive location is always `compute-squad-archive/` in the repo root; the frontmatter claim now matches reality (aliases, `inherit`, or explicit model IDs); the worked example treats its auth-path change as high-stakes. Added run-footprint, update and uninstall, cost, resume, and trigger-phrase documentation, plus `CONTRIBUTING.md` and gitignore entries for run state.

## 3.2.0 — 2026-07-25

Public release.

- De-personalized the strategy layer: any main-session model can run Stage 0 (top tier recommended); no dependency on a specific frontier model.
- Added `marketplace.json` so Claude Code users can install directly from this repo.
- Added `codex/` prompt pack: the same pipeline as a manually-run sequence of Codex sessions.
- Added `docs/example-log.md`: a complete worked run showing every log entry format, including a DELEGATE block.
- Added MIT license and this changelog.

## 3.1.0 — 2026-07-25

- **DELEGATE protocol.** The hierarchy is fractal: every stage can request that its zero-judgment busywork be pushed down a tier via a `DELEGATE:` block in its log entry. Subagents cannot spawn subagents, so the Squad Manager acts as the switchboard, running intern (Haiku) or execution (Sonnet) helpers on the requesting stage's behalf. Downward only; capped at 5 helpers per stage per run.

## 3.0.0 — 2026-07-25

Role-hierarchy restructure: strategy / PM / execution / intern.

- **Stage 0 Strategy** added: the main session interrogates the goal, identifies gaps, clarifies them with the user in one batched pass, and locks goal + acceptance criteria before any agent spawns.
- **Design and Verifier merged into an Opus PM** (`squad-pm`) with PLAN and ACCEPT modes. The PM plans the work, classifies execution complexity, and adversarially accepts the deliverable.
- **Executor moved to Sonnet by default**, with an Opus override when the PM classifies work COMPLEX. Verification asymmetry holds by construction: the Opus PM always reviews from a tier above Sonnet execution.
- `squad-mech` scoped explicitly as the intern: zero-judgment busywork only.

## 2.0.0 — 2026-07-24

Decision-density routing for the Opus 5 era.

- Replaced the single-worker-model design with per-stage routing: stages that decide (Design, Verifier, Manager) run stronger models; stages that execute against a tight spec run cheaper ones.
- Added verification asymmetry (the verifier never runs weaker than the executor it checks), retry economics, and escalate-on-repeated-FAIL rules.
- Added Haiku tier for mechanical steps (log archival).

## 1.0.0

Original Compute Squad: a 4-stage pipeline (Recon → Design → Executor → Verifier) driven by an Opus manager spawning Sonnet subagents, coordinated through a shared `COMPUTE_SQUAD_LOG.md`, with log archival before every run and a Verifier that clears the log only on PASS.
