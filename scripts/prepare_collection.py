#!/usr/bin/env python3
"""Rebuild the bundled import, pinned outline assets and lexical lookup audit.
Run with Python 3; PNG conversion is separate using the bundled Node sharp library.
No database access. Dictionary lookups establish headwords, not native review.
"""
import concurrent.futures
import hashlib
import html
import json
from pathlib import Path
import re
import urllib.parse
import subprocess

ROOT = Path(__file__).resolve().parents[1]
COLLECTION = ROOT / 'albo/priv/collections/kosovo-200'
STATIC = ROOT / 'albo/priv/static/images/cards'
PRINT = ROOT / 'albo/priv/printing/images'
PIN = '7faf87628a1ad6175975bc595344337ce14a7db4'
UPSTREAM = f'https://raw.githubusercontent.com/lucide-icons/lucide/{PIN}'
# Original simple SVG artwork, dedicated to CC0. Distinct from upstream Lucide.
CUSTOM = {
 'music': '<path d="M10 18V5l10-3v13M10 8l10-3"/><ellipse cx="6" cy="18" rx="4" ry="3"/><ellipse cx="16" cy="15" rx="4" ry="3"/>',
 'cheese': '<path d="M3 10 16 3l5 7v11H3zM3 10h18"/><circle cx="8" cy="15" r="1"/><circle cx="16" cy="17" r="1"/>',
 'butterfly': '<path d="M12 8C1-5 0 14 10 13 1 14 5 24 12 16 19 24 23 14 14 13 24 14 23-5 12 8zM12 8v10M12 8l-2-5M12 8l2-5"/>',
 'sock': '<path d="M11 2h9v12l-9 7c-6 4-11-3-6-6l6-4zM11 6h9"/>',
 'table': '<path d="M3 8h18v4H3zM5 12v9M19 12v9"/>',
 'window': '<rect x="4" y="3" width="16" height="18" rx="1"/><path d="M12 3v18M4 12h16"/>',
 'spoon': '<ellipse cx="12" cy="6" rx="4" ry="5"/><path d="M12 11v11"/>',
 'fork': '<path d="M7 2v6a5 5 0 0 0 10 0V2M12 2v20M7 6h10"/>',
 'knife': '<path d="M14 2C9 5 8 10 8 13h6v9h3V2z"/>',
 'soap': '<rect x="3" y="10" width="18" height="11" rx="4"/><path d="M8 14h8"/><circle cx="7" cy="5" r="2"/><circle cx="15" cy="4" r="1"/>',
 'trousers': '<path d="M6 2h12l2 20h-6l-2-13-2 13H4zM6 5h12"/>',
 'dress': '<path d="m8 2-2 4 3 3-5 13h16L15 9l3-3-2-4c-2 3-6 3-8 0zM9 10h6"/>',
 'skirt': '<path d="M8 3h8l5 18H3zM7 7h10M10 9l-2 10M14 9l2 10"/>',
 'shoe': '<path d="M3 9h5l3 4 9 2a2 2 0 0 1 1 4H3zM3 19v2h18v-2M11 13l-2 2M14 14l-2 2"/>',
 'scarf': '<path d="M5 3h14v5H5zM9 8v13h5V8M14 8l5 10-4 2M9 18h5"/>',
 'glove': '<path d="M8 12V4a1.5 1.5 0 0 1 3 0v6-8a1.5 1.5 0 0 1 3 0v8-6a1.5 1.5 0 0 1 3 0v6-3a1.5 1.5 0 0 1 3 0v8l-3 7H9l-6-8a2 2 0 0 1 3-2l2 3z"/>',
 'boot': '<path d="M6 2h10v11l5 2v6H3v-5l3-3zM3 18h18M6 6h10"/>',
 'belt': '<rect x="2" y="8" width="20" height="8" rx="1"/><rect x="8" y="7" width="7" height="10" rx="1"/><path d="M8 12h5M19 12h.1"/>',
 'hat': '<path d="M6 14 8 4h8l2 10M3 14h18v4H3zM7 11h10"/>',
 'head': '<ellipse cx="12" cy="10" rx="7" ry="8"/><path d="M9 18v4M15 18v4"/>',
 'nose': '<path d="m13 3-4 12c-1 4 7 4 8 1M9 18l-2-1"/>',
 'mouth': '<path d="M2 12q5-7 10-3 5-4 10 3-10 13-20 0zM2 12h20"/>',
 'tooth': '<path d="M12 4C2-2 2 9 5 14l2 7c1 3 3-7 5-7s4 10 5 7l2-7c3-5 3-16-7-10z"/>',
 'finger': '<path d="M9 21 5 13a2 2 0 0 1 3-2l2 3V3a2 2 0 0 1 4 0v9l5 2v7z"/>',
 'bread': '<path d="M5 11C0 10 2 3 7 3h10c5 0 7 7 2 8v10H5zM8 6l-2 3M13 6l-2 3M18 6l-2 3"/>',
 'chair': '<path d="M6 13V3h12v10M4 13h16v4H4zM6 17v5M18 17v5"/>',
 'bridge': '<path d="M2 9h20M2 13h20M3 7v14M21 7v14M3 9q9 16 18 0M8 9v8M16 9v8"/>',
}
for n in range(1, 11):
    CUSTOM[f'number-{n}'] = f'<text x="12" y="18" text-anchor="middle" font-family="sans-serif" font-size="17" stroke="none" fill="#000">{n}</text>'

def fetch(url):
    result = subprocess.run(["curl", "--fail", "--location", "--silent", "--show-error", "--max-time", "35", url], capture_output=True)
    if result.returncode:
        raise RuntimeError(f"{url}: {result.stderr.decode().strip()}")
    return result.stdout

