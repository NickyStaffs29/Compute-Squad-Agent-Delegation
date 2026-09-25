const { createStore } = require('./db/store');
const { createLogger } = require('./log');
const { systemClock } = require('./clock');
const { createRateLimiter } = require('./middleware/rateLimit');
const { registerAuthRoutes } = require('./auth/auth.routes');

// Builds the service in-process: a route table behind the global IP limiter.
// handle() takes { method, path, ip, body } and returns { status, body }.
function createApp({ clock = systemClock, accounts = [] } = {}) {
  const store = createStore(accounts);
  const log = createLogger();
  const outbox = [];
  const limiter = createRateLimiter({ clock });
  const routes = new Map();
  const route = (method, path, handler) => routes.set(`${method} ${path}`, handler);

  registerAuthRoutes(route, { store, log, outbox, clock });

  function handle({ method, path, ip = '127.0.0.1', body = {} }) {
    if (!limiter.allow(ip)) {
      return { status: 429, body: { error: 'too_many_requests' } };
    }
    const handler = routes.get(`${method} ${path}`);
    if (!handler) {
      return { status: 404, body: { error: 'not_found' } };
    }
    return handler(body);
  }

  return { handle, store, log, outbox };
}

module.exports = { createApp };
