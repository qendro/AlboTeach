# Webapp printing

`render.py` consumes a temporary JSON snapshot from `Albo.Printing`. It reads no database and makes no network requests. The Docker release includes Python 3, ReportLab, and Pillow through Debian's `python3-reportlab` package. The standalone `kosovo-flashcards` project remains independent.

US Letter portrait, half-inch margins. Layouts: 2 columns × 4 rows (8 cards), 2 × 5 (10 cards), or 3 × 7 (21 cards). The 21-card layout has 180 × approximately 102.86pt cards (2.5 × approximately 1.43 inches), with compact labels, illustrations, and text. Text never silently clips or truncates: wording that cannot fit at a readable font size fails explicitly. Pages alternate fronts and backs. Long-edge duplex mirrors columns; short-edge mirrors rows. Odd column/row counts retain their center positions. Empty slots retain their physical positions. Calibration uses the selected layout. `image_side` chooses `albanian` (front, default) or `english` (back), without changing language order or duplex mapping. Cards have no revision footer. Back offsets use PDF coordinates: positive X right, positive Y up. No review status is inferred or modified by printing. Downloads are capped at 300 cards and checked against their selected revisions.

Twemoji PNGs were copied from the reference project (512px conversions of unchanged SVG artwork). Copyright Twitter, Inc. and contributors, CC BY 4.0. The full license is in `images/LICENSE-Twemoji`; per-image attribution, source and conversion details are in `images/credits.json`. Attribution is retained in the PDF footer and per-image metadata.

Bitstream Vera fonts: Copyright (c) 2003 Bitstream, Inc. The complete font license is in `fonts/bitstream-vera-license.txt`. Fonts are embedded to preserve Albanian ë and ç.

After a flashcard PDF is generated successfully, the controller atomically increments `cards.print_count` once per included card and broadcasts a studio refresh. Calibration and failed generation do not update counters. Counts belong to the card across content revisions and do not change practice state, content revision, or optional review. The renderer itself remains independent of the database. Existing cards start at zero; older downloads and physical printer completion are not observable.

Run renderer regressions in the toolchain container:

```sh
docker compose run --rm tools python3 -m unittest discover -s test/printing -v
```

The optional 200-card expansion bundles Lucide (pinned source, ISC/MIT including Feather notices) and original CC0 outline art, with source credits and SVG hashes in both artwork manifests. `Card.images/0` reads the bundled manifest at compilation so web and print support the same keys. Black outlines are an optional PDF mode: starter images map to outlines; unsupported legacy pictures become text-only; saved card artwork remains selectable. This mode also uses grayscale text/guides. Complete outline license notices are embedded in PDF Subject metadata. See [collection provenance](../../../docs/collections/kosovo-200.md) for vocabulary, credits, generation scripts, and limitations.

Preferred artwork is now colored Fluent Emoji Flat (Microsoft, MIT) plus original CC0 object drawings, with transparent margins. Both the studio and renderer default to `art_style=color`; black outlines remain optional. Web display and printing map saved keys without editing database records or content revisions. Full credits/license notices are embedded in PDF metadata. See [current color artwork verification](../../../docs/collections/color-art.md).
