## Goal — Locked
Timestamp: 2026-09-01T10:00:12Z

Goal: Add a --dry-run flag to the export command that prints the files it would write and writes nothing.
Acceptance criteria:
- AC1: export --dry-run writes no file and exits 0.
- AC2: export --dry-run prints one line per file a real run would write.
Out of scope: the import command.
Assumptions: none.

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
none found
Invariants:
none found
Open for the PM:
none found

DELEGATE:
- [intern] List every test file under test/ with its case count (procedure:
  grep -c "it(" per file). Non-blocking; context for the PM.
- [intern] List every call to fs.writeFileSync under src/cli/ with file and
  line (procedure: grep -n "writeFileSync" -r src/cli). Non-blocking.

## Delegated — Recon
Timestamp: 2026-09-01T10:05:10Z

test/export.test.js: 6 · test/import.test.js: 9 (procedure ran as specified).

## Delegated — Recon (cont.)
Timestamp: 2026-09-01T10:05:31Z

src/cli/write.js:8, src/cli/write.js:22 (procedure ran as specified).
