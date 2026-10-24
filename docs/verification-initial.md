# Verified October 24, 2026

All application builds, dependency installations, tests, database checks, and browser automation ran inside Docker on the local Mac (ARM64). No host language runtime or package was installed. Oracle inspection used an existing Docker tooling image, read-only credentials, and read-only API/SSH commands; no remote changes were made.

- `docker compose run --rm tools mix precommit`: **18 tests, 0 failures**, with compilation warnings treated as errors. Formatting completed.
- `docker compose up -d --build --wait app`: release built, migrated, seeded, and became healthy. Rebuild/recreation and restart preserved the actual collection.
- HTTP health: `{"status":"ok"}`. Only `127.0.0.1:4010` is published.
- Actual collection: **12 proposed starter cards, 0 approved cards, 0 learner progress entries** at handoff. No real language was approved by software tests.
- Playwright 1.56.1 / Chromium in Docker: desktop 1440×1050 and mobile 390×844. Sign-in/out, both roles, LiveView connection, parent creation and explicit approval of synthetic fixtures, learner reveal/grade/complete, and resume all passed. Mobile overflow checks passed. No browser console errors or uncaught page exceptions.
- Visually inspected the desktop dashboard and login, mobile login/dashboard/parent card layout, and revealed practice card. Fixed the mobile parent-table overflow and sign-in heading contrast discovered during inspection. Screenshots are in `output/browser/`.
- `scripts/backup.sh`: successful online SQLite snapshots, integrity check `ok`, exported to owner-only files in `backups/`. Docker Desktop does not export this container’s tmpfs through `docker cp`; the script uses a binary stream over `docker exec` instead.
- Restored an actual local backup into an isolated volume: integrity `ok`, all 12 proposals and original empty review history preserved.
- Separately backed up the completed browser fixture session and restored into another isolated Docker volume: **15 cards, 3 progress entries, 3 review events**. After starting the release and restarting its container, all counts persisted and health passed. These temporary containers/volumes were removed; the actual learning volume was never used for fixtures.
- Maintenance shell scripts pass syntax checks inside Docker. Restore validates database integrity and expected application tables/columns before changing local data.
- Runtime observed at approximately **144 MiB** while idle, with a 512 MiB container memory limit. This is an observation, not a load-test guarantee.

Boundaries: linguistic review remains the parent/tutor’s task. This is a single-household learner MVP. No audio, quiz, print integration, cloud deployment, automatic remote backup, or production domain was configured. The reference project and existing services were left unchanged.
