# AlboTeach

A local Kosovo Albanian learning app for one family learner. Phoenix LiveView, SQLite, and a standalone Docker release. Docker Desktop is the only prerequisite; no language runtime or database installation is needed on your PC.

## Start

```sh
./scripts/setup.sh
docker compose up -d --build --wait app
```

Open **http://localhost:4010** or **http://127.0.0.1:4010**. Both local addresses support the live connection. Choose **I’m learning** or **I’m a parent**, then press the entry button. Both passwords are empty by default, so there is no input to fill in. Both roles have the same Card studio, practice, import/export, editing, optional review, archive, and restore tools. They share one collection and one learner’s progress.

The app is bound to `127.0.0.1:4010` on your computer. Local settings are in ignored, owner-only `albo/.env`. Keep `SECRET_KEY_BASE` stable. Empty `LEARNER_PASSWORD` and `PARENT_PASSWORD` enable one-click entry. If you later set a non-empty password, use at least 16 characters; the corresponding input appears automatically after `docker compose up -d --force-recreate app`. Sessions expire after 12 hours. Roles select a starting screen; they do not limit features.

## Cards and practice

The 12 starter cards are available immediately. They are AI suggestions whose source and dialect notes are retained; availability does not mean someone verified their language.

An optional [200-card Kosovo Albanian collection](docs/collections/kosovo-200.md) adds 188 cards without replacing starters or learner history. It includes source and dialect notes, 110 illustrated additions, and licensed colored object illustrations on transparent backgrounds. Colored art is now the default; the earlier black outlines remain optional. See [replacement artwork and print-size checks](docs/collections/color-art.md). After rebuilding, import `albo/priv/collections/kosovo-200/import.json` in Card studio, or run `./scripts/import-kosovo-200.sh` for a verified backup followed by the same duplicate-safe importer. These are researched AI proposals, not native-reviewed translations. The expansion is not automatically seeded.

Open **Card studio** to create cards, import a collection, or choose **Edit card**. A new card needs Albanian, an English meaning, and a topic. A stable key is generated if you leave it blank. Illustration, notes, and source can be changed too. Save once: new and imported cards are ready to practice, and edits stay available. Validation errors appear in the editor. An archived card stays archived when edited until you choose **Restore card**.

Reviewing is optional. The editor shows the saved wording, and its optional review section can record who checked it. Editing clears that review note so it never claims the changed wording was checked. **Archive card** hides a card from practice without deleting it or its history; restore it anytime. Old `/parent` links still open the shared studio.

The **Quality check** column lets you flag each card for **Prishtina / less formal wording**, **Update, change or add picture**, and **Delete**, as three compact icon checkboxes in a row, with a quick notes line. Use **Save all** at the top to save every pending change, including cards hidden by filters. Delete records a request for later removal. Feedback is separate from vocabulary notes and does not change the card or its practice history. **Export JSON** includes `quality_language`, `quality_image`, `quality_delete`, and `quality_notes` alongside card IDs and wording so an AI agent can work through your feedback. Uncheck flags and choose **Save all** to clear them after the work is done.

Practice shows an English prompt, then reveals Albanian. “I remembered!” schedules the next review in 1, 3, 7, 14, then 30 days. “Still learning” returns after 10 minutes. **All cards** is the default: All topics and All levels include every active card, including new cards and cards already practiced. Topic and level filters narrow this full collection. **Daily practice** is an optional shorter mode containing up to five due cards and three new cards; its daily new-card cap resets at midnight UTC. The cap does not restrict All cards. Repeating a remembered card before its due date records practice without inflating its learning streak or pushing its due date back. Changed wording has its own progress revision. Every answer saves automatically and moves to the next card. Use **Turn card back** to see English again, or **Next card** to skip without recording an answer. Skipped cards remain available for later practice. When an all-card session ends, choose **Start again** to repeat the collection.

## Physical flashcards

Open **Card studio** to create, edit, and print flashcards in one place. The checkbox above the card rows selects all shown available cards; click it again to clear the selection. A dash indicates a partial selection. The compact **Select new** action selects only unprinted cards. Select new replaces your selection with only the shown cards whose print count is zero. Search by word or topic using the studio’s existing search box. Selections stay while you filter. Both roles can print all available cards; optional language review is unchanged. Archived cards are excluded. Click **Print cards** and **Download front & back PDF**. Each download supports up to 300 selected cards, in card ID order. Refresh the page if a selected card was edited or archived in another window.

Choose **20** in the **Per click** toggle to select a clicked card and the next 19 available cards in the displayed list, stopping at the end. This respects the current search and status filters, skips archived cards, and preserves other selections. Unchecking removes just that card. Choose **1** to return to individual selection.

