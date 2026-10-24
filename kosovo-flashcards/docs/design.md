# Implementation decision and boundaries

## Existing projects assessed

Reviewed October 23, 2026, using project documentation and (for the print layout) the source files.

| Project | Fit | Decision |
| --- | --- | --- |
| [martin-maly/flashcards](https://github.com/martin-maly/flashcards) | MIT Python/ReportLab generator with Letter, images and duplex layout. No persistent reviewed lexicon/correction workflow. | Reuse a small attributed adaptation of its geometry and wrapping code. Extend grids, add both flip modes, readable-width validation, asset validation, approval guards and audit snapshots. |
| [martignlo/printable-flashcards](https://github.com/martignlo/printable-flashcards) | Simple CSV print utility with duplex options; no image/review collection workflow in the documented interface. The inspected repository tree had no standalone license file. | Evaluate as a reference, do not vendor its code. |
| [genanki](https://github.com/kerrickstaley/genanki) | MIT library for creating digital Anki packages. | Good possible future exporter; does not address the physical-first workflow. |
| [OpenMoji](https://github.com/hfg-gmuend/openmoji) | Consistent open illustration set, CC BY-SA 4.0 artwork. | Suitable alternative; use one style for MVP. |
| [Twemoji](https://github.com/jdecked/twemoji/tree/v15.1.0) | Consistent reusable SVG illustrations, CC BY 4.0 graphics. | Bundle 24 assets with original SVGs, derived PNGs, attribution, source URLs and license. No runtime download dependency. |
| [ReportLab](https://docs.reportlab.com/) | Open-source PDF toolkit, BSD license, direct coordinates and embedded TrueType support. | Use the existing PDF engine; only collection and application-specific print rules are custom. |

The small generators do not provide the requested persistent review and correction safeguards. Forking a whole general-purpose generator would preserve unused templates and input frameworks. Instead, the project reuses the useful MIT layout/wrapping subset and builds a small local workflow around established PDF, image and database components.

## Runtime and storage

- Python 3.10+, ReportLab, Pillow; argparse and sqlite3 from the standard library.
- No network calls during application use. Codex generates JSON proposals; it does not need another LLM backend.
- SQLite is the authoritative collection. `cards` contains content, status, revision and reviewer; `history` has full event snapshots; `aliases` retains normalized historic keys; `batches`/`batch_cards` preserve collection membership and order; `images` records managed asset references/credits; `meta`/`PRAGMA user_version` track the schema.
- Foreign keys and unique constraints prevent dangling references and conflicting IDs/positions. Imports and reviews are transactions using nested savepoints. Revision guards reject stale edits.
- Image files are bundled or copied beside the database under `media/` with content-derived filenames. Backups use SQLite's online backup API and include managed media. This is a single-user, local tool, not a concurrent database service.
- Review HTML is self-contained, offline and read-only; review JSON supports edits and explicit decisions. No dedicated frontend or web server.

## Duplicates and correction preservation

New cards cannot overwrite old ones. Exact concept keys, normalized Albanian wording and normalized English glosses are matched against current and historical values. Unicode NFC, case folding, punctuation and spacing normalization preserve Albanian diacritics while ignoring formatting differences. A separate accent-insensitive grouping command suggests possible near duplicates. The generator brief includes exclusions for proposed, approved and rejected vocabulary, so rejected suggestions are not endlessly recycled.

This conservative approach may block legitimate homonyms that share one gloss or Albanian form. For the beginner MVP, manually review or extend an existing card's meaning rather than bypassing deduplication. It cannot prove semantic novelty or infer that unrelated keys are inflections of the same word. The Codex instructions and human review are responsible for those decisions.

A changed card becomes proposed, with reviewer cleared and revision incremented. Old wording remains indexed and preserved in history. Imports of old generated text are skipped; re-rendering uses the corrected content. The previous PDF remains the way to reproduce a previous printed edition exactly.

## Print geometry

US Letter is 612 × 792 points. With 36-point symmetric margins, the usable rectangle is 540 × 720 points. Two columns produce 270-point (3.75-inch) widths; four rows produce 180-point (2.5-inch) heights, five rows 144-point (2-inch) heights.

For a portrait long-edge flip, a card at front column c goes to back column 1-c, with its row preserved. For short-edge, column stays fixed and row r goes to rows-1-r. Back text stays normally readable in the PDF, for the chosen flip. Blank slots on partial sheets are reflected with the same mapping; the last page is never packed independently.

Only front cut lines are drawn. Sparse color, white backgrounds and safe text margins reduce ink and tolerate small feed shifts. Draft labels identify unreviewed content. Offset calibration adjusts translation, not skew or scaling. Printer drivers must use 100%/Actual size and the chosen duplex flip.

PDF generation first writes a temporary PDF; layout failures preserve an existing PDF. Cards that cannot fit at a readable font size, unsupported print glyphs and missing images fail clearly. Each output has a manifest with full card snapshots and positions. Artwork credits are in the review report, PDF footer (bundled Twemoji), PDF metadata and a separate credit text file for custom sources; keep them together when sharing.

## Validation and limits

The tests inspect actual PDF text locations through an independent numeric reflection calculation, not just the renderer's own manifest. Cases include both flips, both grids, multiple sheets, a partial sheet, Unicode, rollback, review guards, image management and backup. Supplied PDFs were also rendered to PNG and inspected visually.

No automatic translation quality check, speech synthesis, pronunciation guide, spaced repetition, per-learner progress, Anki generation or authenticated API is included. Generic SQLite/JSON/CSV access and stable card IDs preserve a simple route to those future features. First install on the user's desktop and real printer calibration remain local tasks.
