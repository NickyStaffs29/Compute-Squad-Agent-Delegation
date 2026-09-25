## Goal — Locked
Timestamp: 2026-09-02T09:00:12Z
Run: 2026-09-02-export-dry-run

Goal: Add a --dry-run flag to the export command that prints the files it would write and writes nothing.
Acceptance criteria:
- AC1: export --dry-run writes no file and exits 0.
- AC2: export --dry-run prints one line per file a real run would write.
Out of scope: the import command.
Assumptions: none.

## Status
Timestamp: 2026-09-02T09:00:12Z
Run: 2026-09-02-export-dry-run
Mode: plan
Worktree: /home/dev/app, branch main
Base: 1a2b3c4
Plan: none
Grant: none
Next: spawn squad-recon
Stop: after the plan

## Recon
Timestamp: 2026-09-02T09:03:40Z
Agent: squad-recon (claude-opus-5-5)
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
Timestamp: 2026-09-02T09:08:02Z
Agent: squad-pm (claude-fable-5-1)
Attempt: 1
Classification: STANDARD
High-stakes: no
Totals: 2 source files changed, 2 tests added, 2 work orders.

WO-1: parse --dry-run in src/cli/export.js and pass
dryRun to writeOutputs(); in src/cli/write.js, print each path and skip the
write when dryRun is set. WO-2: add one test per criterion to
test/export.test.js. Must NOT change: a real run's output. Verification plan:
npm test. Non-goals: the import command. Risks: none.

## Status — Plan approved, run SHELVED
Timestamp: 2026-09-02T09:15:10Z

The user approved the plan and asked to keep it shelved.
