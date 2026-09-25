const test = require('node:test');
const assert = require('node:assert/strict');
const { createApp } = require('../../app');
const { createFakeClock } = require('../../clock');

const ACCOUNTS = [{ email: 'ada@example.com' }, { email: 'grace@example.com' }];

function setup() {
  const clock = createFakeClock();
  const app = createApp({ clock, accounts: ACCOUNTS });
  const reset = (email, ip) =>
    app.handle({ method: 'POST', path: '/api/auth/reset-request', ip, body: { email } });
  return { clock, app, reset };
}

test('a reset request for a known account sends one email and stores one hashed token', () => {
  const { app, reset } = setup();
  const res = reset('ada@example.com');
  assert.equal(res.status, 200);
  assert.equal(app.outbox.length, 1);
  assert.equal(app.outbox[0].to, 'ada@example.com');
  const rows = app.store.listResetTokens(1);
  assert.equal(rows.length, 1);
  assert.notEqual(rows[0].tokenHash, app.outbox[0].token);
});

test('an unknown address gets the same response and no email', () => {
  const { app, reset } = setup();
  const known = reset('ada@example.com');
  const unknown = reset('nobody@example.com');
  assert.deepEqual(unknown, known);
  assert.equal(app.outbox.length, 1);
});

test('the account lookup ignores case and surrounding spaces', () => {
  const { app, reset } = setup();
  reset('  Grace@Example.com ');
  assert.equal(app.outbox.length, 1);
  assert.equal(app.outbox[0].to, 'grace@example.com');
});

test('a request without an email is a 400', () => {
  const { app, reset } = setup();
  assert.equal(reset('').status, 400);
  assert.equal(app.outbox.length, 0);
});

test('no log event carries an address or a token', () => {
  const { app, reset } = setup();
  reset('ada@example.com');
  reset('nobody@example.com');
  const logged = JSON.stringify(app.log.events);
  assert.deepEqual(app.log.events.map((e) => e.code), ['reset_email_sent']);
  assert.ok(!logged.includes('@'));
  assert.ok(!logged.includes(app.outbox[0].token));
});

test('the global IP limiter allows 300 requests per IP per 5 minutes', () => {
  const { clock, reset } = setup();
  for (let i = 0; i < 300; i += 1) {
    assert.equal(reset('nobody@example.com', '10.0.0.1').status, 200);
  }
  assert.equal(reset('nobody@example.com', '10.0.0.1').status, 429);
  assert.equal(reset('nobody@example.com', '10.0.0.2').status, 200);
  clock.advance(5 * 60 * 1000);
  assert.equal(reset('nobody@example.com', '10.0.0.1').status, 200);
});
