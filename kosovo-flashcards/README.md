# Kosovo Albanian Flashcard Generator

A local, review-first tool that Codex can operate for you. It keeps vocabulary and corrections in SQLite, creates a visual review report, and makes aligned, duplex US Letter PDFs. It runs without accounts, a server, an AI API key or network access after installation.

## Start here

1. Install Python 3.10 or newer on your desktop, then extract this folder.
2. Open the folder in Codex. The included `AGENTS.md` explains the workflow.
3. Have Codex install the tool in a virtual environment:

```sh
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -e .
```

Windows PowerShell: use `py -m venv .venv`, then `.venv\Scripts\Activate.ps1`. If activation is restricted, call `.venv\Scripts\python.exe` directly. The commands below work as `python -m kosovo_cards ...` as well as `kcards ...`.

The included `data/cards.sqlite` already contains **12 proposed starter cards and zero approved cards**. Open `output/review.html` to see their images, translations and dialect notes. `output/pdf/starter-draft.pdf` is their printable draft. All sample language is unverified; ask a Kosovo Albanian speaker in your family or your tutor to confirm the preferred forms.

Try saying this to Codex:

> Read AGENTS.md, show me the starter cards, and help me review them. Keep them proposed until I explicitly approve them.

Then:

> Create 20 new beginner cards about food, avoiding all existing vocabulary. Show me the proposed cards before printing.

Codex supplies the language generation. The tool supplies durable state and deterministic processing. There is no second AI model or paid service behind it.

## The everyday workflow

**Propose a new batch.** Codex asks the tool for a brief, writes draft JSON, then imports it:

```sh
kcards brief --count 20 --topic "food and household objects" -o output/next-brief.json
kcards import examples/my-new-batch.json --batch food-002
kcards review --batch food-002 --json output/food-review.json --html output/food-review.html
```

`examples/my-new-batch.json` is a file Codex creates, not an included example. The brief has the exact format, available image keys, approved wording, and compact exclusion lists including historical corrections. Imports always create proposals. Duplicate candidates are skipped and reported; they never overwrite corrections. Each import needs a new batch name. The starter example is `examples/starter.json`; do not import it again into the included collection.

**Review and correct.** Open the generated HTML in any browser. It is an offline report with embedded images. Tell Codex your corrections, or edit the exported review JSON. In that file each card has a blank `decision`: set it to `approved` or `rejected` only after review. You may edit content in the same file, but leave `id` and `revision` unchanged.

```sh
kcards apply-review output/food-review.json --reviewer "Dan / family review"
```

The entire review applies atomically. An old review file is refused if any card's content has changed since export. A blank decision saves corrections without approving them. For a small set of cards that you have explicitly approved through Codex:

```sh
kcards approve --ids 1-4,6 --reviewer "Dan / family review"
```

This command records a human decision; it does not independently verify the language. Codex must not run it merely because it generated plausible translations.

**Print.** Once you have approved the selected cards:

```sh
kcards render --status approved --limit 100 -o output/pdf/first-100.pdf
```

This prints up to the first 100 approved cards in stable ID order. Use `--batch food-002` to print a particular batch, or `--ids 1-8,12` to choose cards. A batch containing unapproved cards refuses normal printing; add `--status approved` to intentionally select only approved members. For a clearly marked draft, use `--allow-proposed`. Rejected cards cannot be printed.

The PDF has alternating front/back pages: **1 front, 2 its back, 3 front, 4 its back**. Fronts show Albanian plus an optional illustration; backs show English. Stable IDs appear on both sides. An incomplete final sheet preserves empty positions. A `.manifest.json` beside each PDF records selected cards, revisions, positions, image credits/checksums and the PDF checksum.

## Home-printer setup

Print `output/pdf/calibration.pdf` first, on plain paper:

- US Letter, portrait, color, **Actual size / 100%**. Turn off Fit, Shrink, borderless expansion, booklet and multiple pages per sheet.
- Double-sided, **flip on long edge** for the supplied PDFs. Keep automatic page rotation off.
- Hold the sheet to light: FRONT 1 must have BACK 1 behind it, and the center crosses and squares must coincide. Cut using the front-side dotted lines.
- Default cards: **8 per sheet, 3.75 × 2.5 inches**, with 0.5-inch margins. `--per-sheet 10` gives 3.75 × 2-inch cards. A full default sheet uses approximately 80% of the paper area for cards.

