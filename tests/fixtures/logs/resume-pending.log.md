## Goal — Locked
Timestamp: 2026-09-01T12:00:12Z
Audit: no
Run: 2026-09-01-release-notes

Goal: List every changed public function in the release notes for 2.4.0.
Acceptance criteria:
- AC1: docs/release-notes/2.4.0.md names each public function changed since tag v2.3.0.
- AC2: npm test passes.
Out of scope: internal helpers.
Assumptions: none.

## Status
Timestamp: 2026-09-01T12:00:12Z
Run: 2026-09-01-release-notes
Mode: full
Worktree: /home/dev/app, branch main
Base: 1a2b3c4
Plan: none
Grant: all revisions, full-mode request
Next: spawn squad-recon
Stop: after the PM verdict

## Recon
Timestamp: 2026-09-01T12:03:18Z
Agent: squad-recon (claude-sonnet-5)
Attempt: 1

Checks:
- goal facts: all confirmed
- `npm test` -> exit 0; 4 passed; tree changed: no
- `git tag --list v2.3.0` -> exit 0; v2.3.0
Map:
- src/index.js:1-40 the public exports: every public function is exported here
- docs/release-notes/: one file per release; 2.4.0.md does not exist yet
Callers:
none found
Tests:
- test/exports.test.js: 4 cases on the export list
Invariants:
none found
Open for the PM:
none found

## PM — Plan
Timestamp: 2026-09-01T12:07:45Z
Agent: squad-pm (claude-opus-5-5)
Attempt: 1
Classification: MECHANICAL
High-stakes: no
Totals: 1 doc file added, 0 source files changed.

Tasks, in order: 1. add docs/release-notes/2.4.0.md
listing each export from src/index.js whose body changed since v2.3.0; 2. run npm
test. Risks: none.

## Executor
Timestamp: 2026-09-01T12:12:20Z
Agent: squad-executor-mechanical (claude-sonnet-5)
Attempt: 1
Plan: r1, work order all

Tasks: 1-2 of 2
Files changed: docs/release-notes/2.4.0.md
Checks:
- `npm test` -> exit 0; 4 passed
Deviations: none
For acceptance:
- F1: the list of 6 functions came from git diff v2.3.0 -- src/
Commit: 1a2b3c4d5e6f, working tree 1 changed file

## PM — Accept (pending)
Timestamp: 2026-09-01T12:18:02Z
Agent: squad-pm (claude-opus-5-5)
Attempt: 1

- `npm test` -> exit 0; 4 passed
The first criterion needs the full list of changed exports to compare against
the notes; that listing is zero-judgment work.

DELEGATE:
- [intern] For each name exported from src/index.js, print the name when
  `git diff --quiet v2.3.0 -- <its file>` exits 1; return at most 10 lines.

## Delegated — Accept
Timestamp: 2026-09-01T12:20:37Z

6 exports changed: parse, format, merge, split, pick, omit (procedure ran as
specified).
