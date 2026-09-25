const crypto = require('node:crypto');
const { sendEmail } = require('../email/send');
const GENERIC_RESULT = Object.freeze({
  ok: true,
  message: 'If an account exists for that address, a reset link is on its way.',
});

function hashToken(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

// Creates a reset token for the account and emails the link. Unknown
// addresses get the same result and no email.
function requestPasswordReset({ store, log, outbox, clock }, email) {
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
  log.event('reset_email_sent', { accountId: account.id });
  return GENERIC_RESULT;
}

module.exports = { requestPasswordReset, hashToken };
