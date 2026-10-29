// Adds the pictures requested in production on October 29, 2026.
// Uses the established Fluent Flat (MIT) and original vector (CC0) catalog.
// NODE_PATH must include sharp. This script never accesses a database.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {execFileSync} = require('node:child_process');
const sharp = require('sharp');

const root = path.resolve(__dirname, '..');
const staticDir = path.join(root, 'albo/priv/static/images/cards');
const printDir = path.join(root, 'albo/priv/printing/images');
const collectionDir = path.join(root, 'albo/priv/collections/color-art');
const pin = '1ffb34c752ecf5d402f04cfb4b392c77f57c54bc';
const upstream = `https://raw.githubusercontent.com/microsoft/fluentui-emoji/${pin}/`;
const fetch = url => execFileSync('curl', ['--fail', '--silent', '--show-error', '--location', '--retry', '2', '--max-time', '40', url], {maxBuffer: 20_000_000});

const fluent = {
  lemon: 'Lemon', blueberries: 'Blueberries', chicken: 'Poultry leg', pasta: 'Spaghetti',
  couch: 'Couch and lamp', soccer: 'Soccer ball', basketball: 'Basketball',
  homework: 'Memo', computer: 'Laptop', math: 'Abacus',
  greeting: 'Waving hand', 'good-morning': 'Sunrise', 'good-night': 'Crescent moon',
  'thank-you': 'Heart hands', please: 'Folded hands', yes: 'Check mark button',
  no: 'Cross mark', what: 'Red question mark', tired: 'Yawning face',
  hungry: 'Face savoring food', good: 'Thumbs up'
};

