## Goal — Locked
Timestamp: 2026-09-01T10:00:12Z
Run: 2026-09-01-export-dry-run

Goal: Add a --dry-run flag to the export command that prints the files it would write and writes nothing.
Acceptance criteria:
- export --dry-run writes no file and exits 0.
- export --dry-run prints one line per file a real run would write.
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

The command is defined in src/cli/export.js (lines 12-58). It writes through
writeOutputs() in src/cli/write.js (lines 5-31), its only caller. Tests:
test/export.test.js (6 cases).

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

Completed task 1 in src/cli/export.js. Task 2 is blocked: writeOutputs() also
writes a lock file before its loop (src/cli/write.js:8), which the plan does
not mention.

Deviations: none. Tasks 2 and 3 are not done.

BLOCKER:
- rerun: PM
- why: src/cli/write.js:8 writes a lock file before the loop, and the plan does not say whether a dry run takes it.
