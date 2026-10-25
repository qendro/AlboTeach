const {chromium} = require('playwright');
const fs = require('fs');
const assert = require('assert/strict');
(async () => {
  fs.mkdirSync('/output',{recursive:true});
  const browser = await chromium.launch({headless:true});
  const page = await browser.newPage({viewport:{width:1440,height:1050},reducedMotion:'reduce'});
  const errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
  const base=process.env.QA_BASE_URL || 'http://localhost:4000';
  let healthy=false;
  for(let i=0;i<40;i++){
    try{healthy=(await page.request.get(`${base}/health`)).ok();}catch{}
    if(healthy)break;
    await new Promise(resolve=>setTimeout(resolve,250));
  }
  assert(healthy,'QA release did not become healthy');
  const connected=async()=>{
    await page.locator('[data-phx-main].phx-connected').waitFor();
    assert.equal(await page.locator('#connection-status').isVisible(),false,'Connection warning must be hidden after connecting');
  };
  const screenshot=name=>page.screenshot({path:`/output/${name}.png`,fullPage:true});
  const login=async role=>{
    await page.goto(`${base}/login?role=${role}`);
    assert.equal(await page.locator('#login-password').count(),0,'Blank credentials must hide the password field');
    await page.locator('#login-form button[type=submit]').click();
    await connected();
  };
  await page.goto(`${base}/login`);
  await screenshot('login-desktop');
  await page.setViewportSize({width:390,height:844});
  await screenshot('login-mobile');
  await login('learner');
  assert.equal(await page.locator('#topics>a').count(),3,'Starter cards must be available without review');
  await screenshot('dashboard-mobile');
  await page.getByRole('link',{name:'Card studio',exact:true}).click();
  await connected();
  await page.locator('#vocabulary tr').first().waitFor();
  assert.equal(await page.locator('#vocabulary tr').count(),12);
  await screenshot('studio-mobile');
  assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
  for(const role of ['learner','parent']){
    await login(role);
    await page.goto(`${base}/cards`);
    await connected();
    // Import must be available immediately, regardless of role or imported status.
    const english=`Synthetic imported ${role}`;
    const json=JSON.stringify({cards:[{concept:`qa.${role}`,albanian:`Synthetic Albanian ${role}`,english,category:`qa-${role}`,status:'proposed'}]});
    await page.locator('#import-open').click();
    await page.locator('#import_json').fill(json);
    await page.locator('#import-submit').click();
    await page.locator('#import-modal').waitFor({state:'detached'});
    let row=page.locator('#vocabulary tr').filter({hasText:english});
    await row.locator('input[id^="print-select-"]:enabled').waitFor();
    const quality=row.locator('.studio-quality-form');
    await quality.getByLabel('Prishtina / less formal wording').check();
    await quality.getByLabel('Update, change or add picture').check();
    await quality.getByLabel('Delete',{exact:true}).check();
    await quality.getByRole('textbox').fill('Synthetic QA: use a natural Prishtina phrase.');
    await page.locator('#quality-save-all').click();
    await page.getByText('All quality checks saved.',{exact:true}).waitFor();
    await page.reload();
    await connected();
    assert(await quality.getByLabel('Prishtina / less formal wording').isChecked());
    assert(await quality.getByLabel('Update, change or add picture').isChecked());
    assert(await quality.getByLabel('Delete',{exact:true}).isChecked());
    assert.equal(await quality.getByRole('textbox').inputValue(),'Synthetic QA: use a natural Prishtina phrase.');
    await page.setViewportSize({width:1440,height:1050});
    await screenshot(`quality-${role}-desktop`);
    await page.setViewportSize({width:390,height:844});
    await screenshot(`quality-${role}-mobile`);
    assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));
    await row.getByRole('button',{name:'Edit card'}).click();
    await page.locator('#card_albanian').fill(`Edited synthetic Albanian ${role}`);
    await page.locator('#card_notes').fill('Updated in the real browser without approval or review.');
    await page.locator('#save-card').click();
    await page.locator('#card-modal').waitFor({state:'detached'});
    row=page.locator('#vocabulary tr').filter({hasText:english});
    await row.getByText(`Edited synthetic Albanian ${role}`,{exact:true}).waitFor();
    await row.getByRole('button',{name:'Edit card'}).click();
    assert.equal(await page.locator('#card_albanian').inputValue(),`Edited synthetic Albanian ${role}`);
    // Optional review has no effect on availability; archive is a separate action.
    await page.locator('#optional-review summary').click();
    await page.locator('#review_reviewer').fill('Software browser QA fixture');
    await page.locator('#mark-reviewed').click();
    await page.locator('#card-modal').getByText('Reviewed by Software browser QA fixture',{exact:false}).waitFor();
    await page.locator('#archive-card').click();
    await page.locator('#card-modal').waitFor({state:'detached'});
    await row.locator('input[id^="print-select-"]:disabled').waitFor();
    await row.getByRole('button',{name:'Edit card'}).click();
    await page.locator('#archive-card').click();
    await page.locator('#card-modal').waitFor({state:'detached'});
    await row.locator('input[id^="print-select-"]:enabled').waitFor();
    // Create with the normal fields only: no password, stable key, reviewer, or approval.
    await page.locator('#new-card').click();
    await page.locator('#card_albanian').fill(`Synthetic created ${role}`);
    await page.locator('#card_english').fill(`Synthetic created meaning ${role}`);
    await page.locator('#card_category').fill(`qa-${role}`);
    await page.locator('#save-card').click();
    await page.locator('#card-modal').waitFor({state:'detached'});
    await page.goto(`${base}/practice?topic=qa-${role}`);
    await connected();
    await page.locator('#practice-card').waitFor();
    await page.locator('#reveal-card').click();
    await page.locator('#card-word').getByText(`Edited synthetic Albanian ${role}`,{exact:true}).waitFor();
    await page.locator('#flip-back').click();
    await page.locator('#card-word[lang=en]').waitFor();
    await page.locator('#reveal-card').click();
    await page.locator('#card-word[lang=sq]').waitFor();
    await screenshot(`practice-${role}`);
    await page.locator('#grade-remembered').click();
    if(role==='learner') {
      await page.locator('#reveal-card').waitFor();
      await page.locator('#reveal-card').click();
      await page.locator('#card-word').getByText(`Synthetic created ${role}`,{exact:true}).waitFor();
      await page.locator('#grade-remembered').click();
    }
    const response=await page.request.get(`${base}/cards/export`);
    assert.equal(response.status(),200);
    const exported=await response.json();
    assert(exported.cards.some(c=>c.concept===`qa.${role}`&&c.status==='active'));
    assert(exported.cards.some(c=>c.albanian===`Synthetic created ${role}`&&c.status==='active'));
  }
  await page.setViewportSize({width:1440,height:1050});
  await page.goto(`${base}/cards`);
  await connected();
  await screenshot('studio-desktop');
  await page.locator('#edit-7').click();
  await screenshot('editor-desktop');
  assert.equal(errors.length,0,errors.join('\n'));
  await browser.close();
  console.log('PASS: both roles enter without passwords; full studio access; quality flags and notes save and survive reload; immediate imported/created availability; real edit/save/reopen; optional review; archive/restore; learner practice; export; desktop/mobile layout; no browser errors.');
})().catch(e=>{console.error(e.stack);process.exit(1);});