def main():
    rows = [[part.strip() for part in line.split('|')] for line in (COLLECTION/'vocabulary.tsv').read_text().splitlines() if line and not line.startswith('#')]
    cards = []
    for category, english, albanian, icon, note, lemma in rows:
        slug = re.sub(r'[^a-z0-9]+', '_', english.lower()).strip('_')
        lemma = lemma or albanian
        url = 'https://fjale.al/' + urllib.parse.quote(lemma)
        cards.append(dict(concept=f'{category}.{slug}', english=english, albanian=albanian,
                          category=category, difficulty='beginner', image=f'line-{icon}' if icon else '',
                          source=f'AI draft; lexical reference: {url}',
                          notes=(note+' ' if note else '') + 'Not native-reviewed. Written headword/reference is not proof of the family’s spoken Kosovo form. See docs/collections/kosovo-200.md.'))
    regional = {'mother': 'https://oralhistorykosovo.org/sq/riza-krasniqi/', 'father': 'https://oralhistorykosovo.org/sq/riza-krasniqi/', 'paternal uncle': 'https://oralhistorykosovo.org/sq/riza-krasniqi/', 'to eat': 'https://oralhistorykosovo.org/sq/valdete-idrizi/', 'to read': 'https://oralhistorykosovo.org/sq/shkelzen-maliqi/', 'to write': 'https://oralhistorykosovo.org/sq/shkelzen-maliqi/', 'hello / goodbye': 'https://www.qvyshift.com/phrasebook/kosovar-albanian/', 'good morning': 'https://files.peacecorps.gov/multimedia/audio/languagelessons/albania/AL_Albanian_Language_Lessons.pdf'}
    for card in cards:
        if card['english'] in regional:
            card['source'] = 'AI draft; usage reference: ' + regional[card['english']]
    assert len(cards) == 188
    for field in ('concept','albanian','english'):
        assert len({c[field].casefold() for c in cards}) == len(cards), field
    (COLLECTION/'import.json').write_text(json.dumps({'schema_version':1,'cards':cards}, ensure_ascii=False, indent=2)+'\n')
    # Keep a concise lookup audit rather than reproducing dictionary definitions.
    def lookup(row):
        lemma = row[5] or row[2]
        url = 'https://fjale.al/' + urllib.parse.quote(lemma)
        try:
            body = fetch(url).decode()
            title = html.unescape(re.search(r'<title>(.*?)</title>',body,re.S)[1])
            found = f'data-slug="{lemma}"' in body and 'class="def"' in body
            return dict(english=row[1], lemma=lemma, url=url, title=title, headword_found=found)
        except Exception as error:
            return dict(english=row[1], lemma=lemma, url=url, error=str(error), headword_found=False)
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        audit = list(pool.map(lookup, rows))
    (COLLECTION/'lexical-audit.json').write_text(json.dumps({'accessed':'2026-10-24','limitation':'Headword presence only. English senses and dialect choices are AI proposals; no native verification.', 'entries':audit},ensure_ascii=False,indent=2)+'\n')
    print('Headwords needing inspection:', [(x['english'],x.get('error',x.get('title'))) for x in audit if not x['headword_found']], flush=True)
    legacy = {'apple':'apple','banana':'banana','bread':'bread','egg':'egg','milk':'milk','water':'droplet','house':'house','door':'door-closed','chair':'chair','bed':'bed'}
    keys = {c['image'][5:] for c in cards if c['image']} | set(legacy.values())
    credits=[]
    license_text=fetch(UPSTREAM+'/LICENSE').decode()
    for target in (STATIC/'LICENSE-Lucide.txt',PRINT/'LICENSE-Lucide.txt'):
        target.write_text(license_text)
    for target in (STATIC/'LICENSE-AlboTeach-Outline.txt',PRINT/'LICENSE-AlboTeach-Outline.txt'):
        target.write_text('Original AlboTeach SVG drawings and numeral assets: CC0 1.0 Universal.\nTo the extent possible under law, the authors waive copyright and related rights.\nhttps://creativecommons.org/publicdomain/zero/1.0/\n')
    def artwork(icon):
        key='line-'+icon
        if icon in CUSTOM:
            svg='<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="#000000" stroke-width="0.8" stroke-linecap="round" stroke-linejoin="round">'+CUSTOM[icon]+'</svg>\n'
            credit='Original AlboTeach outline drawing'; license='CC0 1.0'; source='https://creativecommons.org/publicdomain/zero/1.0/'; changes='Original SVG; 512px transparent PNG for printing'
        else:
            source=UPSTREAM+f'/icons/{icon}.svg'
            svg=fetch(source).decode().replace('currentColor','#000000').replace('stroke-width="2"','stroke-width="0.8"')
            credit='Lucide contributors; includes Feather-derived artwork by Cole Bemis'; license='ISC / MIT (see LICENSE-Lucide.txt)'; changes='Black stroke, width 0.8; SVG converted to transparent 512px PNG'
        (STATIC/f'{key}.svg').write_text(svg)
        return dict(key=key,file=key+'.png',credit=credit,license=license,source=source,changes=changes,sha256_svg=hashlib.sha256(svg.encode()).hexdigest())
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        credits=list(pool.map(artwork, sorted(keys)))
    for target in (STATIC/'credits.json',PRINT/'credits.json'):
        original=[x for x in json.loads(target.read_text()) if not x['key'].startswith('line-')]
        target.write_text(json.dumps(original+credits,ensure_ascii=False,indent=2)+'\n')
    (COLLECTION/'print-outline-map.json').write_text(json.dumps({old:'line-'+new for old,new in legacy.items()},indent=2)+'\n')
    print(f'{len(cards)} cards; {sum(bool(c["image"]) for c in cards)} illustrated; {len(credits)} outline assets')

if __name__=='__main__': main()
