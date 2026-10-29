# Colored flashcard illustrations — replacement artwork

The user rejected the black outline style. The preferred illustrations are now **colored, recognizable object drawings on transparent backgrounds**, with ample surrounding whitespace. These are a separate set of drawings, not recolored Lucide/outline paths. No vocabulary, Kosovo usage notes, card IDs, image keys stored in the database, revisions, progress, reviews, archive state or print history are edited.

## Sources and licensing

- 75 illustrations use Microsoft's **Fluent Emoji Flat** originals, pinned to commit `1ffb34c752ecf5d402f04cfb4b392c77f57c54bc` in [microsoft/fluentui-emoji](https://github.com/microsoft/fluentui-emoji). The repository's [MIT license](https://github.com/microsoft/fluentui-emoji/blob/1ffb34c752ecf5d402f04cfb4b392c77f57c54bc/LICENSE) is bundled in both artwork directories as `LICENSE-Fluent-Emoji.txt`. Source colors/shapes are retained. Their viewboxes have 12% added transparent margin on every side; PNGs are rendered at 512 × 512. The generic orange-fruit drawing uses Fluent's Tangerine illustration as a simple visual cue for orange; it is not a botanical reference.
- 32 new original AlboTeach illustrations cover objects missing from the set, three shapes and ten numerals. These use colored planes, highlights and perspective where appropriate, independently of the previous outline assets. They are dedicated to CC0 in `LICENSE-AlboTeach-Color.txt`. The human parts are generic illustrations, not portraits or representations of the learner/family.
- Both artwork `credits.json` manifests retain per-file credit, license, pinned source URL, transformation details and SVG SHA-256. Full applicable license notices and per-picture credits travel in the PDF Subject metadata, with a visible credit line in the footer.
- All prior Twemoji, outline SVGs, PNGs and licenses remain available. Image generation was not used; the replacement set uses licensed vector originals plus original SVG drawings.

## Default behavior

`Card.display_image/1` maps legacy/starter and `line-*` saved keys to `color-*` keys for studio and practice. `albo/priv/collections/color-art/display-map.json` is the shared mapping used by web display and printing. It covers every illustrated card in the current 200-card collection. Saved card records are unchanged, so learners keep the same content revisions and learning state.

**Printer artwork** defaults to **Color illustrations · white space** in the studio and renderer. Black text and gray guides avoid spending colored ink on type. **Black outlines · least ink** remains an explicit optional mode; it never overrides the color default. **Saved card artwork** preserves the previous ability to print the image key stored on each card. Picture-side selection, duplex layouts, calibration and print counters continue to work as before.

The collection still has 120 illustrated cards and 80 text-only cards. No misleading picture was added to kinship distinctions or other text-only meanings. Object/action cards can share a related picture; the text supplies the intended meaning. There are no full-card backgrounds, photo rectangles or colored category panels in the PDFs.

## Print-size and image-area verification

The real renderer places pictures in a maximum 70pt square on 8-card sheets, approximately 56pt on 10-card sheets, and 28pt on 21-card sheets. Transparent padding is inside that box. All 107 PNGs have transparent edges. The maximum occupied picture area, including even white pixels conservatively, is **4.93% of an 8-card face**, **3.97% of a 10-card face**, and **2.07% of a compact 21-card face**. These are image-area calculations, not measured ink or toner consumption; text/guides and printer settings also contribute.

`art-audit.json` records alpha coverage, saturated-color area, a rough maximum-CMY weighting and occupied area at each actual layout. The build rejects artwork that touches its outer transparent margin or occupies more than 7% of any supported card face. Visual QA includes the full art contact sheet, the 8-card sample, matching English backs, and the 21-card recognition test rendered at 150 dpi. The size-check PDF is designed for printing at **Actual size / 100%** to judge small objects on the home printer; no physical printer test has been claimed.

## Rebuild and artifacts

- `scripts/prepare_color_art.py`: downloads pinned sources, draws the missing objects and prepares SVGs, maps and credit manifests. No database access.
- `scripts/convert_color_art.cjs`: uses sharp to prepare print PNGs and generate the area audit. Set NODE_PATH to a Node installation containing sharp.
- `albo/priv/collections/color-art/sources.json`: selected Fluent folders and original illustration names.
- `albo/priv/collections/color-art/display-map.json`: display/print substitution without content edits.
- `albo/priv/collections/color-art/art-audit.json`: actual-size area audit.
- `output/pdf/color-v2-illustrated-sample.png`: four-card visible sample for sharing in the chat.
- `output/pdf/color-v2-sample-front.png`: full eight-card illustrated sample.
- `output/pdf/kosovo-200-sample.pdf`: refreshed two-page duplex sample.
- `output/pdf/color-v2-size-check.pdf`: 21 illustrated cards at the real compact size, with matching backs.
- `output/pdf/color-v2-size-check.png`: rendered compact-size front.
- `output/pdf/kosovo-200-8-per-sheet.pdf`: refreshed complete 200-card collection, 50 pages / 25 duplex sheets.
- `output/pdf/kosovo-200-21-per-sheet.pdf`: refreshed complete 200-card collection, 20 pages / 10 duplex sheets.
- `output/pdf/color-art-contact-sheet.png`: all replacement illustrations for inspection.
- `output/pdf/outline-v1/`: preserved previous sample/full PDFs for recovery/comparison.

PDFs are generated from a fresh live vocabulary export with actual saved IDs and wording. Offline artifact generation does not increment studio download counts. Language provenance and the original expansion audit remain in [the collection notes](kosovo-200.md); no new language-review claim is made here.

## Verified local rollout — 2026-10-24

The rebuilt local app is healthy at `http://localhost:4010`. Browser checks confirm the colored carrot in Card studio, a colored apple in practice, **200 total / 200 ready**, and the color artwork selected by default in print settings. A PDF generated by the running release through `Albo.Printing.pdf/3` uses `art_style=color`; the two-page artifact is `output/pdf/color-v2-runtime-sample.pdf`. No studio download was recorded.

The verified pre-rollout backup is `backups/alboteach-20261024T224222Z.sqlite`; the post-rollout checkpoint is `backups/alboteach-20261024T224612Z.sqlite`. Every row in **every database table** compares exactly equal across the rollout: cards, historic keys, content events, progress, reviews and schema migrations. Card count stays 200 and all 120 illustrated cards resolve to the replacement color assets. Tests pass: `mix precommit` (44 tests) and PDF regressions (8 tests). All 107 image hashes match their credit manifests. Implementation, assets, backups and refreshed artifacts are also retained in the primary project at `/Users/qendrim/Documents/Code/02_Sandbox/AlboTeach`; source changes remain uncommitted for review.

## Card Studio review additions (October 24, 2026)

The [saved-feedback review](card-quality-review-2026-10-24.md) adds 53 distinct illustrations for 63 picture requests, bringing the color manifest to 160 assets. This includes family portraits, missing objects and body parts, people running/walking, a crayon, small color swatches, and paired big/small comparisons. The additions use the same pinned Fluent Flat MIT and original CC0 vector system. Web SVG and print PNG credits match; all 160 images pass the existing margin/occupied-area checks. `scripts/prepare_quality_art.cjs` reproduces these additions and must run after the original `prepare_color_art.py`; `convert_color_art.cjs` then refreshes the full audit. The dated report records the live content changes separately from the original optional 200-card import.

## Production picture requests (October 29, 2026)

The [production picture review](card-pictures-2026-10-29.md) adds 39 illustrations for the saved picture flags, bringing the color catalog to 199 assets. These include numerals 11-21, the newly added morning vocabulary, actions, conversation cues, and feelings. `scripts/prepare_morning_art.cjs` reproduces the additions without changing any database; `morning-pictures.json` records their stable concept-to-image mappings. New pictures have web SVGs, transparent print PNGs, matching credits, and margin/area checks. All 39 appear correctly in the 8-card and 21-card duplex print proofs.
