## Goal — Locked
Timestamp: 2026-09-01T11:00:12Z

Goal: Store uploaded avatars at most 512 pixels on the long side.
Acceptance criteria:
- An upload larger than 512 pixels is stored scaled to 512 on the long side.
- npm test passes.
Out of scope: existing avatars.
Assumptions: none.

## Recon
Timestamp: 2026-09-01T11:04:09Z
Agent: squad-recon (claude-sonnet-5)

Uploads land in src/avatar/upload.js (lines 20-61), which calls sharp through
resize() in src/avatar/image.js (lines 3-18). Tests: test/avatar.test.js (5
cases).

## PM — Plan
Timestamp: 2026-09-01T11:09:33Z
Agent: squad-pm (claude-opus-5-5)

Totals: 1 source file changed, 1 test added.
Classification: MECHANICAL. Tasks, in order: 1. in src/avatar/image.js, pass
{ width: 512, height: 512, fit: "inside" } to resize(); 2. add one test with a
1024 by 768 upload. Verification plan: npm test. Risks: none.

## Executor
Timestamp: 2026-09-01T11:14:50Z
Agent: squad-executor-haiku (claude-haiku-5)

Implemented tasks 1 and 2 in src/avatar/image.js and test/avatar.test.js.
`npm test` -> exit 0; 6 passed.

Deviations: none. For acceptance: the test fixture is a PNG; JPEG uploads take
the same path.

## PM — Accept (pending)
Timestamp: 2026-09-01T11:22:31Z
Agent: squad-pm (claude-opus-5-5)

- `npm test` -> exit 0; 6 passed
The first criterion holds for new uploads, but src/avatar/upload.js:44 also
re-encodes every stored avatar on its next read, which the locked goal puts out
of scope.

BLOCKER:
- needs-human: whether re-encoding stored avatars on read is acceptable or the goal must exclude it
- why: src/avatar/upload.js:44 re-encodes on read, so existing avatars change despite "Out of scope: existing avatars."
