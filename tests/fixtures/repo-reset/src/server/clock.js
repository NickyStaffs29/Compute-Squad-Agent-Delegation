// Time source. Production uses systemClock; tests use createFakeClock and
// move time with advance(ms) instead of waiting.
const systemClock = Object.freeze({ now: () => Date.now() });

function createFakeClock(start = Date.UTC(2026, 0, 1)) {
  let current = start;
  return {
    now: () => current,
    advance(ms) {
      current += ms;
    },
  };
}

module.exports = { systemClock, createFakeClock };
