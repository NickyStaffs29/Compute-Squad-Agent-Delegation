## Goal — Locked
Timestamp: 2026-09-05T09:00:04Z
Run: 2026-09-05-deprecation-report
Attended: yes
Goal: Add docs/deprecations.md listing every exported function marked @deprecated in the six packages under packages/.
Acceptance criteria:
- docs/deprecations.md lists exactly the exports whose JSDoc carries @deprecated, one line each with its package.
- npm test passes.
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

The six packages are packages/{core,cli,http,store,auth,util}, each exporting
from its src/index.js. docs/ has no deprecations page yet. Tests: npm test runs
every package's suite (41 cases). The per-package listing below is
zero-judgment work the map does not wait for.

Risks: none blocking.

DELEGATE:
- [intern] packages/core: print each export of src/index.js whose JSDoc has @deprecated.
- [intern] packages/cli: the same procedure.
- [intern] packages/http: the same procedure.
- [intern] packages/store: the same procedure.
- [intern] packages/auth: the same procedure.
- [intern] packages/util: the same procedure.

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
