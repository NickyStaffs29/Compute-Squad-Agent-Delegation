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
