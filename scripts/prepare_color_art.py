#!/usr/bin/env python3
"""Bundle replacement colored object illustrations. Never reads/writes the database.
Uses pinned Microsoft Fluent Emoji Flat originals plus new CC0 object drawings.
"""
import concurrent.futures
import hashlib
import json
from pathlib import Path
import re
import subprocess
import urllib.parse

ROOT = Path(__file__).resolve().parents[1]
STATIC = ROOT / 'albo/priv/static/images/cards'
PRINT = ROOT / 'albo/priv/printing/images'
COLLECTION = ROOT / 'albo/priv/collections/color-art'
PIN = '1ffb34c752ecf5d402f04cfb4b392c77f57c54bc'
BASE = f'https://raw.githubusercontent.com/microsoft/fluentui-emoji/{PIN}/'
FLUENT = {
 'alarm-clock':'Alarm clock', 'apple':'Red apple', 'baby':'Baby', 'backpack':'Backpack',
 'banana':'Banana', 'bath':'Bathtub', 'bed':'Bed', 'beef':'Cut of meat', 'bike':'Bicycle',
 'bird':'Bird', 'book-open':'Open book', 'boot':'Hiking boot', 'bread':'Bread',
 'building-complex':'Office building', 'bus':'Bus', 'butterfly':'Butterfly', 'car':'Automobile',
 'carrot':'Carrot', 'cat':'Cat', 'chair':'Chair', 'cheese':'Cheese wedge', 'citrus':'Tangerine',
 'cloud-rain':'Cloud with rain', 'coffee':'Hot beverage', 'cooking-pot':'Pot of food',
 'cup-soda':'Teacup without handle', 'dog':'Dog', 'dress':'Dress', 'droplet':'Droplet',
 'ear':'Ear', 'egg':'Egg', 'eye':'Eye', 'face-slightly-frowning':'Slightly frowning face',
 'face-slightly-smiling':'Smiling face with smiling eyes', 'file':'Page facing up',
 'finger':'Index pointing up', 'fish':'Fish', 'flower-2':'Blossom', 'glove':'Gloves',
 'grape':'Grapes', 'hand':'Raised hand', 'hat':'Womans hat', 'hospital':'Hospital',
 'house':'House', 'key-round':'Key', 'knife':'Kitchen knife', 'milk':'Glass of milk',
 'moon':'Crescent moon', 'mouth':'Mouth', 'music':'Musical notes', 'nose':'Nose',
 'notebook':'Notebook', 'pen':'Pen', 'pencil':'Pencil', 'plane':'Airplane',
 'plane-takeoff':'Airplane departure', 'rabbit':'Rabbit', 'ruler':'Straight ruler',
 'scarf':'Scarf', 'school':'School', 'scissors':'Scissors', 'shoe':'Running shoe',
 'snowflake':'Snowflake', 'soap':'Soap', 'sock':'Socks', 'spoon':'Spoon', 'sun':'Sun',
 'thermometer-sun':'Thermometer', 'tooth':'Tooth', 'train-front':'Train',
 'tree-deciduous':'Deciduous tree', 'trousers':'Jeans', 'utensils':'Fork and knife',
 'volleyball':'Volleyball', 'window':'Window'
}
# New full-color object illustrations, drawn independently of the rejected line assets.
# A few flat color planes, rounded joins and highlights, with transparent surroundings.
CUSTOM = {
 'belt': '<path d="M12 44h69a7 7 0 0 1 0 16H12z" fill="#C88654"/><path d="M12 54h69v6H12z" fill="#A85C39"/><rect x="26" y="39" width="23" height="26" rx="4" fill="#F8BF42"/><rect x="32" y="45" width="12" height="14" rx="2" fill="#B77545"/><path d="M29 52h13" stroke="#F8DF8A" stroke-width="4"/><circle cx="68" cy="52" r="1.5" fill="#784B31"/><circle cx="76" cy="52" r="1.5" fill="#784B31"/>',
 'bridge': '<path d="M12 42h72v10H12z" fill="#D99761"/><path d="M12 52h72v6H12z" fill="#BC7047"/><path d="M16 39v38h12V56q20 29 40 0v21h12V39H68q-20 27-40 0z" fill="#E8AE7C"/><path d="M10 77h22M64 77h22" stroke="#B9764D" stroke-width="5" stroke-linecap="round"/><path d="M20 34v13M38 38v9M58 38v9M76 34v13" stroke="#C47849" stroke-width="4"/>',
 'circle': '<circle cx="48" cy="48" r="29" fill="#58B9E5"/><path d="M24 59a29 29 0 0 0 49-29 29 29 0 0 1-49 29" fill="#299AD5"/><path d="M29 36a23 23 0 0 1 16-10" stroke="#AFE5F5" stroke-width="5" stroke-linecap="round"/>',
 'disc': '<ellipse cx="48" cy="51" rx="36" ry="26" fill="#A8CEE1"/><ellipse cx="48" cy="48" rx="36" ry="25" fill="#EBF6FC"/><ellipse cx="48" cy="48" rx="25" ry="16" fill="#BDE1EF"/><ellipse cx="48" cy="47" rx="22" ry="13" fill="#FFFFFF"/>',
 'door-closed': '<path d="M22 14h52v70H22z" fill="#B37748"/><path d="M28 20h40v64H28z" fill="#E9AE70"/><path d="M32 26h30v20H32zM32 53h30v24H32z" fill="#D79156"/><circle cx="61" cy="50" r="3" fill="#FFF1A7"/><path d="M22 84h52" stroke="#916143" stroke-width="4" stroke-linecap="round"/>',
 'door-open': '<path d="M19 14h55v70H19z" fill="#B37748"/><path d="M25 20h42v64H25z" fill="#F8F2E8"/><path d="m25 20 30 10v54L25 94z" fill="#E7A668"/><path d="m30 29 20 6v17l-20-3zM30 56l20 1v18l-20 6z" fill="#CE874E"/><circle cx="48" cy="55" r="2.5" fill="#FFF1A7"/>',
 'footprints': '<g transform="rotate(-15 33 48)" fill="#A87D64"><ellipse cx="31" cy="56" rx="10" ry="17"/><circle cx="20" cy="35" r="4"/><circle cx="29" cy="30" r="4.5"/><circle cx="39" cy="31" r="4"/><circle cx="46" cy="36" r="3.5"/></g><g transform="translate(25 -15) rotate(14 33 48)" fill="#C69A7C"><ellipse cx="31" cy="56" rx="10" ry="17"/><circle cx="20" cy="35" r="4"/><circle cx="29" cy="30" r="4.5"/><circle cx="39" cy="31" r="4"/><circle cx="46" cy="36" r="3.5"/></g>',
 'fork': '<g transform="rotate(30 48 48)"><path d="M42 43h12v39a6 6 0 0 1-12 0z" fill="#7EB5CA"/><path d="M46 44h4v35h-4z" fill="#A6D5E2"/><path d="M35 12h5v19h5V12h6v19h5V12h5v21q0 14-13 14T35 33z" fill="#B4C0CA"/><path d="M35 12h3v21q0 10 8 12-11-1-11-12z" fill="#D8E3E9"/></g>',
 'glass-water': '<path d="m22 16 7 64q19 9 38 0l7-64z" fill="#DDF3FA"/><path d="m29 42 4 34q15 7 30 0l4-34z" fill="#5BB8E4"/><ellipse cx="48" cy="42" rx="19" ry="5" fill="#8CD9F3"/><path d="m29 23 4 31" stroke="#FFFFFF" stroke-width="4" stroke-linecap="round"/><ellipse cx="48" cy="16" rx="26" ry="6" fill="#B7D8E5"/><ellipse cx="48" cy="16" rx="21" ry="3" fill="#F6FBFF"/>',
 'head': '<path d="M38 67h20v18H38z" fill="#DCA27F"/><ellipse cx="48" cy="44" rx="25" ry="30" fill="#F4C8A5"/><ellipse cx="23" cy="48" rx="5" ry="8" fill="#EAB994"/><ellipse cx="73" cy="48" rx="5" ry="8" fill="#EAB994"/><path d="M23 41C15 4 76 0 74 40L62 23q-16 19-36 12v10z" fill="#825B44"/><circle cx="38" cy="47" r="2.4" fill="#654739"/><circle cx="58" cy="47" r="2.4" fill="#654739"/><path d="M41 62q7 5 14 0" fill="none" stroke="#B46F56" stroke-width="2.5" stroke-linecap="round"/>',
 'library-big': '<path d="M15 31h66v50H15z" fill="#F4D9B4"/><path d="m9 31 39-19 39 19z" fill="#DB8A69"/><path d="M24 37h8v35h-8M64 37h8v35h-8" fill="#FFF6E8"/><path d="M9 77h78v7H9z" fill="#CA9476"/><path d="M38 47q10-5 10 0 10-5 10 0v22q-10-5-10 0-10-5-10 0z" fill="#58AFC3"/><path d="M48 47v22" stroke="#CEE9F0" stroke-width="2"/>',
 'route': '<path d="M15 79q35-8 35-30T80 16" fill="none" stroke="#AAB4BF" stroke-width="22"/><path d="M15 79q35-8 35-30T80 16" fill="none" stroke="#F4E7AB" stroke-width="2.5" stroke-dasharray="6 6"/>',
 'shirt': '<path d="m32 18-19 13 10 21 10-5v36h30V47l10 5 10-21-19-13-16 7z" fill="#88C7E4"/><path d="m32 18 16 7-9 14-10-17M64 18l-16 7 9 14 10-17" fill="#D7F0F8"/><path d="M48 26v57" stroke="#5FADD3" stroke-width="3"/><circle cx="49" cy="45" r="1.6" fill="#FFFFFF"/><circle cx="49" cy="57" r="1.6" fill="#FFFFFF"/><circle cx="49" cy="69" r="1.6" fill="#FFFFFF"/><path d="M56 44h7v11h-7z" fill="#62B0D5"/>',
 'skirt': '<path d="M32 18h32l18 61q-33 11-68 0z" fill="#F2A1B0"/><path d="m37 28-8 52M59 28l9 52M48 29v53" stroke="#D77F99" stroke-width="5"/><path d="M32 18h32v12H32z" fill="#DB7E9B"/><path d="M15 78q32 10 66 0" fill="none" stroke="#F8C4CE" stroke-width="4"/>',
 'soup': '<ellipse cx="48" cy="45" rx="36" ry="14" fill="#F6D5B3"/><path d="M12 45q4 37 36 37t36-37z" fill="#64B8C9"/><path d="M48 82q26 0 33-26-5 29-33 29" fill="#3598AF"/><ellipse cx="48" cy="45" rx="32" ry="11" fill="#E9A654"/><path d="M26 44h8M47 49h8M60 40h8" stroke="#6C9E56" stroke-width="4" stroke-linecap="round"/><path d="M34 27q-5-5 0-11M49 24q-5-5 0-11M64 27q-5-5 0-11" stroke="#C1C9CE" stroke-width="3" fill="none" stroke-linecap="round"/>',
 'square': '<rect x="20" y="20" width="56" height="56" rx="2" fill="#7CC6A3"/><path d="M20 69h56v7H20z" fill="#4EA57E"/><path d="M25 25h46" stroke="#B5E6D0" stroke-width="4"/>',
 'store': '<path d="M20 35h56v47H20z" fill="#FAE4C8"/><path d="M26 48h23v23H26z" fill="#9CDBEA"/><path d="M56 48h14v34H56z" fill="#72B4CF"/><path d="M16 24h64l6 19H10z" fill="#E8837C"/><path d="M25 24h12l-3 19H20zM49 24h12l3 19H49zM73 24h7l6 19H76z" fill="#FFF1D7"/><path d="M20 82h56" stroke="#D2B797" stroke-width="4"/><circle cx="60" cy="64" r="1.5" fill="#F8E29A"/>',
 'table': '<path d="m16 36 41-17 28 17-41 20z" fill="#E1AB6B"/><path d="M16 36v8l28 18v-6z" fill="#B97D4D"/><path d="m44 56 41-20v8L44 62z" fill="#CB9159"/><path d="M21 45v31l7 5V50zM74 48v29l6-3V45zM42 61v25l7-3V59z" fill="#AE7449"/><path d="m26 35 28-11" stroke="#F3C991" stroke-width="3" stroke-linecap="round"/>',
 'toy-brick': '<path d="m12 54 21-11 22 11v24L33 89 12 78z" fill="#EAA764"/><path d="m12 54 21 11 22-11-22-11z" fill="#FFD08E"/><path d="M33 65v24l22-11V54z" fill="#D98A4D"/><path d="m48 39 19-10 20 10v23L67 73 48 62z" fill="#79BFA8"/><path d="m48 39 19 10 20-10-20-10z" fill="#AFE2CE"/><path d="M67 49v24l20-11V39z" fill="#51A389"/><path d="m22 18 18-9 19 9v22L40 50 22 40z" fill="#7FAFDE"/><path d="m22 18 18 10 19-10L40 9z" fill="#B4D5F1"/><path d="M40 28v22l19-10V18z" fill="#5E95CC"/>',
 'trees': '<path d="M27 55h7v30h-7zM65 43h6v39h-6z" fill="#B98555"/><path d="M9 52q-8-17 5-25 0-20 17-18 20-3 21 18 13 12 0 27-21 15-43-2" fill="#75BD7C"/><path d="M15 55q23 8 36-8-4 18-22 17z" fill="#4D9B65"/><path d="M53 42q-8-14 4-21 0-16 13-15 16-2 17 16 11 10 0 22-17 12-34-2" fill="#9DCD86"/>',
 'triangle': '<path d="m48 16 34 62H14z" fill="#F3AD70"/><path d="m14 78 5-9h58l5 9z" fill="#D98A56"/><path d="m30 54 16-29" stroke="#FBD7B0" stroke-width="4" stroke-linecap="round"/>',
 'users': '<path d="M8 85q0-28 21-28t21 28" fill="#73B6D5"/><path d="M47 85q0-28 21-28t21 28" fill="#CE95B5"/><ellipse cx="29" cy="38" rx="16" ry="20" fill="#EEC5A4"/><path d="M13 36q-4-27 17-24 20 0 15 22L33 24l-18 9z" fill="#89634A"/><ellipse cx="68" cy="38" rx="16" ry="20" fill="#DCA885"/><path d="M52 35q-6-26 16-25 22 0 18 31l-7-11-19-4z" fill="#654B3B"/><path d="M27 88q0-24 21-24t21 24" fill="#F0B458"/><ellipse cx="48" cy="59" rx="13" ry="16" fill="#F0BE98"/><path d="M35 55q0-23 20-16 10 4 6 17l-10-8-16 6z" fill="#815E45"/>'
}
for n in range(1,11):
    CUSTOM[f'number-{n}'] = f'<text x="48" y="72" text-anchor="middle" font-family="DejaVu Sans,sans-serif" font-weight="bold" font-size="66" fill="#5799C5">{n}</text>'


