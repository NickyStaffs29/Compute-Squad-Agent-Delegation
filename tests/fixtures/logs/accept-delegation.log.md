## Goal — Locked
Timestamp: 2026-09-01T12:00:12Z
Run: 2026-09-01-release-notes

Goal: List every changed public function in the release notes for 2.4.0.
Acceptance criteria:
- docs/release-notes/2.4.0.md names each public function changed since tag v2.3.0.
- npm test passes.
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

Public functions are exported from src/index.js (lines 1-40). The notes live in
docs/release-notes/, one file per release. Tests: test/exports.test.js (4 cases).

## PM — Plan
Timestamp: 2026-09-01T12:07:45Z
Agent: squad-pm (claude-opus-5-5)

Totals: 1 doc file added, 0 source files changed.
Classification: MECHANICAL. Tasks, in order: 1. add docs/release-notes/2.4.0.md
listing each export from src/index.js whose body changed since v2.3.0; 2. run npm
test. Risks: none.

## Executor
Timestamp: 2026-09-01T12:12:20Z
Agent: squad-executor-mechanical (claude-sonnet-5)

Added docs/release-notes/2.4.0.md with 6 functions (task 1). `npm test` -> exit
0; 4 passed (task 2).

Deviations: none. For acceptance: the list came from git diff v2.3.0 -- src/.

## PM — Accept (pending)
Timestamp: 2026-09-01T12:18:02Z
Agent: squad-pm (claude-opus-5-5)

- `npm test` -> exit 0; 4 passed
The first criterion needs the full list of changed exports to compare against
the notes; that listing is zero-judgment work.

DELEGATE:
- [intern] For each name exported from src/index.js, print the name when
  `git diff --quiet v2.3.0 -- <its file>` exits 1. BLOCKING.

## Delegated — Accept
Timestamp: 2026-09-01T12:20:37Z

6 exports changed: parse, format, merge, split, pick, omit (procedure ran as
specified).

## PM — PASS
Timestamp: 2026-09-01T12:24:55Z
Agent: squad-pm (claude-opus-5-5)

- `npm test` -> exit 0; 4 passed
- The helper's 6 names match the 6 in docs/release-notes/2.4.0.md.
Both criteria met. Refutation attempted: an export re-exported from a second
file (none found). High-stakes: no. Verdict: PASS.
Archive target: compute-squad-archive/COMPUTE_SQUAD_LOG_2026-09-01_122502_2026-09-01-release-notes.md
