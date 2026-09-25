## Goal — Locked
Timestamp: 2026-09-02T09:00:12Z
Run: 2026-09-02-reset-cooldown
Attended: yes
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

## Recon
Timestamp: 2026-09-02T09:04:31Z
Agent: squad-recon (claude-opus-5-5)
Attempt: 1

Checks:
- goal facts: all confirmed
- `npm test` -> exit 0; tests 6, pass 6, fail 0; tree changed: no
Map:
- src/server/auth/auth.routes.js:6-13 registerAuthRoutes: POST /api/auth/reset-request answers 400 for a missing email, otherwise 200 with requestPasswordReset()'s result (line 11)
- src/server/auth/reset.service.js:14-29 requestPasswordReset: "function requestPasswordReset({ store, log, outbox, clock }, email) {"; an unknown address gets GENERIC_RESULT (line 17); a known one gets a hashed token row (lines 21-25), an email through sendEmail() (line 26), and a reset_email_sent event with the account id (line 27)
- src/server/auth/reset.service.js:3-6 GENERIC_RESULT: "const GENERIC_RESULT = Object.freeze({", module-private, not exported
- src/server/db/store.js:23-27 listResetTokens(accountId): an account's password_reset_tokens rows, oldest first; createdAt is epoch milliseconds from the injected clock
- src/server/log.js:3 EVENT_CODES: "const EVENT_CODES = Object.freeze(['reset_email_sent']);"; event() throws on any other code (lines 11-13)
- src/server/email/send.js:2-7 sendEmail: pushes the mail to the outbox
- src/server/middleware/rateLimit.js:2 createRateLimiter: the global IP limiter, 300 requests per IP per 5 minutes; there is no per-account throttle
Callers:
- requestPasswordReset <- src/server/auth/auth.routes.js:11
Tests:
- src/server/auth/__tests__/reset.routes.test.js: 6 cases through setup() (lines 8-14), run by npm test ("node --test"); the suite's clock helper is createFakeClock() in src/server/clock.js:5-13
Invariants:
- CLAUDE.md:3 "Auth responses are generic: no status code, body, or log line may reveal whether an account exists.": at risk: a refused request must return GENERIC_RESULT so every response stays identical
- CLAUDE.md:4 "Log events carry an event code and ids only, never an email address or a reset token.": at risk: a new event carries the account id only
- CLAUDE.md:5 "Tests never use real timers or sleep; use createFakeClock from src/server/clock.js.": holds
- CLAUDE.md:6 "No new dependencies: Node's standard library only.": holds
Open for the PM:
- the newest row from listResetTokens() gives the cooldown without a schema change
- a new event code needs an EVENT_CODES entry, or event() throws

## Status
Timestamp: 2026-09-02T09:04:40Z
Run: 2026-09-02-reset-cooldown
Mode: plan
Worktree: /home/dev/app, branch main
Base: 4f2c9a1
Plan: none
Grant: none
Next: spawn squad-pm (PLAN)
Stop: after the plan

## PM — Plan
Timestamp: 2026-09-02T09:09:48Z
Agent: squad-pm (claude-fable-5-1)
Attempt: 1
Classification: STANDARD
High-stakes: yes
Totals: 3 files changed, 3 tests added, 2 work orders (WO-1: 2 files, 2 tests; WO-2: 3 files, 1 test).

Spec: enforce a per-account 60-second cooldown inside
requestPasswordReset(), not the route, so every future caller inherits it. A
refused request returns GENERIC_RESULT, so no response changes.

WO-1, the cooldown (AC1, AC2, AC3 and AC5):
1. src/server/auth/reset.service.js: after GENERIC_RESULT (line 6) add
   `const RESEND_COOLDOWN_MS = 60 * 1000;`. In requestPasswordReset(), after
   the unknown-account return (lines 16-18), add
   `const tokens = store.listResetTokens(account.id);`,
   `const newest = tokens[tokens.length - 1];` and
   `if (newest && clock.now() - newest.createdAt < RESEND_COOLDOWN_MS) { return GENERIC_RESULT; }`.
   Within 60 seconds means less than 60,000 ms after the newest token.
2. src/server/auth/__tests__/reset.routes.test.js, two tests after the last
   one, using setup() and the fake clock. (a) ada requests, the clock advances
   59 s, ada requests again: the second response deep-equals the first, the
   outbox holds 1 email, listResetTokens(1) holds 1 row, and a request for
   grace then sends (outbox 2). (b) ada requests, the clock advances 60 s, ada
   requests again: outbox 2, listResetTokens(1) 2 rows.

WO-2, the cooldown event (AC4):
3. src/server/log.js: add 'reset_cooldown_hit' to EVENT_CODES (line 3).
4. src/server/auth/reset.service.js: in the cooldown branch, call
   `log.event('reset_cooldown_hit', { accountId: account.id });` before the
   return.
5. src/server/auth/__tests__/reset.routes.test.js, test (c): a request inside
   the cooldown logs exactly one reset_cooldown_hit event, with accountId 1 and
   no '@' in any event.

Must NOT change: the status or body of any response, auth.routes.js,
store.js, send.js, rateLimit.js, package.json. Verification plan: npm test
(8 pass after WO-1, 9 after WO-2), and every log.event call in the diff passes
only a code and accountId. Non-goals: per-IP throttling, admin-triggered
resets. Risks: none material; the tests use the fake clock only.

## Status
Timestamp: 2026-09-02T09:10:05Z
Run: 2026-09-02-reset-cooldown
Mode: plan
Worktree: /home/dev/app, branch main
Base: 4f2c9a1
Plan: r1, work order all
Grant: none
Next: await a grant for r1
Stop: here; a plan-mode run ends after the plan

## Decision
Timestamp: 2026-09-05T14:02:10Z
Type: park
Covers: r1, work order all
User's words: "Park the cooldown plan for now; I need the squad on the CSV export bug."

## Status
Timestamp: 2026-09-05T14:02:18Z
Run: 2026-09-02-reset-cooldown
Mode: plan
Worktree: /home/dev/app, branch main
Base: 4f2c9a1
Plan: r1, work order all
Grant: none
Next: none
Stop: here; the run is parked, and Stage 1 archives it for the new goal
