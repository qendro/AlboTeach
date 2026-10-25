// Run with the bundled Node runtime; set NODE_PATH to its node_modules directory.
const fs = require('node:fs');
const path = require('node:path');
const sharp = require('sharp');
const root = path.resolve(__dirname, '..');
const folder = path.join(root, 'albo/priv/static/images/cards');
(async () => {
  const audit = [];
  for (const entry of JSON.parse(fs.readFileSync(path.join(folder, 'credits.json')))) {
    if (!entry.key.startsWith('line-')) continue;
    await sharp(path.join(folder, entry.key + '.svg'), {density: 1536 / 24 * 72})
      .resize(512, 512).png().toFile(path.join(root, 'albo/priv/printing/images', entry.file));
    const {data, info} = await sharp(path.join(root, 'albo/priv/printing/images', entry.file))
      .ensureAlpha().raw().toBuffer({resolveWithObject: true});
    let coverage = 0;
    for (let i = 0; i < data.length; i += 4) {
      if (data[i] !== data[i + 1] || data[i] !== data[i + 2]) throw Error('Colored art: ' + entry.key);
      coverage += data[i + 3] / 255;
    }
    const fraction = coverage / (info.width * info.height);
    if (fraction > 0.2) throw Error('Outline too dense: ' + entry.key);
    audit.push({key: entry.key, ink_fraction: Math.round(fraction * 10000) / 10000});
  }
  fs.writeFileSync(path.join(root, 'albo/priv/collections/kosovo-200/art-audit.json'), JSON.stringify({
    method: 'Sum of alpha coverage / 512 × 512 pixels. Black art on transparency. Image area only; not measured printer ink use.',
    images: audit
  }, null, 2) + '\n');
  console.log('Validated ' + audit.length + ' grayscale outline assets, each under 20% image area coverage.');
})().catch(e => { console.error(e); process.exit(1); });
