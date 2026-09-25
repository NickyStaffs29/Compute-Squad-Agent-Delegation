## Goal — Locked
Timestamp: 2026-09-04T10:00:12Z
Run: 2026-09-04-export-dry-run
Attended: yes
Audit: no
Goal: Add a --dry-run flag to the export command that prints the files it would write and writes nothing.
Acceptance criteria:
- AC1: export --dry-run writes no file and exits 0.
- AC2: export --dry-run prints one line per file a real run would write.
Out of scope: the import command.
Assumptions: none

## Status
Timestamp: 2026-09-04T10:00:12Z
Run: 2026-09-04-export-dry-run
Mode: full
Worktree: /home/dev/app, branch main
Base: 1a2b3c4
Plan: none
Grant: all revisions, full-mode request
Next: spawn squad-recon
Stop: after the PM verdict

## Recon
Timestamp: 2026-09-04T10:03:40Z
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

## Status
Timestamp: 2026-09-04T10:03:51Z
Run: 2026-09-04-export-dry-run
Mode: full
Worktree: /home/dev/app, branch main
Base: 1a2b3c4
Plan: none
Grant: all revisions, full-mode request
Next: spawn squad-pm (PLAN)
Stop: after the PM verdict

## PM — Plan
Timestamp: 2026-09-04T10:08:02Z
Agent: squad-pm (claude-fable-5-1)

Totals: 2 source files changed, 2 tests added.
Classification: STANDARD. High-stakes: no. Tasks, in order: 1. parse --dry-run in src/cli/export.js and pass dryRun to
writeOutputs(); 2. in src/cli/write.js, print each path and skip the write when
dryRun is set; 3. add one test per criterion to test/export.test.js. Must NOT
change: a real run's output. Verification plan: npm test. Non-goals: the import
command. Risks: none.
