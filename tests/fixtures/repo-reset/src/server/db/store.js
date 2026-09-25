// In-memory tables. accounts: { id, email }. password_reset_tokens:
// { id, accountId, tokenHash, createdAt }, createdAt in epoch milliseconds.
function createStore(accounts = []) {
  const accountRows = accounts.map((account, index) => ({
    id: index + 1,
    email: account.email.trim().toLowerCase(),
  }));
  const passwordResetTokens = [];

  return {
    findAccountByEmail(email) {
      const wanted = String(email).trim().toLowerCase();
      return accountRows.find((row) => row.email === wanted) || null;
    },

    insertResetToken({ accountId, tokenHash, createdAt }) {
      const row = { id: passwordResetTokens.length + 1, accountId, tokenHash, createdAt };
      passwordResetTokens.push(row);
      return row;
    },

    // Oldest first.
    listResetTokens(accountId) {
      return passwordResetTokens
        .filter((row) => row.accountId === accountId)
        .sort((a, b) => a.createdAt - b.createdAt || a.id - b.id);
    },
  };
}

module.exports = { createStore };
