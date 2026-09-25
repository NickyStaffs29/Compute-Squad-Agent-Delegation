// Formats a whole number of cents as US dollars: 900 -> "$9.00".
// The page loads this file with a script tag; node:test loads it with require.
function formatPrice(cents) {
  if (!Number.isInteger(cents) || cents < 0) {
    throw new RangeError('cents must be a whole number of at least 0');
  }
  const dollars = Math.floor(cents / 100);
  const rest = String(cents % 100).padStart(2, '0');
  return '$' + dollars + '.' + rest;
}

if (typeof module === 'object' && module.exports) {
  module.exports = { formatPrice };
}
