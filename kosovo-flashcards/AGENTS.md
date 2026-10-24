# Operating this flashcard project in Codex

Use this local CLI as the primary interface. Read README.md for commands. No server, model API integration, MCP service, frontend, learner-progress system or paid image service is needed for the MVP.

## Language authority and approval

- Teach everyday conversational Kosovo Albanian to a beginner who already knows English. Start with individual words and very short phrases. The parent/tutor's explicit corrections and approved card wording take priority over model recollection and formal textbook forms.
- The database is authoritative. Read current cards and generation exclusions before proposing content. Do not use your conversation memory as a substitute for the collection.
- Every generated card is proposed. Label uncertainty in `notes`; `source` should say AI proposal unless a real source was supplied. Do not invent linguistic verification or parent review.
- Only run approval commands or set `decision: approved` after explicit human approval of the identified cards. State the IDs being approved and record the human reviewer. Do not treat "create cards" or "make a PDF" as language approval.
- Changes clear approval. Do not bypass this by editing SQLite directly.

## New batches

1. Run `python -m kosovo_cards brief --count N --topic TOPIC -o output/next-brief.json` using the virtualenv interpreter if required. Read that file. It contains existing and historical exclusions, approved wording and valid image keys.
2. Write a small JSON draft with a `cards` array using the brief's template. Each card requires `concept`, `albanian`, `english`, `category`. Use a stable English concept key such as `food.apple`. Keep forms consistent with the family's reviewed vocabulary; avoid giving definite/indefinite or inflected variants new keys just to evade deduplication. Optional: part_of_speech, difficulty, notes, source, image. Do not supply status or an ID.
3. Use a bundled image only when it clearly conveys the intended meaning. Leave abstract words/phrases without art. Avoid generating new illustrations when a consistent licensed asset fits.
4. Import with a unique batch name. Read the result; duplicates are skipped, never replaced. If fewer cards were added than requested, propose replacements for the missing count using the latest exclusions, then import under another batch name.
5. Generate `review --batch NAME --json ... --html ...`. Show the user the visual report and relevant dialect notes. Wait for content review when needed; do not claim the batch is approved.
6. For an explicit preview request, `render --allow-proposed` produces clearly marked draft cards. Use normal render only for approved vocabulary.

## Corrections and images

Read `show ID`, write a JSON patch, and call `update ID --patch FILE --revision CURRENT`. Keep the card ID stable. Example: replacing the illustration on card 12 uses an image key patch; its content approval is then cleared. For new PNG/JPEG art use `image-add` with real credit, license and source. Imports copy bytes locally. Never mutate bundled images or managed image files in place.

Use exported review JSON for bulk edits and explicit decisions. Preserve IDs/revisions; stale reviews must be regenerated. `apply-review` checks and writes the entire batch atomically.

## Printing and preservation

Default: US Letter portrait, 8 cards/sheet, alternating front/back pages, long-edge duplex, 100%/Actual size. Always recommend the numbered calibration sheet for a new printer. If the user supplies back offsets, use the same flip and offsets for calibration and final cards. Physical printer alignment has not been verified here.

Use the existing PDFs for exact historical reprints; a fresh render uses current card revisions. Save editions under distinct filenames. Preserve `.manifest.json` and `.credits.txt` alongside PDFs. Avoid overwriting earlier output unless requested. Back up the database and managed media with the backup command before maintenance. Do not reset `data/cards.sqlite` or mark test fixtures as linguistic evidence.

Keep repetitive operations in software. The tool makes no AI calls. When adding features, prefer Python's standard library and the existing ReportLab/Pillow stack. Run `python -m unittest discover -s tests -v` after changes affecting storage, reviews or printing. Fix failures before delivery; keep scope local and simple.
