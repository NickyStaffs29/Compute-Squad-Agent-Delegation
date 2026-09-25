// Global IP flood limiter: at most `limit` requests per IP per window.
function createRateLimiter({ clock, limit = 300, windowMs = 5 * 60 * 1000 }) {
  const hits = new Map();

  return {
    allow(ip) {
      const now = clock.now();
      const recent = (hits.get(ip) || []).filter((at) => now - at < windowMs);
      if (recent.length >= limit) {
        hits.set(ip, recent);
        return false;
      }
      recent.push(now);
      hits.set(ip, recent);
      return true;
    },
  };
}

module.exports = { createRateLimiter };
