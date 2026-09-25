const test = require('node:test');
const assert = require('node:assert/strict');
const { formatPrice } = require('../public/price');

test('formatPrice writes whole dollars with two decimals', () => {
  assert.equal(formatPrice(900), '$9.00');
  assert.equal(formatPrice(19900), '$199.00');
});

test('formatPrice keeps the cents', () => {
  assert.equal(formatPrice(4905), '$49.05');
  assert.equal(formatPrice(7), '$0.07');
});

test('formatPrice refuses a negative or fractional amount', () => {
  assert.throws(() => formatPrice(-1), RangeError);
  assert.throws(() => formatPrice(9.5), RangeError);
});
