## Goal — Locked
Timestamp: 2026-09-01T10:00:12Z
Audit: no
Run: 2026-09-01-export-dry-run

Goal: Add a --dry-run flag to the export command that prints the files it would write and writes nothing.
Acceptance criteria:
- AC1: export --dry-run writes no file and exits 0.
- AC2: export --dry-run prints one line per file a real run would write.
Out of scope: the import command.
Assumptions: none.

## Status
Timestamp: 2026-09-01T10:00:12Z
Run: 2026-09-01-export-dry-run
Mode: full
Worktree: /home/dev/app, branch main
Base: 1a2b3c4
Plan: none
Grant: all revisions, full-mode request
Next: spawn squad-recon
Stop: after the PM verdict

## Recon
Timestamp: 2026-09-01T10:03:40Z
Agent: squad-recon (claude-sonnet-5)
Attempt: 1

Checks:
- goal facts: all confirmed
- `npm test` -> exit 0; 6 passed; tree changed: no
Map:
- src/cli/export.js:12-58 the export command: parses its flags and calls writeOutputs()
- src/cli/write.js:5-31 writeOutputs: "function writeOutputs(files, options) {"; writes every output file
Callers:
- writeOutputs <- src/cli/export.js:40
Tests:
- test/export.test.js: 6 cases on the export command
Invariants:
none found
Open for the PM:
none found

## PM — Plan
Timestamp: 2026-09-01T10:08:02Z
Agent: squad-pm (claude-opus-5-5)
Attempt: 1
Classification: STANDARD
High-stakes: no
Totals: 2 source files changed, 2 tests added.

Tasks, in order: 1. parse --dry-run in
src/cli/export.js and pass dryRun to writeOutputs(); 2. in src/cli/write.js,
print each path and skip the write when dryRun is set; 3. add one test per
criterion to test/export.test.js. Must NOT change: a real run's output.
Verification plan: npm test. Non-goals: the import command. Risks: none.

## Executor
Timestamp: 2026-09-01T10:16:27Z
Agent: squad-executor (claude-sonnet-5)
Attempt: 1
Plan: r1, work order all

Tasks: 1 of 3; task 2 is blocked
Files changed: src/cli/export.js
Checks:
none found
Deviations: none
For acceptance: none
Commit: 1a2b3c4d5e6f, working tree 1 changed file

BLOCKER:
- rerun: Plan
- why: src/cli/write.js:8 writes a lock file before the loop, and the plan does not say whether a dry run takes it.

DELEGATE:
- [intern] List every call to fs.writeFileSync under src/cli/ with file and
  line (procedure: grep -n "writeFileSync" -r src/cli); return at most 20
  lines. Non-blocking.
