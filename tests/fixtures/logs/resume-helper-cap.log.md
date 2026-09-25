## Goal — Locked
Timestamp: 2026-09-05T09:00:04Z
Run: 2026-09-05-deprecation-report
Attended: yes
Audit: no
Goal: Add docs/deprecations.md listing every exported function marked @deprecated in the six packages under packages/.
Acceptance criteria:
- AC1: docs/deprecations.md lists exactly the exports whose JSDoc carries @deprecated, one line each with its package.
- AC2: npm test passes.
Out of scope: removing any deprecated function.
Assumptions: none

## Status
Timestamp: 2026-09-05T09:00:04Z
Run: 2026-09-05-deprecation-report
Mode: plan
Worktree: /home/dev/mono, branch main
Base: 7c1d0e2
Plan: none
Grant: none
Next: spawn squad-recon
Stop: after the plan

## Recon
Timestamp: 2026-09-05T09:04:12Z
Agent: squad-recon (claude-opus-5-5)
Attempt: 1

Checks:
- goal facts: all confirmed
- `npm test` -> exit 0; 4 passed; tree changed: no
- `ls packages` -> exit 0; auth cli core http store util
Map:
- packages/{core,cli,http,store,auth,util}/src/index.js: each package's exports
- docs/: no deprecations page yet
Callers:
none found
Tests:
- npm test: every package's suite, 41 cases
Invariants:
none found
Open for the PM:
- the per-package listing below is zero-judgment work the map does not wait for

DELEGATE:
- [intern] packages/core: print each export of src/index.js whose JSDoc has @deprecated; return at most 5 lines.
- [intern] packages/cli: the same procedure; return at most 5 lines.
- [intern] packages/http: the same procedure; return at most 5 lines.
- [intern] packages/store: the same procedure; return at most 5 lines.
- [intern] packages/auth: the same procedure; return at most 5 lines.
- [intern] packages/util: the same procedure; return at most 5 lines.

## Status
Timestamp: 2026-09-05T09:04:25Z
Run: 2026-09-05-deprecation-report
Mode: plan
Worktree: /home/dev/mono, branch main
Base: 7c1d0e2
Plan: none
Grant: none
Next: run Recon's DELEGATE: block
Stop: after the plan

## Delegated — Recon
Timestamp: 2026-09-05T09:07:40Z

- packages/core: parseLegacy, toV1 (procedure ran as specified).
- packages/cli: none (procedure ran as specified).
- packages/http: rawRequest (procedure ran as specified).
- packages/store: openSync (procedure ran as specified).
- packages/auth: none (procedure ran as specified).
- packages/util: not run: helper cap reached.
