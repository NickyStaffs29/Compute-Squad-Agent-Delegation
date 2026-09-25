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
Attempt: 1

The command is defined in src/cli/export.js (lines 12-58). It writes through
writeOutputs() in src/cli/write.js (lines 5-31), its only caller.

DELEGATE:
- [intern] List every test file under test/ with its case count (procedure:
  grep -c "it(" per file). Non-blocking; context for the PM.

## Delegated — Executor
Timestamp: 2026-09-01T10:05:10Z

test/export.test.js: 6 · test/import.test.js: 9 (procedure ran as specified).
