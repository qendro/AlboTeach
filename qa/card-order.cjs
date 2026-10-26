const {chromium} = require('playwright');
const fs = require('fs');
const assert = require('assert/strict');

(async () => {
  fs.mkdirSync('/output', {recursive: true});
  const browser = await chromium.launch({headless: true});
  const context = await browser.newContext({viewport: {width: 1440, height: 1050}, reducedMotion: 'reduce'});
  const page = await context.newPage();
  const base = process.env.QA_BASE_URL || 'http://localhost:4000';
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  const connected = target => target.locator('[data-phx-main].phx-connected').waitFor();
  const rows = () => page.locator('#vocabulary tr');
  const positions = () => page.locator('#vocabulary .studio-position').allTextContents();
  const waitCount = count => page.waitForFunction(n => document.querySelectorAll('#vocabulary tr').length === n, count);
  const screenshot = async name => {
    await page.screenshot({path: `/output/${name}.png`});
    assert(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), 'No viewport overflow');
  };
  let healthy = false;
  for (let attempt = 0; attempt < 60; attempt++) {
    try { healthy = (await page.request.get(`${base}/health`)).ok(); } catch {}
    if (healthy) break;
    await new Promise(resolve => setTimeout(resolve, 250));
  }
  assert(healthy, 'QA app must become healthy');
  await page.goto(`${base}/login?role=parent`);
  await page.locator('#login-form button[type=submit]').click();
  await page.goto(`${base}/cards`);
  await connected(page);
  await page.locator('#cards-empty').waitFor();

  if (process.env.QA_PHASE === 'empty-restart') {
    await page.locator('#new-card').click();
    await page.locator('#card_albanian').fill('Synthetic restart');
    await page.locator('#card_english').fill('Synthetic restart meaning');
    await page.locator('#card_category').fill('Restart');
    await page.locator('#save-card').click();
    await page.locator('#card-modal').waitFor({state: 'detached'});
    assert.deepEqual(await positions(), ['1']);
    await page.setViewportSize({width: 390, height: 844});
    await page.locator('#studio-sort-controls').scrollIntoViewIfNeeded();
    await screenshot('studio-order-mobile-controls');
    console.log('Empty collection stayed empty after restart; next card starts at 1.');
    await browser.close();
    return;
  }

  const cards = Array.from({length: 24}, (_, index) => ({
    concept: `qa.order.${index}`, albanian: `SQ ${String(index + 1).padStart(2, '0')}`,
    english: `EN ${String(24 - index).padStart(2, '0')}`,
    category: index % 2 ? 'Topic B' : 'Topic A', subcategory: index % 3 ? 'Objects' : 'Fruit',
    difficulty: index % 2 ? 'growing' : 'beginner', image: index % 3 ? '' : 'apple',
    source: 'Synthetic software fixture, not linguistic evidence'
  }));
  await page.locator('#import-open').click();
  await page.locator('#import_json').fill(JSON.stringify({cards}));
  await page.locator('#import-submit').click();
  await page.locator('#import-modal').waitFor({state: 'detached'});
  await waitCount(24);
  assert.deepEqual(await positions(), cards.map((_, i) => String(i + 1)));
  assert.equal(await page.locator('thead th').count(), 10);
  assert(await page.locator('#move-up-1').isDisabled());
  assert(await page.locator('#move-down-24').isDisabled());

  const second = await page.context().newPage();
  await second.goto(`${base}/cards`);
  await connected(second);
  await page.locator('#move-up-5').click();
  await page.waitForFunction(() => document.querySelector('#order-5').textContent === '4');
  await second.waitForFunction(() => document.querySelector('#order-5').textContent === '4');
  assert.equal(await page.locator('#order-4').innerText(), '5');
  await page.locator('#move-down-5').click();
  await page.waitForFunction(() => document.querySelector('#order-5').textContent === '5');
  await second.close();
  await screenshot('studio-order-desktop');

  await page.locator('#edit-1').click();
  assert.equal(await page.locator('#card_subcategory').inputValue(), 'Fruit');
  assert.equal(await page.locator('#subtopic-suggestions option[value=Fruit]').count(), 1);
  await page.locator('#card_subcategory').fill('Fresh fruit');
  await page.locator('#save-card').click();
  await page.locator('#card-modal').waitFor({state: 'detached'});
  await page.locator('#filters_search').fill('Fresh fruit');
  await waitCount(1);
  assert(await page.locator('#move-down-1').isDisabled());
  await page.locator('#filters_search').fill('');
  await waitCount(24);

  for (const field of ['topic', 'subtopic', 'level', 'albanian']) {
    await page.locator(`#sort-${field}`).click();
    await page.waitForURL(`**sort=${field}`);
    assert(await page.locator('#move-down-1').isDisabled());
  }
  await page.locator('#sort-english').click();
  await page.waitForURL('**sort=english');
  assert.equal(await rows().first().getAttribute('id'), 'cards-24');
  await page.reload();
  await connected(page);
  assert.equal(await rows().first().getAttribute('id'), 'cards-24');
  await page.locator('#select-visible').check();
  await page.locator('#print-selected-count').filter({hasText: '24 selected'}).waitFor();
  await page.locator('#filters_search').fill('Fresh fruit');
  await waitCount(1);
  await page.locator('#print-open').click();
  await page.locator('#print-modal').waitFor();
  assert.deepEqual(await page.locator('#print-preview-cards li').evaluateAll(elements => elements.map(e => Number(e.dataset.cardId))), Array.from({length: 24}, (_, i) => 24 - i));
  await page.locator('#print_sides').selectOption('albanian');
  const pending = page.waitForEvent('download');
  await page.locator('#download-cards').click();
  const download = await pending;
  assert.equal(await download.failure(), null);
  await download.saveAs('/output/ordered-albanian.pdf');
  fs.writeFileSync('/output/expected-print-order.json', JSON.stringify(cards.map(c => c.albanian).reverse()));
  await screenshot('studio-print-order-desktop');
  await page.locator('#close-print').click();
  await page.locator('#filters_search').fill('');
  await waitCount(24);
  await page.setViewportSize({width: 390, height: 844});
  await page.locator('#sort_by').selectOption('order');
  await page.waitForURL('**sort=order');
  await screenshot('studio-order-mobile');
  await page.locator('#studio-sort-controls').scrollIntoViewIfNeeded();
  await screenshot('studio-order-mobile-controls');
  await page.locator('#print-select-1').uncheck();
  await page.locator('#print-select-1').check();
  assert(await page.locator('#move-down-1').isEnabled());
  await page.locator('#move-down-1').click();
  await page.waitForFunction(() => document.querySelector('#order-1').textContent === '2');
  await page.locator('#move-up-1').click();
  await page.waitForFunction(() => document.querySelector('#order-1').textContent === '1');
  await page.locator('#sort_by').selectOption('subtopic');
  await page.waitForURL('**sort=subtopic');
  assert(await page.locator('#move-down-1').isDisabled());
  await page.setViewportSize({width: 1440, height: 1050});
  await page.goto(`${base}/cards`);
  await connected(page);

  await page.locator('#edit-10').click();
  await page.locator('#delete-card').click();
  await page.locator('#cancel-delete').click();
  assert.equal(await rows().count(), 24);
  await page.locator('#edit-10').click();
  await page.locator('#delete-card').click();
  await page.locator('#confirm-delete').click();
  await waitCount(23);
  assert.deepEqual(await positions(), Array.from({length: 23}, (_, i) => String(i + 1)));
  await page.locator('#select-visible').check();
  await page.locator('#delete-selected').click();
  await page.locator('#delete-title').filter({hasText: 'Delete 23 cards?'}).waitFor();
  await screenshot('studio-delete-confirmation');
  await page.locator('#confirm-delete').click();
  await page.locator('#cards-empty').waitFor();
  assert.equal((await page.request.get(`${base}/images/cards/color-apple.svg`)).status(), 200);
  assert.deepEqual(errors, []);
  await browser.close();
  console.log('Card ordering, grouping, mobile controls, live refresh, ordered PDF and deletion passed.');
})().catch(error => {console.error(error); process.exit(1);});
