## Goal — Locked
Timestamp: 2026-09-10T09:00:12Z
Run: 2026-09-10-invoice-owner
Attended: yes
Goal: Only the account that owns an invoice may download its PDF.
Acceptance criteria:
- AC1: GET /api/invoices/:id/pdf answers 404 to any account other than the invoice's owner.
- AC2: The owner still downloads the PDF with status 200.
Out of scope: the invoice list endpoint.
Assumptions: none

## Status
Timestamp: 2026-09-10T09:00:12Z
Run: 2026-09-10-invoice-owner
Mode: full
Worktree: /home/dev/app, branch main
Base: 7c1d2e3
Plan: none
Grant: all revisions, full-mode request
Next: spawn squad-recon
Stop: after the closing archive

## Recon
Timestamp: 2026-09-10T09:03:40Z
Agent: squad-recon (claude-opus-5-5)
Attempt: 1

Checks:
- goal facts: all confirmed
- `npm test` -> exit 0; 12 passed; tree changed: no
Map:
- src/routes/invoices.js:30-52 GET /api/invoices/:id/pdf: "router.get('/:id/pdf', requireSession, async (req, res) => {"; loads the invoice by id and streams its PDF with no owner check
Callers:
- the route <- src/app.js:18
Tests:
- test/invoices.test.js: 12 cases on the invoice routes
Invariants:
- AGENTS.md:4 "A resource another account owns answers 404, never 403.": at risk: the new check must answer 404
Open for the PM:
none found

## Status
Timestamp: 2026-09-10T09:03:51Z
Run: 2026-09-10-invoice-owner
Mode: full
Worktree: /home/dev/app, branch main
Base: 7c1d2e3
Plan: none
Grant: all revisions, full-mode request
Next: spawn squad-pm (PLAN)
Stop: after the closing archive

## PM — Plan
Timestamp: 2026-09-10T09:08:02Z
Agent: squad-pm (claude-fable-5-1)
Attempt: 1
Classification: STANDARD
High-stakes: yes
Totals: 1 source file changed, 2 tests added.

Tasks, in order: 1. in src/routes/invoices.js, after the invoice lookup at
line 34, answer 404 when invoice.accountId differs from req.session.accountId;
2. add two tests to test/invoices.test.js: another account gets 404, the owner
gets 200. Must NOT change: the invoice list endpoint. Verification plan: npm
test. Criteria: AC1 test 1; AC2 test 2. Non-goals: the list endpoint. Risks:
none.

## Status
Timestamp: 2026-09-10T09:08:20Z
Run: 2026-09-10-invoice-owner
Mode: full
Worktree: /home/dev/app, branch main
Base: 7c1d2e3
Plan: r1, work order all
Grant: all revisions, full-mode request
Next: spawn squad-executor (STANDARD)
Stop: after the closing archive

## Executor
Timestamp: 2026-09-10T09:16:27Z
Agent: squad-executor (claude-opus-5-5)
Attempt: 1
Plan: r1, work order all

Tasks: 1-2 of 2
Files changed: src/routes/invoices.js, test/invoices.test.js
Checks:
- `npm test` -> exit 0; 14 passed
Deviations: none
For acceptance: none
Commit: 7c1d2e3f4a5b, working tree 2 changed files

## Status
Timestamp: 2026-09-10T09:16:40Z
Run: 2026-09-10-invoice-owner
Mode: full
Worktree: /home/dev/app, branch main
Base: 7c1d2e3
Plan: r1, work order all
Grant: all revisions, full-mode request
Next: spawn squad-pm (ACCEPT)
Stop: after the closing archive

## PM — PASS
Timestamp: 2026-09-10T09:24:05Z
Agent: squad-pm (claude-fable-5-1)
Attempt: 1
High-stakes: yes

Tested: 7c1d2e3f4a5b, working tree 2 changed files
| Criterion | Result | How | Evidence |
|---|---|---|---|
| AC1 | met | reproduced | test 1: a second account gets 404; refutation, an anonymous request gets 401 from requireSession before the lookup |
| AC2 | met | reproduced | test 2: the owner gets 200 and the PDF bytes |
- `npm test` -> exit 0; 14 passed
Regressions: none
Outside scope: none
Executor points: none
The change sits on an auth path, so the log stays intact for the main session's
high-stakes review.

## Status
Timestamp: 2026-09-10T09:24:30Z
Run: 2026-09-10-invoice-owner
Mode: full
Worktree: /home/dev/app, branch main
Base: 7c1d2e3
Plan: r1, work order all
Grant: all revisions, full-mode request
Next: main-session high-stakes review
Stop: after the closing archive

## High-stakes review
Timestamp: 2026-09-10T09:31:44Z
Agent: main session (claude-fable-5-1)
Result: upheld
Rerun: Executor
Tested: 7c1d2e3f4a5b, working tree 2 changed files
Checked:
- `npm test` -> exit 0; 14 passed
- `git diff 7c1d2e3 -- src/routes/invoices.js` -> exit 0; one owner check added before the stream
Risks:
- another account reads the PDF | the owner check answers 404 before the stream (src/routes/invoices.js:35); the npm test check
- an anonymous caller reads the PDF | requireSession answers 401 before the handler (src/routes/invoices.js:30)
- the 404 shows that the invoice exists | it is the same 404 body an unknown id gets (src/routes/invoices.js:33-36)
Decisions after lock:
- none
