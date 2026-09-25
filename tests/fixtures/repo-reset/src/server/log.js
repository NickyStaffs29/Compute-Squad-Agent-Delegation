// Structured log events. An event is a known code plus ids, never an email
// address or a token; an unknown code throws so a typo cannot ship.
const EVENT_CODES = Object.freeze(['reset_email_sent']);

function createLogger() {
  const events = [];

  return {
    events,
    event(code, fields = {}) {
      if (!EVENT_CODES.includes(code)) {
        throw new Error(`unknown log event code: ${code}`);
      }
      events.push({ code, ...fields });
    },
  };
}

module.exports = { createLogger, EVENT_CODES };
