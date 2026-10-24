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
  page.on('console', message => {if (message.type() === 'error') errors.push(message.text());});
  const connected = () => page.locator('[data-phx-main].phx-connected').waitFor();
  let healthy = false;
  for (let attempt = 0; attempt < 40; attempt++) {
    try { healthy = (await page.request.get(`${base}/health`)).ok(); } catch {}
    if (healthy) break;
    await new Promise(resolve => setTimeout(resolve, 250));
  }
  assert(healthy, 'QA release must become healthy');
  const download = async (button, filename) => {
    const pending = page.waitForEvent('download');
    await page.locator(button).click();
    const file = await pending;
    assert.equal(await file.failure(), null);
    await file.saveAs(`/output/${filename}`);
    assert(fs.readFileSync(`/output/${filename}`).subarray(0, 5).equals(Buffer.from('%PDF-')));
  };
  const screenshot = async name => {
    await page.evaluate(() => {document.activeElement?.blur(); window.scrollTo(0, 0);});
    await page.screenshot({path: `/output/${name}.png`, fullPage: !name.startsWith('selection-toolbar')});
    assert(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), 'No horizontal overflow');
  };
  const clearSelection = async () => {
    if (!(await page.locator('#select-visible').isChecked())) {
      await page.locator('#select-visible').check();
      await page.locator('#select-all-control[data-state="all"]').waitFor();
    }
    await page.locator('#select-visible').uncheck();
    await page.locator('#print-selected-count').filter({hasText: '0 selected'}).waitFor();
  };
  const openPrint = async () => {
    await page.locator('#print-open').click();
    await page.locator('#print-modal').waitFor();
  };
  const closePrint = async () => {
    await page.locator('#close-print').click();
    await page.locator('#print-modal').waitFor({state: 'detached'});
  };
  await page.goto(`${base}/cards/print`);
  assert.equal(new URL(page.url()).pathname, '/login');
  for (const role of ['learner', 'parent']) {
    await page.goto(`${base}/login?role=${role}`);
    await page.locator('#login-form button[type=submit]').click();
    await connected();
    await page.goto(`${base}/cards/print`);
    await connected();
    assert.equal(new URL(page.url()).pathname, '/cards');
    assert.equal(await page.locator('nav a[href="/cards/print"]').count(), 0);
    assert.equal(await page.locator('#vocabulary tr').count(), 12);
    assert(await page.locator('#new-card').isVisible());
    await page.locator('#select-visible').focus();
    await page.keyboard.press('Space');
    await page.locator('#select-all-control[data-state="all"]').waitFor();
    assert(await page.locator('#select-visible').isChecked());
    await page.keyboard.press('Space');
    await page.locator('#select-all-control[data-state="none"]').waitFor();
    assert.equal(await page.locator('#select-visible').isChecked(), false);
    await openPrint();
    assert(await page.locator('#download-cards').isDisabled());
    assert.equal(await page.locator('#print_image_side').inputValue(), 'albanian');
    await download('#download-calibration', `${role}-calibration.pdf`);
    await closePrint();
    for (let index = 0; index < 9; index++) {
      await page.locator('#vocabulary .studio-select input').nth(index).check();
    }
    const firstCounter = page.locator('#vocabulary tr').first().locator('.studio-print-count');
    const previousCount = Number(await firstCounter.getAttribute('data-print-count'));
    const firstCounterId = await firstCounter.getAttribute('id');
    await page.locator('#print-selected-count').filter({hasText: '9 selected'}).waitFor();
    assert(await page.locator('#select-visible').evaluate(input => input.indeterminate));
    assert.equal(await page.locator('#select-visible').getAttribute('aria-checked'), 'mixed');
    assert.equal(await page.locator('#vocabulary .studio-select input:checked').count(), 9);
    await screenshot(`${role}-studio-desktop`);
    await openPrint();
    assert.match(await page.locator('#print-page-count').innerText(), /2 sheets · 4 PDF pages/);
    await screenshot(`${role}-print-dialog-desktop`);
    await download('#download-cards', `${role}-cards.pdf`);
    await page.locator(`#${firstCounterId}[data-print-count="${previousCount + 1}"]`).waitFor();
    await closePrint();
    await page.locator('#filters_search').fill('mollë');
    await page.waitForFunction(() => document.querySelectorAll('#vocabulary tr').length === 1);
    assert.match(await page.locator('#print-selected-count').innerText(), /9 selected/);
    await page.locator('#filters_search').fill('no-matching-fixture');
    await page.locator('#cards-empty').waitFor();
    assert.match(await page.locator('#print-selected-count').innerText(), /9 selected/);
    await page.locator('#filters_search').fill('');
    await page.waitForFunction(() => document.querySelectorAll('#vocabulary tr').length === 12);
    await openPrint();
    await page.locator('#print_per_sheet').selectOption('10');
    await page.locator('#print-page-count').filter({hasText: '2 PDF pages'}).waitFor();
    await page.locator('#print_image_side').selectOption('english');
    await page.locator('#print_flip').selectOption('short-edge');
    await page.locator('#print-adjustments summary').click();
    await page.locator('#print_back_x_mm').fill('0.5');
    await page.locator('#print_back_y_mm').fill('-0.5');
    await download('#download-cards', `${role}-cards-ten-short-edge.pdf`);
    await page.locator(`#${firstCounterId}[data-print-count="${previousCount + 2}"]`).waitFor();
    await download('#download-calibration', `${role}-calibration-ten-short-edge.pdf`);
    assert.equal(await firstCounter.getAttribute('data-print-count'), String(previousCount + 2));
    await page.setViewportSize({width: 390, height: 844});
    await screenshot(`${role}-print-dialog-mobile`);
    await closePrint();
    await screenshot(`${role}-studio-mobile`);
    await clearSelection();
    await page.locator('#print-selected-count').filter({hasText: '0 selected'}).waitFor();
    await page.locator('#select-visible').click();
    await page.locator('#print-selected-count').filter({hasText: '12 selected'}).waitFor();
    await page.locator('#vocabulary .studio-select input').first().uncheck();
    await page.locator('#print-selected-count').filter({hasText: '11 selected'}).waitFor();
    await page.locator('#select-new').click();
    await page.locator('#print-selected-count').filter({hasText: '3 selected'}).waitFor();
    assert.equal(await page.locator('#vocabulary tr:has(input:checked) .studio-print-count[data-print-count="0"]').count(), 3);
    await page.setViewportSize({width: 1440, height: 1050});
  }
  // More than 20 synthetic cards exercise forward selection and persistence.
  await page.locator('#import-open').click();
  await page.locator('#import_json').fill(JSON.stringify({cards: Array.from({length: 24}, (_, index) => ({
    concept: `qa.selection.${index}`, albanian: `Synthetic batch ${index + 1}`, english: `Synthetic batch item ${index + 1}`,
    category: 'qa-batch-selection', source: 'Software fixture, not linguistic evidence', image: index % 2 === 0 ? 'apple' : ''
  }))}));
  await page.locator('#import-submit').click();
  await page.locator('#import-modal').waitFor({state: 'detached'});
  await clearSelection();
  await page.locator('#filters_search').fill('qa-batch-selection');
  await page.waitForFunction(() => document.querySelectorAll('#vocabulary tr').length === 24);
  await page.locator('#selection-size-20').click();
  await page.locator('#selection-size-20[aria-pressed=true]').waitFor();
  await page.locator('#vocabulary .studio-select input').nth(2).check();
  await page.locator('#print-selected-count').filter({hasText: '20 selected'}).waitFor();
  for (let index = 0; index < 24; index++) {
    assert.equal(await page.locator('#vocabulary .studio-select input').nth(index).isChecked(), index >= 2 && index < 22);
  }
  await page.locator('#vocabulary .studio-select input').nth(2).uncheck();
  await page.locator('#print-selected-count').filter({hasText: '19 selected'}).waitFor();
  await clearSelection();
  await page.locator('#vocabulary .studio-select input').nth(2).check();
  await page.locator('#print-selected-count').filter({hasText: '20 selected'}).waitFor();
  await openPrint();
  await download('#download-cards', 'batch-twenty-cards.pdf');
  await closePrint();
  await page.waitForFunction(() => document.querySelectorAll('#vocabulary .studio-print-count[data-print-count="1"]').length === 20);
  await screenshot('selection-toolbar-desktop');
  await page.locator('#select-new').click();
  await page.locator('#print-selected-count').filter({hasText: '4 selected'}).waitFor();
  await page.setViewportSize({width: 390, height: 844});
  await screenshot('selection-toolbar-mobile');
  await page.reload();
  await connected();
  await page.locator('#filters_search').fill('qa-batch-selection');
  await page.waitForFunction(() => document.querySelectorAll('#vocabulary tr').length === 24);
  assert.equal(await page.locator('#vocabulary .studio-print-count[data-print-count="1"]').count(), 20);
  await page.locator('#select-new').click();
  await page.locator('#print-selected-count').filter({hasText: '4 selected'}).waitFor();
  await clearSelection();
  await page.locator('#print-selected-count').filter({hasText: '0 selected'}).waitFor();
  await page.locator('#selection-size-20').click();
  await page.locator('#selection-size-20[aria-pressed=true]').waitFor();
  await page.locator('#vocabulary .studio-select input').last().check();
  await page.locator('#print-selected-count').filter({hasText: '1 selected'}).waitFor();
  await clearSelection();
  await page.locator('#select-visible').check();
  await page.locator('#print-selected-count').filter({hasText: '24 selected'}).waitFor();
  await openPrint();
  await page.locator('#print_per_sheet').selectOption('21');
  await page.locator('#print-page-count').filter({hasText: '2 sheets · 4 PDF pages'}).waitFor();
  await page.locator('#print_image_side').selectOption('english');
  await page.locator('#print_flip').selectOption('long-edge');
  await download('#download-cards', 'grid-3x7-cards-long-edge.pdf');
  await download('#download-calibration', 'grid-3x7-calibration.pdf');
  await page.locator('#print_flip').selectOption('short-edge');
  await download('#download-cards', 'grid-3x7-cards-short-edge.pdf');
  await screenshot('grid-3x7-print-dialog-mobile');
  await page.locator('#print_image_side').selectOption('albanian');
  await page.locator('#print_flip').selectOption('long-edge');
  await download('#download-cards', 'grid-3x7-pictures-albanian.pdf');
  assert.deepEqual(errors, []);
  await browser.close();
  console.log('Studio print QA passed: both roles, real downloads including 3x7 cards and calibration, live persistent print counters, select all/new, 20-card selection and end-of-list behavior, desktop/mobile, no browser errors.');
})().catch(error => {console.error(error); process.exit(1);});
