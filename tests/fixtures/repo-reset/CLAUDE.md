# Project rules

- Auth responses are generic: no status code, body, or log line may reveal whether an account exists.
- Log events carry an event code and ids only, never an email address or a reset token.
- Tests never use real timers or sleep; use createFakeClock from src/server/clock.js.
- No new dependencies: Node's standard library only.
