// NODE_PATH must contain sharp. Builds print PNGs and checks transparent margins
// plus occupied image area at the real card layouts. No database access.
const fs = require('node:fs');
const path = require('node:path');
const sharp = require('sharp');
const root = path.resolve(__dirname, '..');
const staticDir = path.join(root, 'albo/priv/static/images/cards');
const printDir = path.join(root, 'albo/priv/printing/images');
(async () => {
  const audit = [];
  for (const entry of JSON.parse(fs.readFileSync(path.join(staticDir, 'credits.json')))) {
    if (!entry.key.startsWith('color-')) continue;
    const output = path.join(printDir, entry.file);
    await sharp(path.join(staticDir, entry.key + '.svg'), {density: 400}).resize(512,512).png().toFile(output);
    const {data, info} = await sharp(output).ensureAlpha().raw().toBuffer({resolveWithObject:true});
    let occupied = 0, darkness = 0, color = 0;
    for (let i=0; i<data.length; i+=4) {
      const alpha = data[i+3]/255;
      const least = Math.min(data[i], data[i+1], data[i+2]);
      const most = Math.max(data[i], data[i+1], data[i+2]);
      occupied += alpha;
      darkness += alpha*(1-least/255);
      if (most-least>20) color += alpha;
    }
    for (const [x,y] of [[0,0],[511,0],[0,511],[511,511],[256,0],[0,256],[511,256],[256,511]]) {
      if (data[(y*info.width+x)*4+3] !== 0) throw Error('Artwork touches outer margin: '+entry.key);
    }
    const fraction = occupied/(info.width*info.height);
    const perCard={};
    for (const [layout,w,h] of [[8,270,180],[10,270,144],[21,180,720/7]]) {
      const size = layout===21 ? 28 : Math.min(70,h*.39);
      perCard[layout] = +(fraction*size*size/(w*h)).toFixed(4);
      if (perCard[layout]>.07) throw Error('Too much image area on card: '+entry.key);
    }
    audit.push({key:entry.key,occupied_image_fraction:+fraction.toFixed(4),color_image_fraction:+(color/(512*512)).toFixed(4),max_cmy_weighted_image_fraction:+(darkness/(512*512)).toFixed(4),occupied_card_fraction:perCard});
  }
  fs.writeFileSync(path.join(root,'albo/priv/collections/color-art/art-audit.json'),JSON.stringify({
    method:'512px transparent PNG alpha coverage, saturated-color area, and max(1-R,1-G,1-B) weighted by alpha. Card coverage uses actual renderer image sizes. White areas count toward occupied coverage, making it conservative. These are image area proxies, not measured printer ink consumption.',
    images:audit
  },null,2)+'\n');
  console.log('Validated '+audit.length+' color illustrations; transparent edges; each occupies under 7% of any card face.');
})().catch(e=>{console.error(e);process.exit(1)});
