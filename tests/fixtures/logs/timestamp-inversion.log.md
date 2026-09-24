## Goal — Locked
Timestamp: 2026-09-01T10:00:12Z

Goal: Add a --dry-run flag to the export command that prints the files it would write and writes nothing.
Acceptance criteria:
- export --dry-run writes no file and exits 0.
- export --dry-run prints one line per file a real run would write.
Out of scope: the import command.
Assumptions: none.

## Recon
Timestamp: 2026-09-01T10:03:40Z
Agent: squad-recon (claude-sonnet-5)

The command is defined in src/cli/export.js (lines 12-58). It writes through
writeOutputs() in src/cli/write.js (lines 5-31), its only caller. Tests:
test/export.test.js (6 cases).

## PM — Plan
Timestamp: 2026-09-01T10:01:05Z
Agent: squad-pm (claude-opus-5-5)

Totals: 2 source files changed, 2 tests added.
Classification: STANDARD. Tasks, in order: 1. parse --dry-run in
src/cli/export.js and pass dryRun to writeOutputs(); 2. in src/cli/write.js,
print each path and skip the write when dryRun is set; 3. add one test per
criterion to test/export.test.js. Must NOT change: a real run's output.
Verification plan: npm test. Non-goals: the import command. Risks: none.