def fetch(url):
    result = subprocess.run(['curl','--fail','--location','--silent','--show-error','--retry','2','--max-time','40',url],capture_output=True)
    if result.returncode: raise RuntimeError(url+': '+result.stderr.decode())
    return result.stdout


def main():
    tree=json.loads(fetch(f'https://api.github.com/repos/microsoft/fluentui-emoji/git/trees/{PIN}?recursive=1'))
    paths=[item['path'] for item in tree['tree'] if '/Flat/' in item['path'] and item['path'].endswith('.svg')]
    existing=json.loads((STATIC/'credits.json').read_text())
    keys={e['key'][5:] for e in existing if e['key'].startswith('line-')}
    assert keys==set(FLUENT)|set(CUSTOM), (keys-set(FLUENT)-set(CUSTOM),(set(FLUENT)|set(CUSTOM))-keys)
    license=fetch(BASE+'LICENSE').decode()
    for directory in (STATIC,PRINT):
        (directory/'LICENSE-Fluent-Emoji.txt').write_text(license)
        (directory/'LICENSE-AlboTeach-Color.txt').write_text('Original AlboTeach colored object drawings and numerals: CC0 1.0 Universal.\nTo the extent possible under law, the authors waive copyright and related rights.\nhttps://creativecommons.org/publicdomain/zero/1.0/\n')
    def make(key):
        name='color-'+key
        if key in CUSTOM:
            svg='<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="-9 -9 114 114">'+CUSTOM[key]+'</svg>\n'
            credit='Original AlboTeach colored object illustration'; license='CC0 1.0';source='https://creativecommons.org/publicdomain/zero/1.0/'
            changes='New original colored illustration, not derived from outline assets; transparent padded canvas; PNG conversion'
        else:
            matches=[p for p in paths if p.split('/')[1]==FLUENT[key]]
            p=next((p for p in matches if '/Medium-Light/Flat/' in p),matches[0])
            source=BASE+urllib.parse.quote(p)
            svg=fetch(source).decode()
            # Add whitespace by widening the viewbox; preserve the drawing's shapes and colors.
            match=re.search(r'viewBox="([^"]+)"',svg); x,y,w,h=map(float,match[1].split()); pad=.12*max(w,h)
            padded=f'{x-pad:g} {y-pad:g} {w+2*pad:g} {h+2*pad:g}'
            svg=svg[:match.start(1)]+padded+svg[match.end(1):]
            credit='Microsoft Corporation, Fluent Emoji Flat';license='MIT'; changes='Original colors and shapes; 12% transparent margin added on every side; SVG converted to PNG'
        (STATIC/(name+'.svg')).write_text(svg)
        return dict(key=name,file=name+'.png',credit=credit,license=license,source=source,changes=changes,sha256_svg=hashlib.sha256(svg.encode()).hexdigest())
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool: entries=list(pool.map(make,sorted(keys)))
    for directory in (STATIC,PRINT):
        manifest=[e for e in json.loads((directory/'credits.json').read_text()) if not e['key'].startswith('color-')]
        (directory/'credits.json').write_text(json.dumps(manifest+entries,ensure_ascii=False,indent=2)+'\n')
    mapping={'line-'+key:'color-'+key for key in keys}
    legacy=json.loads((ROOT/'albo/priv/collections/kosovo-200/print-outline-map.json').read_text())
    mapping.update({old:mapping[line] for old,line in legacy.items()})
    # Additional pre-existing starter catalog entries use matching colored replacements too.
    mapping.update({key:'color-'+target for key,target in {'fish':'fish','cat':'cat','cheese':'cheese','cup':'coffee','tree':'tree-deciduous','sun':'sun','car':'car','fork-knife':'utensils','spoon':'spoon','dog':'dog','hand':'hand','book':'book-open','ball':'volleyball'}.items()})
    (COLLECTION/'display-map.json').write_text(json.dumps(dict(sorted(mapping.items())),indent=2)+'\n')
    (COLLECTION/'sources.json').write_text(json.dumps(dict(upstream_commit=PIN,fluent=FLUENT,original_drawings=sorted(CUSTOM)),indent=2)+'\n')
    print(f'Prepared {len(entries)} replacement illustrations ({len(FLUENT)} Fluent Emoji, {len(CUSTOM)} original); no card records changed.')

if __name__=='__main__': main()
