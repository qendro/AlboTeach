# Updated local MVP verified October 24, 2026

The user requested password-free entry, equal tools for learners and parents, working editing, and immediate card availability without mandatory review. These supersede the original review-first workflow documented in [the historical verification record](verification-initial.md).

- `docker compose run --rm tools mix precommit`: **21 tests, 0 failures**. Compilation with warnings as errors and formatting passed.
- Both role passwords are empty in the existing local `.env`. The signing secret was preserved. The input is hidden, and entry creates a valid session without typing anything. Optional configured-password behavior remains tested.
- Both roles can navigate to Card studio and use creation, import, edit, export, optional review, archive, and restore. Existing `/parent` links remain functional.
- Created/imported cards are immediately active, and edits keep them available. Tests assert import status/reviewer fields cannot fabricate a review or hide an imported card. Atomic import, duplicate history, revision checks, and practice scheduling still pass.
- Fixed the invalid-edit no-op bug: required-field validation can remove the invalid change while retaining an error, and the old save path incorrectly treated that as success. Invalid changesets now fail before the no-op branch; the editor stays open and displays errors. Actual field edits, save, and reopening were verified in a real browser for both roles.
- Playwright / Chromium in Docker passed the new workflow on an isolated disposable database: password-free entry, starter cards visible immediately, learner and parent imports, edits, optional reviews, archive/restore, creation without an internal key, practice of imported/created wording, and downloadable exports. No browser errors. Mobile overflow checks passed.
- Visually inspected the new password-free login, shared studio on mobile, and simplified editor. Screenshots are in `output/browser-updated/`.
- The actual release was rebuilt and restarted in Docker and reports healthy at `http://localhost:4010`. Migration converted all 12 existing starter cards to `active`, retaining their wording/revisions and empty progress; no review was fabricated. Archived cards are not changed by the migration. Actual SQLite integrity check passed.
- An online backup was taken before applying the data migration, and another backup was taken after the update. The initial backup/restore and restart-persistence results are retained in the historical verification record. Temporary browser fixtures are not in the actual learning volume.

All dependency installation, runtime, tests, and browser automation ran inside Docker. No remote infrastructure or reference-project changes were made.

## Live connection and card navigation fix

The running server rejected WebSocket origins from `http://127.0.0.1:4010` because its allowlist contained only `localhost`. The browser could render the initial HTML but could not flip cards, submit LiveView events, or clear the disconnected warning. Local runtime configuration now accepts both loopback hostnames while retaining origin checks.

- `mix precommit` inside Docker: **22 tests, 0 failures**. New coverage verifies flipping back and forth and Next card skipping without recording progress or processing duplicate clicks.
- Browser regression on the release image at both **http://localhost:4010** and **http://127.0.0.1:4010** passed: live connection established, warning hidden, flip to Albanian, flip back to English, next-card counter/content advance, warning shown during a simulated socket disconnection, and automatic recovery with warning cleared.
- Added a visible **Next card** control to skip without inventing a recall answer. Answer buttons continue to save and advance; **Turn card back** reveals English again.
- The rebuilt local app is healthy, and its logs now confirm a successful LiveView WebSocket connection from `127.0.0.1:4010`.
- The full creation/import/edit/practice/export browser workflow also passed using `http://127.0.0.1:4010`, with no browser errors and the disconnect banner hidden while connected. Disposable QA data was removed afterward.

## Full collection in All topics

The default flashcard view previously reused the daily scheduler, hiding cards after the three-new-card allowance or until their next due date. It now defaults to **All cards**, with **All topics** and **All levels** covering every active card regardless of prior practice. Topic/level filters narrow the collection. **Daily practice** remains an explicitly selected shorter mode.

All-card answers can introduce more than three words and record repeat practice. Remembering a card before it is due preserves its existing streak and due date, so repeated browsing does not inflate mastery. Skipping still records no answer. Completed all-card sessions offer Start again.

- Docker precommit passed **24 tests** before concurrent printing work began. Added regression coverage exercises a collection larger than three, cards previously practiced today, topic filters, all-card grading beyond the daily cap, early-repeat streak preservation, and restarting the complete collection.
- Browser regression passed on both loopback addresses: all 12 starter cards are individually reachable, Food narrows the view to 6, All topics restores 12, Daily practice narrows to 3, All cards restores 12, and Start again restarts the full set. Connection and reconnection checks still passed.
- A later full recheck encountered incomplete `PrintLive`/`PrintController` work being added concurrently in the shared workspace. Those changes were left untouched. The running release and isolated browser test image contain the completed All cards change.
- The final focused Learning and LiveView regression run passed **16 tests, 0 failures**, including grading all seven fixture cards after the daily allowance was exhausted. The full real-browser create/import/edit/practice/export flow also passed on the updated release. Temporary QA data was removed.
- After the concurrent printing modules appeared, the final full compile with warnings as errors and entire test suite completed successfully: **24 tests, 0 failures**. The temporary compilation limitation above is resolved.
