## Goal — Locked
Timestamp: 2026-09-02T09:00:12Z
Run: 2026-09-02-reset-cooldown
Attended: yes
Audit: no
Goal: Add a 60-second resend cooldown to the password-reset email endpoint, per-account.
Acceptance criteria:
- AC1: A second reset request for the same account within 60 seconds of the first sends no new email and creates no new token row.
- AC2: A reset request 60 seconds or more after the account's newest token creates a new token and sends the email as normal.
- AC3: No response or log reveals whether an account exists (existing invariant preserved).
- AC4: A request refused by the cooldown logs the event code reset_cooldown_hit with the account id and no address.
- AC5: npm test passes.
Out of scope: per-IP throttling; admin-triggered resets (different service path).
Assumptions: none

## Status
Timestamp: 2026-09-02T09:00:12Z
Run: 2026-09-02-reset-cooldown
Mode: plan
Worktree: /home/dev/app, branch main
Base: 4f2c9a1
Plan: none
Grant: none
Next: spawn squad-recon
Stop: after the plan


## Decision
Timestamp: 2026-09-02T09:01:00Z
Type: invented
Covers: none
User's words: "Keep it shelved."
