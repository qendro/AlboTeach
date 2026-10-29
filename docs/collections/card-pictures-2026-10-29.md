# Production picture requests - October 29, 2026

Adds 39 colored illustrations for the 39 picture flags saved in the production Card Studio. The collection remains at 215 cards. Assets follow the existing transparent-background style: 21 Microsoft Fluent Emoji Flat originals under MIT, pinned to commit 1ffb34c752ecf5d402f04cfb4b392c77f57c54bc, and 18 original AlboTeach vector drawings and numerals under CC0.

The requested images include numerals 11-21, foods, household objects, sports, school items, three actions, conversation cues, and feelings. Abstract meanings use representative symbols: a map pin and question mark for where, a speech bubble with three moods for how are you, waving for hello/goodbye, sunrise/moon for morning/night, heart hands for thanks, folded hands for please, a check/cross for yes/no, and a thumbs-up for good. Card wording supplies the exact meaning. Chicken uses a cooked drumstick as a food cue; math uses an abacus; homework uses a paper and pencil.

Reproduce with scripts/prepare_morning_art.cjs, with NODE_PATH pointing to an installation containing sharp. The script downloads pinned licensed vectors, creates the original drawings, renders 512px transparent PNGs, checks transparent margins and the existing image-area bound, appends per-file credits, and records stable concept-to-image mappings in albo/priv/collections/color-art/morning-pictures.json. It never accesses a database. Web and print manifests contain matching credit entries and source hashes.

Deploy the assets before applying image keys through Albo.Learning.save_card/3. Preserve current wording, saved order, IDs, print counts, and history rows. Resolve only the picture flags after verifying every assigned SVG and PNG. Application image edits increment content revisions and clear optional review notes through the normal save path. Full production SQLite and artwork backups are kept privately under backups/.

Validation: mix precommit (63 tests); all 39 pictures rendered in the 8-card and 21-card duplex layouts, with English backs clear; contact-sheet and rendered-page visual inspection. Offline print proofs do not increment production print counts.

| Card ID | English | Picture key |
|---|---|---|
| 201 | Eleven (11) | color-number-11 |
| 202 | Twelve (12) | color-number-12 |
| 203 | Thirteen (13) | color-number-13 |
| 204 | Fourteen (14) | color-number-14 |
| 205 | Fifteen (15) | color-number-15 |
| 206 | Sixteen (16) | color-number-16 |
| 207 | Seventeen (17) | color-number-17 |
| 208 | Eighteen (18) | color-number-18 |
| 209 | Nineteen (19) | color-number-19 |
| 210 | Twenty (20) | color-number-20 |
| 211 | Twenty-one (21) | color-number-21 |
| 212 | Lemons | color-lemon |
| 213 | Blueberries | color-blueberries |
| 214 | Chicken | color-chicken |
| 215 | Pasta | color-pasta |
| 216 | Bowl | color-bowl |
| 217 | Couch | color-couch |
| 218 | Soccer | color-soccer |
| 219 | Basketball | color-basketball |
| 220 | Homework | color-homework |
| 221 | Computer | color-computer |
| 222 | Math | color-math |
| 168 | to come | color-come |
| 171 | to sit | color-sit |
| 172 | to stand up | color-stand-up |
| 11 | Where? | color-where |
| 12 | How are you? | color-how-are-you |
| 193 | hello / goodbye | color-greeting |
| 194 | good morning | color-good-morning |
| 195 | good night | color-good-night |
| 196 | thank you | color-thank-you |
| 197 | please | color-please |
| 198 | yes | color-yes |
| 199 | no | color-no |
| 200 | What? | color-what |
| 185 | tired | color-tired |
| 186 | hungry | color-hungry |
| 187 | thirsty | color-thirsty |
| 192 | good | color-good |
