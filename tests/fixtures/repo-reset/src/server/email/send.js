// Mail transport. The outbox array stands in for the provider queue.
function sendEmail(outbox, { to, template, token }) {
  if (!to || !template) {
    throw new Error('sendEmail needs a recipient and a template');
  }
  outbox.push({ to, template, token });
}

module.exports = { sendEmail };
