// Adds the illustrations requested in the October 24 Card Studio review.
// Uses the same pinned Fluent Flat/CC0 asset system as prepare_color_art.py.
// NODE_PATH must include sharp. Does not access the application database.
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const {execFileSync} = require('node:child_process');
const sharp = require('sharp');
const root = path.resolve(__dirname, '..');
const staticDir = path.join(root, 'albo/priv/static/images/cards');
const printDir = path.join(root, 'albo/priv/printing/images');
const pin = '1ffb34c752ecf5d402f04cfb4b392c77f57c54bc';
const base = `https://raw.githubusercontent.com/microsoft/fluentui-emoji/${pin}/`;
const fetch = url => execFileSync('curl', ['--fail', '--silent', '--show-error', '--location', '--retry', '2', '--max-time', '40', url], {maxBuffer: 20_000_000});
const fluent = {
  woman: 'Woman', man: 'Man', girl: 'Girl', boy: 'Boy', child: 'Child',
  grandmother: 'Old woman', grandfather: 'Old man', rice: 'Cooked rice',
  potato: 'Potato', tomato: 'Tomato', cucumber: 'Cucumber', onion: 'Onion',
  pepper: 'Bell pepper', pear: 'Pear', strawberry: 'Strawberry', salt: 'Salt',
  coat: 'Coat', cap: 'Billed cap', tongue: 'Tongue', arm: 'Flexed biceps', leg: 'Leg',
  horse: 'Horse', cow: 'Cow', sheep: 'Ewe',
  'male-teacher': 'Man teacher', 'female-teacher': 'Woman teacher',
  game: 'Game die', running: 'Person running', walking: 'Person walking', crayon: 'Crayon'
};
const svg = body => `<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="-9 -9 114 114">${body}</svg>\n`;
const person = (x, color, hair) => `<path d="M${x-19} 83q0-29 19-29t19 29" fill="${color}"/><ellipse cx="${x}" cy="32" rx="14" ry="18" fill="#E8BB96"/><path d="M${x-14} 29q-3-24 15-22 17 0 13 23l-10-10-17 8" fill="${hair}"/><circle cx="${x-5}" cy="33" r="1.4" fill="#574039"/><circle cx="${x+5}" cy="33" r="1.4" fill="#574039"/><path d="M${x-4} 42q4 3 8 0" fill="none" stroke="#AD725C" stroke-width="2"/>`;
const custom = {
  parents: person(26, '#6BAACA', '#72533E') + person(70, '#D79CB7', '#72533E'),
  yogurt: '<ellipse cx="48" cy="34" rx="27" ry="9" fill="#AAD6E5"/><path d="m21 34 8 45q19 10 38 0l8-45" fill="#81C3D9"/><path d="m30 42 5 30q13 6 26 0l5-30" fill="#F6F0DC"/><ellipse cx="48" cy="34" rx="23" ry="6" fill="#FFFDF4"/><path d="m60 30 9-18" stroke="#A0B4C3" stroke-width="5" stroke-linecap="round"/>',
  sugar: '<path d="m19 42 19-11 20 11v22L38 76 19 64z" fill="#D7E3EA"/><path d="m19 42 19 11 20-11-20-11z" fill="#FFFDF4"/><path d="M38 53v23l20-12V42z" fill="#BCCED9"/><path d="m48 59 17-10 18 10v20L65 89 48 79z" fill="#E7ECED"/><path d="m48 59 17 10 18-10-18-10z" fill="#FFFDF4"/><path d="M65 69v20l18-10V59z" fill="#C6D8E0"/><path d="m48 18 16-9 17 9v19l-17 9-16-9z" fill="#D7E3EA"/><path d="m48 18 16 9 17-9-17-9z" fill="#FFFDF4"/>',
  room: '<path d="M12 15h72v67H12z" fill="#F8EAD6"/><path d="M12 15v67l22-17V29z" fill="#E4CFB1"/><path d="m12 82 22-17h50v17z" fill="#CFA578"/><path d="M47 25h26v25H47z" fill="#8CCDDD"/><path d="M60 25v25M47 37h26" stroke="#FFFBF0" stroke-width="3"/><path d="M39 62h37v8H39zM43 70v10M71 70v10" fill="#D89C5D" stroke="#B47E4B" stroke-width="3"/>',
  pillow: '<path d="M16 25q32 7 64 0-6 23 0 46-32-7-64 0 6-23 0-46" fill="#ABD2E7"/><path d="M22 32q26 4 52 0-4 16 0 32-26-4-52 0 4-16 0-32" fill="#D6EAF2"/><path d="M21 68q28-5 55 0" stroke="#82B3CF" stroke-width="3" fill="none"/>',
  blanket: '<path d="M19 15h58v67H19z" fill="#D6B0CF"/><path d="M19 15h58v15H19z" fill="#F1D8E7"/><path d="M19 42h58M19 60h58M34 30v52M56 30v52" stroke="#AA83B5" stroke-width="3"/><path d="M22 82v5M31 82v5M40 82v5M49 82v5M58 82v5M67 82v5M76 82v5" stroke="#C395BB" stroke-width="3"/>',
  towel: '<path d="M25 13h46v70H25z" fill="#82C8C6"/><path d="M25 22h46M25 72h46" stroke="#D7F0DE" stroke-width="5"/><path d="M25 82h46M30 84v4M39 84v4M48 84v4M57 84v4M66 84v4" stroke="#559EAC" stroke-width="3"/>',
  jacket: '<path d="m31 14-17 9-9 32 14 5 9-23v45h40V37l9 23 14-5-9-32-17-9-17 7z" fill="#74B3D8"/><path d="m31 14 17 7 17-7-6 17H37z" fill="#B6DAEB"/><path d="M48 24v58M32 55h9M56 55h9" stroke="#477DA5" stroke-width="3"/><path d="M28 76h40" stroke="#588AAF" stroke-width="5"/>',
  pajamas: '<path d="m23 12-14 9-5 21 10 4 9-17v24h40V29l9 17 10-4-5-21-14-9-20 8z" fill="#ACB9E5"/><path d="m23 58-5 28h18l7-20 7 20h18l-5-28z" fill="#9EAADA"/><path d="M43 22v30" stroke="#7783B9" stroke-width="2"/><path d="m31 31 2 5 5 1-4 4 1 5-4-3-5 3 1-5-4-4 5-1z" fill="#FFF2B8"/>',
  hair: '<path d="M19 51q-6-43 28-43 36 0 30 43l7 30H12z" fill="#805739"/><ellipse cx="48" cy="49" rx="23" ry="29" fill="#E8BB96"/><path d="M21 42q0-34 27-32 31-1 28 34L55 26 40 37l-18 6" fill="#805739"/><path d="M31 24q16-12 30 0M25 42v25M71 42v25" stroke="#A77B4B" stroke-width="4" fill="none"/><circle cx="40" cy="49" r="2" fill="#684D3C"/><circle cx="57" cy="49" r="2" fill="#684D3C"/><path d="M41 63q7 6 14 0" stroke="#B87A62" stroke-width="2" fill="none"/>',
  knee: '<path d="M29 9h27l-4 30q24-3 25 16l-4 30H50l4-27H26q-9 0-8-13z" fill="#E8BB96"/><path d="M29 9h27l-2 18H24z" fill="#79ADC7"/><circle cx="49" cy="46" r="10" fill="none" stroke="#D47762" stroke-width="3"/><path d="M73 49q-1-7-9-8" fill="none" stroke="#CF9479" stroke-width="3"/>',
  belly: '<path d="m31 12-16 9-8 30 12 4 9-22-3 49h46l-3-49 9 22 12-4-8-30-16-9z" fill="#81B4C9"/><path d="M30 40q18-10 36 0l3 28q-20 13-42 0z" fill="#E8BB96"/><circle cx="48" cy="56" r="13" fill="none" stroke="#D47762" stroke-width="2.5"/><path d="M47 56h2" stroke="#AE725C" stroke-width="3" stroke-linecap="round"/>',
  back: '<path d="M37 10h22v11l18 8 8 27-12 5-6-20 4 42H25l4-42-6 20-12-5 8-27 18-8z" fill="#E8BB96"/><path d="M37 10h22v11q-11 5-22 0z" fill="#D7A27C"/><path d="M48 29v41M34 35q4 11 10 9M62 35q-4 11-10 9" stroke="#CB9177" stroke-width="2.5" fill="none"/><path d="M25 76h46v8H25z" fill="#7CA7CC"/>',
  doll: '<path d="M38 24q-17-18-21 1l9 12M58 24q17-18 21 1L70 37" fill="#BA8050"/><circle cx="48" cy="28" r="16" fill="#EDC7A4"/><path d="M32 22q3-24 24-13 9 4 8 15L48 14z" fill="#BA8050"/><path d="m34 49-17 12 6 8 13-8-7 21h38l-7-21 13 8 6-8-17-12z" fill="#D994B5"/><path d="M38 82v8M58 82v8" stroke="#E2B48E" stroke-width="7"/><circle cx="42" cy="28" r="1.8" fill="#795C4B"/><circle cx="54" cy="28" r="1.8" fill="#795C4B"/><path d="M43 36q5 4 10 0" fill="none" stroke="#B77761" stroke-width="2"/>',
  big: '<circle cx="37" cy="51" r="28" fill="#82B7D7"/><circle cx="78" cy="65" r="12" fill="#DCE8E9"/><path d="m25 17 12-9 12 9M37 9v18" stroke="#3F789F" stroke-width="3" fill="none" stroke-linecap="round"/>',
  small: '<circle cx="37" cy="51" r="28" fill="#DCE8E9"/><circle cx="78" cy="65" r="12" fill="#82B7D7"/><path d="m68 37 10 9 10-9M78 25v20" stroke="#3F789F" stroke-width="3" fill="none" stroke-linecap="round"/>'
};
for (const [name, fill] of Object.entries({red:'#D94841',blue:'#368BCC',green:'#4D9E57',yellow:'#F0C638',black:'#282D34',white:'#FFFFFF',brown:'#91603E'})) {
  custom[`swatch-${name}`] = `<rect x="19" y="19" width="58" height="58" rx="12" fill="${fill}" stroke="#AFB6BA" stroke-width="2"/>`;
}

