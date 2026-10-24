const {chromium}=require('playwright');
const assert=require('assert/strict');
const fs=require('fs');
(async()=>{
  fs.mkdirSync('/output',{recursive:true});
  const browser=await chromium.launch({headless:true});
  const port=process.env.QA_PORT||'4010';
  for(const host of ['localhost','127.0.0.1']){
    const context=await browser.newContext({viewport:{width:390,height:844}});
    await context.addInitScript(()=>{
      const OriginalWebSocket=window.WebSocket;
      window.qaSockets=[];
      window.WebSocket=class extends OriginalWebSocket {
        constructor(...args){super(...args);window.qaSockets.push(this);}
      };
    });
    const page=await context.newPage();
    const base=`http://${host}:${port}`;
    let healthy=false;
    for(let i=0;i<40;i++){
      try{healthy=(await page.request.get(`${base}/health`)).ok();}catch{}
      if(healthy)break;
      await new Promise(resolve=>setTimeout(resolve,250));
    }
    assert(healthy,'QA release must be healthy');
    await page.goto(`${base}/login`);
    await page.locator('#login-form button[type=submit]').click();
    await page.locator('[data-phx-main].phx-connected').waitFor();
    assert.equal(await page.locator('#connection-status').isVisible(),false);
    await page.goto(`${base}/practice`);
    await page.locator('[data-phx-main].phx-connected').waitFor();
    const english=await page.locator('#card-word[lang=en]').innerText();
    await page.locator('#reveal-card').click();
    await page.locator('#card-word[lang=sq]').waitFor();
    assert.notEqual(await page.locator('#card-word').innerText(),english);
    await page.locator('#flip-back').click();
    await page.locator('#card-word[lang=en]').waitFor();
    assert.equal(await page.locator('#card-word').innerText(),english);
    await page.locator('#next-card').click();
    await page.getByText('Card 2 of 12',{exact:true}).waitFor();
    assert.notEqual(await page.locator('#card-word').innerText(),english);
    assert.equal(await page.locator('#connection-status').isVisible(),false);
    await page.screenshot({path:`/output/connected-${host}.png`,fullPage:true});
    // Show the banner only during a real disconnect, then recover automatically.
    await context.setOffline(true);
    // Chromium leaves existing WebSockets open when only HTTP offline mode changes.
    await page.evaluate(()=>window.qaSockets.forEach(socket=>socket.close()));
    await page.locator('#connection-status').waitFor({state:'visible',timeout:15000});
    await context.setOffline(false);
    await page.locator('[data-phx-main].phx-connected').waitFor({timeout:30000});
    await page.locator('#connection-status').waitFor({state:'hidden'});
    await page.locator('#reveal-card').click();
    await page.locator('#card-word[lang=sq]').waitFor();
    await page.locator('#filters_topic').selectOption('food');
    await page.getByText('Card 1 of 6',{exact:true}).waitFor();
    await page.locator('#filters_topic').selectOption('all');
    await page.getByText('Card 1 of 12',{exact:true}).waitFor();
    await page.locator('#filters_mode').selectOption('daily');
    await page.getByText('Card 1 of 3',{exact:true}).waitFor();
    await page.locator('#filters_mode').selectOption('all');
    await page.getByText('Card 1 of 12',{exact:true}).waitFor();
    const seen=new Set();
    for(let i=1;i<=12;i++){
      await page.getByText(`Card ${i} of 12`,{exact:true}).waitFor();
      seen.add(await page.locator('#card-word').innerText());
      await page.locator('#next-card').click();
    }
    await page.locator('#session-complete').waitFor();
    assert.equal(seen.size,12,'All topics must include every flashcard');
    await page.locator('#restart-cards').click();
    await page.getByText('Card 1 of 12',{exact:true}).waitFor();
    console.log(`PASS: ${base}: live connection, hidden warning, flip both directions, next card, offline warning, automatic recovery.`);
    await context.close();
  }
  await browser.close();
})().catch(e=>{console.error(e.stack);process.exit(1);});