The PDF geometry is aligned mathematically. Real printers can shift the reverse side; no software can verify your printer feed remotely. If needed, use `--back-x-mm` and `--back-y-mm` when making **both the calibration PDF and your final PDF**. Positive X moves artwork right on the back PDF; positive Y moves it up. Offsets are limited to ±5 mm. Looking through the front, a long-edge back's horizontal movement appears reversed. Apply a small correction and retest; consistent translation can be corrected, but skew or scaling requires adjusting the printer.

```sh
kcards calibration --back-x-mm 0.5 --back-y-mm -0.5 -o output/pdf/calibration-adjusted.pdf
kcards render --status approved --back-x-mm 0.5 --back-y-mm -0.5 -o output/pdf/cards-adjusted.pdf
```

For a short-edge printer workflow, generate with `--flip short-edge` and select short-edge duplex in the print dialog. Manual duplex feed directions depend on the printer: use the numbered calibration sheet to establish the correct refeed order before printing batches. The tool does not guess that order.

Keep an existing PDF to reprint its exact historical wording. Rendering a batch again uses the latest corrected content for its card IDs. Save different output names when retaining earlier editions.

## Replace an image or correct a card

```sh
kcards images
kcards show 12
kcards update 12 --patch examples/my-correction.json --revision 1
kcards history 12
```

A patch file contains only fields to change, such as `{"image":"house"}` or `{"albanian":"your corrected form","notes":"Tutor correction"}`. Read `show` first and use its current revision. Every content or illustration change clears approval. The example `examples/correction.json` illustrates a possible family preference for card 7, but must not be applied without family/tutor confirmation.

There are 24 bundled Twemoji illustrations. To use a new image, have Codex choose another suitable openly licensed illustration or supply a PNG/JPEG, then import it once:

```sh
kcards image-add path/to/chair.png --key chair-alt --credit "Artist name" --license "CC BY 4.0" --source "https://example.org/original"
```

Use `{"image":"chair-alt"}` as the card patch. The tool copies imported art to managed media and preserves its credits. Use `{"image":""}` for abstract words or phrases. New image keys are immutable; replacing a file under an old key is refused. For expanding the artwork catalog, prefer the same Twemoji style. Original SVGs and rendered 512px PNGs for the bundled catalog are included; no image downloads happen during printing.

## Maintain and access the collection

```sh
kcards list --status proposed
kcards duplicates
kcards export --status approved -o output/approved.json
kcards export --status approved -o output/approved.csv
kcards backup backups/2026-10-23
```

Back up with the command above to a **new** directory; it uses SQLite's backup API and copies managed media. Keep the application folder, including its bundled assets, as well. To use a backup, put its database and `media/` directory side by side and pass `--db /path/to/backup/cards.sqlite` **before** the subcommand. A blank collection can be created with `kcards --db data/new.sqlite init`. Do not replace your collection with a demo or a fresh downloaded project.

`export` is for inspection or another application; importing exports does not restore approval/history. Use database backups for full restoration. The schema is plain SQLite, with version 1 recorded in `PRAGMA user_version`; JSON exports also identify their schema version. See `docs/design.md` for the tables and limitations. A future tutor can read approved vocabulary through the CLI, JSON, CSV or read-only SQLite without depending on any AI provider.

## Verify the installation

```sh
python -m pip install -e '.[test]'
python -m unittest discover -s tests -v
python examples/demo_workflow.py
```

The demo uses its own `output/workflow-demo/` database and **obviously synthetic test cards**, then imports, visually exports, corrects, approves, saves and prints them. Its approval is labeled as a software fixture and makes no claim about Albanian. It leaves the real starter collection untouched and refuses to overwrite an existing demo directory.

The regression suite checks physical front/back positions in generated PDFs, including both flip directions, 8/10-card grids and incomplete sheets; it also checks correction preservation, atomic reviews/imports, stale revisions, Unicode duplicate matching, image backup and print guards. PDF visual QA was performed on the supplied draft and calibration pages. Desktop installation and a physical printer test must be completed on your machine.

## Cost and scope

Two direct runtime dependencies: ReportLab and Pillow. SQLite, CLI parsing and JSON handling use Python's standard library. Installation may require Internet access; ordinary use does not. AI usage is whatever Codex uses to write new content and help you review it. There are no API keys, automatic AI calls, accounts, hosted services, learner-progress models or digital-flashcard integrations in this MVP.

Exact normalized words, English glosses and stable concept keys are deduplicated, including old corrections. **Semantic duplicates are still a review task**: inflections, synonyms, alternate glosses and regional forms can evade matching if assigned different concept keys. Use the same concept key for a word family unless you deliberately intend a separate teaching unit.

See `THIRD_PARTY_NOTICES.md` for code, font and artwork licenses. When sharing printed sheets/PDFs, retain the artwork footer and accompanying image credits.
