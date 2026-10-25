# Kosovo Albanian collection: 200 total cards

Prepared 2026-10-24. Working assumption: approximately 200 **total**, rather than 200 additional. The expansion contains 188 additions alongside the 12 existing starters. Existing cards, historic duplicate keys, content revisions, optional reviews, practice records, archive state and print counts are preserved. New cards have no reviewer and no claim of native verification.

## Language choices and evidence

These are researched **AI proposals**, not a native-reviewed Kosovo curriculum. Standard spellings remain where suitable; everyday Kosovo/Gheg candidates are explicitly identified. Kosovo usage varies by region, generation and family. The monolingual dictionary establishes written headwords and senses, not a particular family's pronunciation or English equivalence. English glosses and short composed phrases were selected by the AI; a successful automated lookup is not translation verification.

- [FJALË, Albanian monolingual dictionary](https://fjale.al/): individual lexical URLs are retained in each card's source. The adjacent `lexical-audit.json` records the queried lemma, page title, access date and lookup result. For plural forms, adjective phrases and verbs, the query can be a base lemma. A successful result means the requested dictionary entry exists; definitions are not copied into this collection.
- [Peace Corps/Albania, Albanian for Invitees (November 2005)](https://files.peacecorps.gov/multimedia/audio/languagelessons/albania/AL_Albanian_Language_Lessons.pdf), printed pages 10–24: a **standard Albanian** cross-check for greetings, food, household objects, clothing, family, colors and numbers. This source does not establish Kosovo dialect correctness. Some source spellings/English glosses need care (for example, the source's color agreement and kitchen spelling); this collection does not blindly reproduce them.
- [Oral History Kosovo: Riza Krasniqi](https://oralhistorykosovo.org/sq/riza-krasniqi/): primary Kosovo speech evidence for babë, nanë, axhë and other family terms. The interview is adult historical material; the flashcards include only ordinary vocabulary, not interview narratives.
- [Oral History Kosovo: Hava Shala transcript](https://oralhistorykosovo.org/wp-content/uploads/2017/02/HavaShala_Transkripti_Shqip.pdf): illustrates local forms and regional variation, including mixha and spoken verb forms. Context evidence, not an English teaching dictionary.
- [Oral History Kosovo: Shkëlzen Maliqi](https://oralhistorykosovo.org/sq/shkelzen-maliqi/): attests me lexu and me shkru. Other me + participle forms are AI-selected Gheg candidates, with standard equivalents and variation notes; these have not each been verified against an independent native speaker.
- [Oral History Kosovo: Valdete Idrizi](https://oralhistorykosovo.org/sq/valdete-idrizi/): usage evidence for me hangër.
- [Qvyshift Kosovar Albanian phrasebook](https://www.qvyshift.com/phrasebook/kosovar-albanian/): secondary cross-check for Tung as both hello and goodbye and for Çka. Its automated-looking pronunciation aids are not reproduced or treated as native review. The dictionary has no entry at the queried tung or mirëmëngjes URLs; the two failed lexical lookups are intentionally visible in the audit. Good morning is supported by the Peace Corps greeting list.

Priority family checks: nanë/nënë/mami, babë/baba/babi, axhë/mixhë, çikë/vajzë; the original shtëpi card keeps its existing shpi note. Actions use a Gheg infinitive, not an imperative: me hangër, me pi, me lexu, me shkru. Me lujt and me kqyrë are explicitly flagged conversational candidates. Gender pairs remain on a single adjective card. Three uses tre as the counting form, with tri for feminine nouns noted. Kinship separates the mother's and father's siblings. The boy/girl cards note son/daughter senses instead of adding semantic duplicates. Ambiguous dictionary words include explanatory notes (e.g. bark, gjuhë, këmbë, pemë, gomë, bluzë).

## Topic counts after import

| Topic | Existing | Added | Total |
|---|---:|---:|---:|
| Family / people | 0 | 20 | 20 |
| Food / drinks | 6 | 19 | 25 |
| Home / objects | 4 | 16 | 20 |
| Clothes | 0 | 15 | 15 |
| Body | 0 | 15 | 15 |
| Animals / nature | 0 | 15 | 15 |
| Numbers / colors / shapes | 0 | 20 | 20 |
| School / play | 0 | 15 | 15 |
| Places / transport | 0 | 15 | 15 |
| Everyday actions | 0 | 20 | 20 |
| Feelings / descriptions | 0 | 10 | 10 |
| Greetings / useful phrases | 2 | 8 | 10 |
| **Total** | **12** | **188** | **200** |

## Artwork and printing

110 of the 188 additions have pictures. 78 are text-only, including family relationships that a generic person icon would not distinguish, colors that would require ink-heavy swatches, and meanings for which the available art was a poor match. Some concrete terms are also text-only rather than using a misleading illustration. Pictures are simple pictograms, not detailed teaching scenes; similar action/object pictures rely on the card text for meaning.

107 reusable outline assets cover those cards and ten starter picture replacements. All have transparent backgrounds and black strokes. Source SVGs and print PNGs are bundled offline. `art-audit.json` records alpha-weighted occupied image area; every PNG is grayscale and under 20% coverage. This is an image-density check, **not a measured claim about printer ink savings**. Text, cutting guides and printer behavior also affect consumption.

[Lucide](https://github.com/lucide-icons/lucide) artwork is pinned to commit `7faf87628a1ad6175975bc595344337ce14a7db4`. Black strokes were thinned to 0.8 SVG units and converted to 512px transparent PNG. The complete upstream ISC/MIT notice is in both artwork directories as `LICENSE-Lucide.txt`; this preserves the Feather-derived icon notices. Original simple AlboTeach SVG drawings and numerals are CC0; see `LICENSE-AlboTeach-Outline.txt`. Per-asset source URLs, transformation details and SHA-256 SVG hashes are in both `credits.json` manifests. Original Twemoji art and CC BY 4.0 notices are retained.

The initial outline rollout below is retained as history. The user subsequently rejected that visual style: **Printer artwork** now defaults to **Color illustrations · white space**, with a separate replacement set and no content/history changes. See [current artwork, licenses and print-size checks](color-art.md). The optional **Black outlines · least ink** mode maps the ten starter illustrations to outlines without changing saved cards. Other legacy images with no outline match become text-only in this mode. **Saved card artwork** prints the illustrations stored on the card, including the original colorful artwork. Picture side, duplex, layout and calibration settings continue to apply. Full Lucide license notices and per-picture credits travel in the PDF Subject metadata; the visible footer identifies the art families. Print at actual size, test duplex alignment on your printer before cutting, and use grayscale if desired.

## Files and safe import

- `albo/priv/collections/kosovo-200/vocabulary.tsv`: editable source rows, usage notes and lookup lemmas.
- `albo/priv/collections/kosovo-200/import.json`: 188 new cards for the existing Card studio importer (below its 300-card / 200 KB limit).
- `albo/priv/collections/kosovo-200/lexical-audit.json`: lookup evidence and explicit lookup failures.
- `albo/priv/collections/kosovo-200/art-audit.json`: image density checks.
- `albo/priv/collections/kosovo-200/print-outline-map.json`: non-destructive print substitution for starters.
- `scripts/prepare_collection.py`: regenerates JSON, lookup audit, pinned SVGs and credits; network required. It never opens a database.
- `scripts/convert_outline_art.cjs`: builds PNGs with sharp and checks grayscale and image density; set NODE_PATH to a Node installation containing sharp.
- `scripts/import-kosovo-200.sh`: makes a verified full SQLite backup, then calls the same transactional `Albo.Learning.import_json/1` used by the studio through the running release RPC. Repeating it skips duplicates. Run after rebuilding/restarting the app with these assets.

Import does not change starter vocabulary or learner history. Review metadata is never supplied. Vocabulary JSON does not include or restore practice/print history; use the full SQLite backup for recovery. Do not replace `starter.json`: existing installations and newly seeded collections still begin with the original 12; this expansion is deliberately imported explicitly.

## Verified local rollout (2026-10-24)

The local app at `http://localhost:4010` was rebuilt and restarted with these assets. The supported importer returned `added: 188, skipped: 0`; repeating it returned `added: 0, skipped: 188`. Live Card studio displays **200 total / 200 ready / 0 optionally reviewed**. All new cards are active, have no reviewer, and start unprinted.

Pre-import backup: `backups/alboteach-20261024T223222Z.sqlite` (SQLite online backup, integrity checked). Post-import checkpoint: `backups/alboteach-20261024T223258Z.sqlite`. Comparison verified every column of the original 12 card rows, their historic keys and content events, and the existing one progress row and one practice-review row. Those original cards retain print_count 2; all additions have print_count 0. Vocabulary JSON is also available at `output/pdf/live-export.json`; full backups remain the recovery source for history.

Checks: `mix precommit` (44 tests); renderer regressions (7 tests); all 107 outline assets pass grayscale and <20% occupied-area checks; visual inspection of illustrated fronts, matching English backs, starter compact sheet, and the dense action/adjective compact sheet. Prepared PDFs: 8 cards/sheet (50 pages / 25 duplex sheets), 21 cards/sheet (20 pages / 10 duplex sheets), and an eight-card sample (2 pages). These offline PDFs were prepared without recording a studio download, so they do not increment the live print counters. Physical duplex alignment and ink usage still depend on the home printer.

The implementation and artifacts were also copied into the originally running app's clean primary checkout at `/Users/qendrim/Documents/Code/02_Sandbox/AlboTeach`, so a normal rebuild from that project retains this support. Source changes remain uncommitted for review.
