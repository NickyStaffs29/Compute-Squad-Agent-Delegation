const { requestPasswordReset } = require('./reset.service');

// POST /api/auth/reset-request { email }
// Always answers 200 with the service's generic result for a well-formed
// request, so the response never says whether the account exists.
function registerAuthRoutes(route, deps) {
  route('POST', '/api/auth/reset-request', (body) => {
    if (typeof body.email !== 'string' || body.email.trim() === '') {
      return { status: 400, body: { error: 'email_required' } };
    }
    return { status: 200, body: requestPasswordReset(deps, body.email) };
  });
}

module.exports = { registerAuthRoutes };
