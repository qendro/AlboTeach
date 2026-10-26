const {chromium} = require('playwright');
const fs = require('fs');
const assert = require('assert/strict');

(async () => {
  fs.mkdirSync('/output', {recursive: true});
  const browser = await chromium.launch({headless: true});
  const page = await browser.newPage({viewport: {width: 1440, height: 1050}, reducedMotion: 'reduce'});
  const base = process.env.QA_BASE_URL || 'http://localhost:4000';
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.goto(`${base}/login?role=parent`);
  if (await page.locator('#login-password').count()) await page.locator('#login-password').fill(process.env.PARENT_PASSWORD || '');
  await page.locator('#login-form button[type=submit]').click();
  await page.goto(`${base}/cards`);
  await page.locator('[data-phx-main].phx-connected').waitFor();
  const exported = await (await page.request.get(`${base}/cards/export`)).json();
  assert.equal(exported.cards.length, Number(process.env.EXPECTED_CARDS || '193'));
  assert.deepEqual(exported.cards.map(c => c.sort_order), exported.cards.map((_, i) => i + 1));
  assert.equal(await page.locator('#vocabulary tr').count(), exported.cards.length);
  for (const field of ['topic', 'subtopic', 'level', 'albanian', 'english', 'order']) {
    await page.locator(`#sort-${field}`).click();
    await page.waitForURL(`**sort=${field}`);
  }
  await page.locator('#vocabulary .studio-select input:enabled').first().check();
  await page.locator('#print-open').click();
  await page.locator('#print-preview-cards li').waitFor();
  assert.equal(await page.locator('#print-preview-cards li').count(), 1);
  await page.locator('#close-print').click();
  await page.evaluate(() => window.scrollTo(0, 0));
  await page.screenshot({path: '/output/studio-desktop.png'});
  await page.setViewportSize({width: 390, height: 844});
  await page.locator('#studio-sort-controls').scrollIntoViewIfNeeded();
  const mobileSelection = page.locator('#vocabulary .studio-select input:enabled').first();
  await mobileSelection.uncheck();
  await mobileSelection.check();
  await page.screenshot({path: '/output/studio-mobile-controls.png'});
  assert(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
  assert.deepEqual(errors, []);
  await browser.close();
  console.log(`Read-only studio verification passed: ${base}, ${exported.cards.length} cards, all sortable headers, preview and mobile layout.`);
})().catch(error => {console.error(error); process.exit(1);});
