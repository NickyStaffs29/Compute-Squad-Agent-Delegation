const crypto = require('node:crypto');
const { sendEmail } = require('../email/send');
const GENERIC_RESULT = Object.freeze({
  ok: true,
  message: 'If an account exists for that address, a reset link is on its way.',
});

function hashToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

// Logs every request alike, then emails a known account a reset link.
// Unknown addresses get the same result and the same log event, no email.
function requestPasswordReset({ store, log, outbox, clock }, email) {
  log.event('reset_requested');
  const account = store.findAccountByEmail(email);
  if (!account) {
    return GENERIC_RESULT;
  }

  const token = crypto.randomBytes(32).toString('hex');
  store.insertResetToken({
    accountId: account.id,
    tokenHash: hashToken(token),
    createdAt: clock.now(),
  });
  sendEmail(outbox, { to: account.email, template: 'password-reset', token });
  return GENERIC_RESULT;
}

module.exports = { requestPasswordReset, hashToken };
