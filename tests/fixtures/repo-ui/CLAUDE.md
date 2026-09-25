# Project rules

- The site is plain HTML, CSS, and browser JavaScript in public/, with no build step.
- Every price on a page comes from formatPrice in public/price.js through a data-cents attribute; never type a formatted price into the HTML.
- Tests use node:test and run with npm test.
- No new dependencies. The browser check, npm run check:overflow, uses the Playwright already installed on the machine.
