## Goal — Locked
Timestamp: 2026-09-12T14:02:10Z
Run: 2026-09-12-billing-note
Attended: yes
Goal: Add an annual-billing note under the plans table on the pricing page.
Acceptance criteria:
- AC1: public/index.html shows "Prices are per month, billed annually. Cancel any time." directly under the plans table.
- AC2: At a 390px-wide viewport the pricing page does not scroll horizontally: `npm run check:overflow` exits 0.
- AC3: `npm test` passes.
Out of scope: the plans, seats, and prices themselves; the page header.
Assumptions: none

## Status
Timestamp: 2026-09-12T14:02:10Z
Run: 2026-09-12-billing-note
Mode: full
Worktree: /home/dev/app, branch main
Base: 4f2c9a1
Plan: none
Grant: all revisions, full-mode request
Next: spawn squad-recon
Stop: after the PASS and the PM's archive