const head = (x, y, r = 10) => `<circle cx="${x}" cy="${y}" r="${r}" fill="#EDC09B"/><path d="M${x-r} ${y-1}q0-${r+8} ${r+3}-${r-1} ${r+2} 0 ${r-3} ${r+1}l-${r-5}-${r-5}-${r+4} ${r-4}" fill="#805B42"/>`;
const arrow = (x, y, rotation = 0) => `<g transform="translate(${x} ${y}) rotate(${rotation})"><path d="M-13-4H3v-8L17 0 3 12V4h-16z" fill="#4B9D7A"/></g>`;
const face = (x, y, mood, fill) => `<circle cx="${x}" cy="${y}" r="11" fill="${fill}"/><circle cx="${x-4}" cy="${y-2}" r="1.1" fill="#73563F"/><circle cx="${x+4}" cy="${y-2}" r="1.1" fill="#73563F"/><path d="${mood==='happy' ? `M${x-4} ${y+3}q4 5 8 0` : mood==='sad' ? `M${x-4} ${y+6}q4-5 8 0` : `M${x-4} ${y+4}h8`}" fill="none" stroke="#A66B57" stroke-width="1.8" stroke-linecap="round"/>`;
const custom = {
  bowl: '<ellipse cx="48" cy="36" rx="36" ry="13" fill="#69B5CD"/><path d="M12 36q5 42 36 42t36-42" fill="#82C6D9"/><path d="M23 55q9 22 28 19 21-2 29-24-5 29-32 29-20 0-25-24" fill="#58A6BE"/><ellipse cx="48" cy="36" rx="32" ry="10" fill="#DBF0F4"/><ellipse cx="48" cy="38" rx="25" ry="6" fill="#B7DFE9"/><path d="M22 49q4 13 12 18" stroke="#BCE7ED" stroke-width="4" fill="none" stroke-linecap="round"/>',
  come: '<path d="M63 14h24v68H63z" fill="#B58058"/><path d="M67 18h16v64H67z" fill="#F4E6CD"/><path d="m67 18 12 8v56l-12 6z" fill="#E5B37C"/><circle cx="76" cy="53" r="1.5" fill="#FFF1BA"/>' + head(25,24) + '<path d="M18 35q7-4 14 0l4 24H15z" fill="#7CB5D2"/><path d="m20 58-7 24h8l8-20 9 20h8L33 57" fill="#607DAB"/><path d="m32 38 10 10 10-5" stroke="#EDC09B" stroke-width="6" stroke-linecap="round" stroke-linejoin="round" fill="none"/>' + arrow(51,65),
  sit: '<path d="M40 61h33v8H40zM66 39h7v30h-7zM43 67h5v20h-5zM66 67h5v20h-5z" fill="#BD8D62"/>' + head(45,22) + '<path d="M37 34q8-4 15 0l3 24H37z" fill="#78B5D3"/><path d="M38 55h25q7 0 7 7v19H58V66H40q-8 0-8-6z" fill="#687FAB"/><path d="M58 79h18v7H58z" fill="#66584D"/><path d="m39 39-6 13 18 5" stroke="#EDC09B" stroke-width="6" stroke-linecap="round" stroke-linejoin="round" fill="none"/>' + arrow(17,47,90),
  'stand-up': '<path d="M10 66h26v7H10zM10 45h6v27h-6zM13 72h5v15h-5zM30 72h5v15h-5z" fill="#D6BA97"/>' + head(51,19) + '<path d="M43 32q8-4 16 0l3 26H40z" fill="#78B5D3"/><path d="m43 56-3 27h10l2-20 4 20h11l-8-27" fill="#687FAB"/><path d="M40 81h11v6H37zM56 81h15v6H56z" fill="#66584D"/><path d="m43 37-8 16M59 37l7 16" stroke="#EDC09B" stroke-width="6" stroke-linecap="round" fill="none"/>' + arrow(80,35,-90),
  where: '<path d="M12 39 34 31l27 9 23-9v48l-23 9-27-9-22 9z" fill="#D6E8D0"/><path d="m34 31 27 9v48l-27-9z" fill="#B7D6AB"/><path d="m17 73 18-20 22 19 22-22" stroke="#F7F3D6" stroke-width="6" fill="none"/><path d="M48 8a18 18 0 0 0-18 18c0 14 18 30 18 30s18-16 18-30A18 18 0 0 0 48 8" fill="#D9756D"/><path d="M43 21q1-7 7-5 8 3 0 9l-3 3v4M47 38v1" stroke="#FFF9EC" stroke-width="4" stroke-linecap="round" fill="none"/>',
  'how-are-you': '<path d="M9 13h78v53q0 7-7 7H42L25 87V73H16q-7 0-7-7z" fill="#C3E3ED"/><path d="M16 21h64v43H16z" fill="#EAF5F6"/>' + face(26,43,'happy','#F8D68C') + face(48,43,'neutral','#F8D68C') + face(70,43,'sad','#F8D68C'),
  thirsty: head(38,25,15) + '<path d="M16 86q0-42 24-42 17 0 22 18l-10 6-7-12v30z" fill="#7AB8CF"/><path d="m33 53 17 13 13-24" stroke="#EDC09B" stroke-width="8" stroke-linecap="round" stroke-linejoin="round" fill="none"/><path d="m58 24 20 3-5 27-16-2z" fill="#CBEAF2"/><path d="m60 36 14 2-2 13-12-1z" fill="#5BB7DE"/><path d="m61 27 4 1" stroke="#FFF" stroke-width="2" stroke-linecap="round"/><path d="m55 11 4 7M70 9v7M82 15l-5 5" stroke="#6AB7D5" stroke-width="3" stroke-linecap="round"/>'
};
for (let n = 11; n <= 21; n++) {
  custom[`number-${n}`] = `<text x="48" y="72" text-anchor="middle" font-family="DejaVu Sans,sans-serif" font-weight="bold" font-size="66" fill="#5799C5">${n}</text>`;
}

const mapping = {
  'food.lemon': 'lemon', 'food.blueberry': 'blueberries', 'food.chicken': 'chicken', 'food.pasta': 'pasta',
  'household.bowl': 'bowl', 'household.couch': 'couch', 'sports.soccer': 'soccer', 'sports.basketball': 'basketball',
  'school-play.homework': 'homework', 'school-play.computer': 'computer', 'school-play.math': 'math',
  'actions.to_come': 'come', 'actions.to_sit': 'sit', 'actions.to_stand_up': 'stand-up',
  'question.where': 'where', 'phrase.how_are_you': 'how-are-you', 'conversation.hello_goodbye': 'greeting',
  'conversation.good_morning': 'good-morning', 'conversation.good_night': 'good-night', 'conversation.thank_you': 'thank-you',
  'conversation.please': 'please', 'conversation.yes': 'yes', 'conversation.no': 'no', 'conversation.what': 'what',
  'feelings.tired': 'tired', 'feelings.hungry': 'hungry', 'feelings.thirsty': 'thirsty', 'feelings.good': 'good'
};
const numbers = ['eleven','twelve','thirteen','fourteen','fifteen','sixteen','seventeen','eighteen','nineteen','twenty','twenty_one'];
numbers.forEach((word, i) => { mapping[`numbers-colors-shapes.${word}`] = `number-${i+11}`; });

