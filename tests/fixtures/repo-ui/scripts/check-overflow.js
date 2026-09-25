#!/usr/bin/env node
// The browser check: does public/index.html scroll sideways on a small phone?
// It opens the page in Chromium at a 390px-wide viewport and compares the
// page's width with the viewport's.
//
//   npm run check:overflow                     run the check
//   node scripts/check-overflow.js --probe     only confirm Chromium starts
//
// Exit 0: no horizontal overflow. Exit 1: the page is wider than the viewport;
// each element that sticks out is listed. Exit 2: the check could not run
// (Playwright is not installed, or it has no Chromium).
//
// Playwright comes from this project's node_modules or, failing that, the
// global npm root. It finds its browsers the usual way: PLAYWRIGHT_BROWSERS_PATH
// when set, otherwise its own cache directory.
'use strict';

const path = require('node:path');
const { execFileSync } = require('node:child_process');
const { pathToFileURL } = require('node:url');

const VIEWPORT = { width: 390, height: 844 };
const PAGE = path.join(__dirname, '..', 'public', 'index.html');

function loadPlaywright() {
  try {
    return require('playwright');
  } catch (localError) {
    try {
      const root = execFileSync('npm', ['root', '-g'], { encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] });
      return require(path.join(root.trim(), 'playwright'));
    } catch (globalError) {
      return null;
    }
  }
}

// Runs in the page: the viewport width, the page width, and the outermost
// elements whose right edge passes the viewport.
function measure() {
  const viewport = document.documentElement.clientWidth;
  const wide = (el) => el.getBoundingClientRect().right > viewport + 0.5;
  const offenders = [];
  for (const el of document.body.querySelectorAll('*')) {
    if (!wide(el) || (el.parentElement !== document.body && wide(el.parentElement))) {
      continue;
    }
    const box = el.getBoundingClientRect();
    const classes = typeof el.className === 'string' ? el.className.trim().split(/\s+/).filter(Boolean) : [];
    offenders.push({
      name: [el.tagName.toLowerCase(), ...classes].join('.'),
      width: Math.round(box.width),
      right: Math.round(box.right),
    });
  }
  return { viewport, page: document.documentElement.scrollWidth, offenders };
}

async function main() {
  const playwright = loadPlaywright();
  if (!playwright) {
    console.log('check-overflow: cannot run: Playwright is not installed');
    return 2;
  }
  let browser;
  try {
    browser = await playwright.chromium.launch();
  } catch (error) {
    console.log('check-overflow: cannot run: Playwright has no Chromium: ' + String(error.message).split('\n')[0]);
    return 2;
  }
  try {
    if (process.argv.includes('--probe')) {
      console.log('check-overflow: Chromium ' + browser.version() + ' starts');
      return 0;
    }
    const page = await browser.newPage({ viewport: VIEWPORT });
    await page.goto(pathToFileURL(PAGE).href);
    const result = await page.evaluate(measure);
    const extra = result.page - result.viewport;
    if (extra <= 0) {
      console.log(`check-overflow: no horizontal overflow at ${result.viewport}px (page ${result.page}px wide)`);
      return 0;
    }
    console.log(`check-overflow: overflow ${extra}px at ${result.viewport}px (page ${result.page}px wide)`);
    for (const item of result.offenders) {
      console.log(`- ${item.name}: ${item.width}px wide, right edge at ${item.right}px`);
    }
    return 1;
  } finally {
    await browser.close();
  }
}

main().then(
  (code) => {
    process.exitCode = code;
  },
  (error) => {
    console.log('check-overflow: cannot run: ' + String(error.message).split('\n')[0]);
    process.exitCode = 2;
  },
);
