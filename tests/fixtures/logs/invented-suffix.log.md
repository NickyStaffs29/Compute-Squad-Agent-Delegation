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
writeOutputs() in src/cli/write.js (lines 5-31), its only caller. Tests:
test/export.test.js (6 cases).

## Goal — Locked (addendum)
Timestamp: 2026-09-01T10:05:02Z

Addendum: the dry run also prints the total byte count.