async function main() {
  const cached = path.join(root, 'tmp/fluent-tree.json');
  const tree = JSON.parse(fs.existsSync(cached) ? fs.readFileSync(cached) : fetch(`https://api.github.com/repos/microsoft/fluentui-emoji/git/trees/${pin}?recursive=1`));
  const paths = tree.tree.filter(x => x.path.includes('/Flat/') && x.path.endsWith('.svg')).map(x => x.path);
  const entries = [];
  for (const name of [...Object.keys(fluent), ...Object.keys(custom)].sort()) {
    const key = `color-${name}`;
    let drawing, source, credit, license, changes;
    if (custom[name]) {
      drawing = svg(custom[name]);
      source = 'https://creativecommons.org/publicdomain/zero/1.0/';
      credit = 'Original AlboTeach colored teaching illustration'; license = 'CC0 1.0';
      changes = 'Original vector illustration; transparent padded canvas; 512px PNG conversion';
    } else {
      const matches = paths.filter(p => p.split('/')[1] === fluent[name]);
      const asset = matches.find(p => p.includes('/Medium-Light/Flat/')) || matches[0];
      if (!asset) throw Error(`Missing pinned illustration: ${fluent[name]}`);
      source = base + asset.split('/').map(encodeURIComponent).join('/');
      drawing = fetch(source).toString();
      drawing = drawing.replace(/viewBox="([^"]+)"/, (_, box) => {
        const [x,y,w,h] = box.split(' ').map(Number), pad = .12 * Math.max(w,h);
        return `viewBox="${x-pad} ${y-pad} ${w+2*pad} ${h+2*pad}"`;
      });
      credit = 'Microsoft Corporation, Fluent Emoji Flat'; license = 'MIT';
      changes = 'Original shapes and colors; 12% transparent padding on every side; 512px PNG conversion';
    }
    fs.writeFileSync(path.join(staticDir, `${key}.svg`), drawing);
    await sharp(Buffer.from(drawing), {density:400}).resize(512,512).png().toFile(path.join(printDir, `${key}.png`));
    entries.push({key, file:`${key}.png`, credit, license, source, changes, sha256_svg:crypto.createHash('sha256').update(drawing).digest('hex')});
  }
  const names = new Set(entries.map(e => e.key));
  for (const dir of [staticDir, printDir]) {
    const file = path.join(dir, 'credits.json');
    const previous = JSON.parse(fs.readFileSync(file)).filter(e => !names.has(e.key));
    fs.writeFileSync(file, JSON.stringify([...previous, ...entries], null, 2) + '\n');
  }
  console.log(`Added ${entries.length} licensed teaching illustrations and print PNGs.`);
}
main().catch(error => {console.error(error); process.exit(1);});