async function main() {
  const cache = path.join(root, 'tmp/fluent-tree.json');
  const tree = JSON.parse(fs.existsSync(cache) ? fs.readFileSync(cache) : fetch(`https://api.github.com/repos/microsoft/fluentui-emoji/git/trees/${pin}?recursive=1`));
  const paths = tree.tree.filter(item => item.path.includes('/Flat/') && item.path.endsWith('.svg')).map(item => item.path);
  const entries = [], audit = [];
  for (const name of [...Object.keys(fluent), ...Object.keys(custom)].sort()) {
    const key = `color-${name}`;
    let drawing, source, credit, license, changes;
    if (custom[name]) {
      drawing = `<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="-9 -9 114 114">${custom[name]}</svg>\n`;
      source = 'https://creativecommons.org/publicdomain/zero/1.0/';
      credit = 'Original AlboTeach colored teaching illustration';
      license = 'CC0 1.0';
      changes = 'Original vector illustration; transparent padded canvas; 512px PNG conversion';
    } else {
      const matches = paths.filter(asset => asset.split('/')[1] === fluent[name]);
      const asset = matches.find(asset => asset.includes('/Medium-Light/Flat/')) || matches[0];
      if (!asset) throw Error(`Missing pinned illustration: ${fluent[name]}`);
      source = upstream + asset.split('/').map(encodeURIComponent).join('/');
      drawing = fetch(source).toString();
      drawing = drawing.replace(/viewBox="([^"]+)"/, (_, box) => {
        const [x,y,w,h] = box.split(' ').map(Number), pad = .12 * Math.max(w,h);
        return `viewBox="${x-pad} ${y-pad} ${w+2*pad} ${h+2*pad}"`;
      });
      credit = 'Microsoft Corporation, Fluent Emoji Flat';
      license = 'MIT';
      changes = 'Original shapes and colors; 12% transparent padding on every side; 512px PNG conversion';
    }
    fs.writeFileSync(path.join(staticDir, `${key}.svg`), drawing);
    const output = path.join(printDir, `${key}.png`);
    await sharp(Buffer.from(drawing), {density:400}).resize(512,512).png().toFile(output);
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
      if (data[(y*info.width+x)*4+3] !== 0) throw Error(`Artwork touches outer margin: ${key}`);
    }
    const fraction = occupied/(info.width*info.height), perCard = {};
    for (const [layout,w,h] of [[8,270,180],[10,270,144],[21,180,720/7]]) {
      const size = layout===21 ? 28 : Math.min(70,h*.39);
      perCard[layout] = +(fraction*size*size/(w*h)).toFixed(4);
      if (perCard[layout]>.07) throw Error(`Too much image area on card: ${key}`);
    }
    audit.push({key,occupied_image_fraction:+fraction.toFixed(4),color_image_fraction:+(color/(512*512)).toFixed(4),max_cmy_weighted_image_fraction:+(darkness/(512*512)).toFixed(4),occupied_card_fraction:perCard});
    entries.push({key,file:`${key}.png`,credit,license,source,changes,sha256_svg:crypto.createHash('sha256').update(drawing).digest('hex')});
  }
  const keys = new Set(entries.map(entry => entry.key));
  for (const dir of [staticDir, printDir]) {
    const file = path.join(dir, 'credits.json');
    const previous = JSON.parse(fs.readFileSync(file)).filter(entry => !keys.has(entry.key));
    fs.writeFileSync(file, JSON.stringify([...previous,...entries], null, 2) + '\n');
  }
  const auditFile = path.join(collectionDir, 'art-audit.json');
  const previousAudit = JSON.parse(fs.readFileSync(auditFile));
  previousAudit.images = [...previousAudit.images.filter(entry => !keys.has(entry.key)),...audit];
  fs.writeFileSync(auditFile, JSON.stringify(previousAudit, null, 2) + '\n');
  fs.writeFileSync(path.join(collectionDir, 'morning-pictures.json'), JSON.stringify({
    description: 'Pictures requested in production on 2026-10-29. Abstract meanings use representative symbols; the card wording supplies the exact meaning.',
    upstream_commit: pin,
    cards: Object.entries(mapping).map(([concept,name])=>({concept,image:`color-${name}`}))
  }, null, 2) + '\n');
  console.log(`Prepared ${entries.length} illustrations for ${Object.keys(mapping).length} requested cards; matching web SVGs and transparent print PNGs. No database changes.`);
}
main().catch(error=>{console.error(error);process.exit(1);});