The **Printed** column shows **Never** or a count such as **2×**. Each successful flashcard PDF download adds one to each included card, including reprints; front and back together count once. Test sheets and failed requests do not count. Counts update in open studio tabs, survive edits and archive/restore, and are included in full database backups. Counts start at zero with this update because earlier downloads were not recorded. They track generated PDFs, since the app cannot detect physical printer completion. Vocabulary JSON import/export does not restore print history.

Fronts show Albanian; backs show English. **Picture side** places illustrations on the **Albanian side (front)** by default, or the **English side (back)**. Cards without illustrations stay text-only. Revision footers are omitted from every card layout. One PDF alternates each sheet's front and matching back, including the empty positions on a partial sheet. Choose 8 cards per sheet (3.75 × 2.5 inches), 10 (3.75 × 2 inches), or **21 cards in a 3 × 7 grid** (2.5 × approximately 1.43 inches). All layouts use US Letter portrait with half-inch margins. The 21-card layout uses smaller illustrations and text to fit; long wording may need to be shortened to stay readable. Stable card IDs appear on both sides. **Download test sheet** uses your chosen layout, including all 21 numbered positions for the 3 × 7 grid.

For a new printer, **Download test sheet** first. Print at **Actual size / 100%**, with double-sided printing and **flip on long edge** by default. Hold the numbered sheet to the light to check matching numbers and centers, then cut along the front guides. Short-edge flip and back offsets up to ±5 mm are available; use the same settings for your test sheet and cards. Positive X moves the back right; positive Y moves it up. Manual refeed order depends on your printer. Physical printer alignment still needs this test on your own printer.

PDF generation runs offline inside the app container using ReportLab and bundled fonts/artwork. No host installation is needed. Downloads update print counts while preserving saved wording and practice history. Keep a downloaded PDF for an exact historical reprint.

## Import and export

Use **Import JSON** in either role. Cards become available immediately; no review, reviewer name, or approval step is required.

```json
{
  "cards": [
    {
      "concept": "food.apple",
      "albanian": "mollë",
      "english": "apple",
      "category": "food",
      "difficulty": "beginner",
      "source": "AI proposal",
      "notes": "Confirm the family’s preferred wording whenever convenient.",
      "image": "apple"
    }
  ]
}
```

This example duplicates a starter card and will be skipped. Required import fields: `concept`, `albanian`, `english`, `category`. Optional: `difficulty` (`beginner` or `growing`), `notes`, `source`, and a bundled `image` key from the editor. Default source during import is `AI proposal`. Up to 300 cards / 200 KB per import. Reference-project exports work; imported status, reviewer, and IDs are ignored so all added cards start available and without a fabricated review.

Duplicates are checked against normalized concepts, Albanian, and English, including historical corrections. They are skipped without overwriting existing cards. Invalid imports roll back entirely. Semantic duplicates still need a human decision. **Export** downloads vocabulary; use backups to preserve all progress and history. Codex can use exported vocabulary to suggest new JSON cards without any AI service inside the app.

## Maintain

```sh
docker compose ps
docker compose logs --tail=100 app
./scripts/backup.sh
docker compose restart app
docker compose up -d --build --wait app
docker compose stop app
```

Data lives in `alboteach_learning_data`, separate from the image. Restart, rebuild, and `docker compose down` preserve it. Removing the volume (including `docker compose down -v`) erases it. The update from the original review-first version makes pending cards available while preserving wording, revisions, progress, and historical review records; archived cards remain archived.

`backup.sh` uses SQLite’s online backup API, checks integrity, and writes owner-only files to `backups/`. Keep copies and `albo/.env` in your own secure backup location. To replace local data:

```sh
./scripts/restore.sh --replace-local-data backups/alboteach-TIMESTAMP.sqlite
```

Restore checks the backup’s integrity/schema, backs up current data, stops this app, restores the database, and starts it again. It expects the fixed Compose project name `alboteach` and a running app. Older AlboTeach backups migrate on startup. The separate print generator’s SQLite files are not interchangeable.

## Develop and verify inside Docker

```sh
docker compose build tools
docker compose run --rm tools mix deps.get
docker compose run --rm tools mix precommit
```

`precommit` compiles with warnings as errors, formats, and tests in a separate test database. Rebuild the app image after edits. [Browser QA](qa/README.md) also runs in Docker using a disposable database, not your collection.

No child names, email accounts, analytics, external AI calls, audio, quizzes, cloud hosting, or automatic remote backups are included. The original `kosovo-flashcards/` project is unchanged and can still handle printing independently. Webapp print dependencies and font credits are documented in [printing notes](albo/priv/printing/README.md). Artwork: [Twemoji credits](albo/priv/static/images/cards/credits.json) and [CC BY 4.0 license](albo/priv/static/images/cards/LICENSE-Twemoji.txt).
