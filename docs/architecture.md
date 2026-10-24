# Architecture and scope

AlboTeach is a local, independent Phoenix 1.8.16 / LiveView 1.2 application on Elixir 1.18 / Erlang OTP 27. Docker builds a production release. Its runtime is an unprivileged user with a read-only root filesystem, limited resources, and a writable SQLite volume. One app container, no separate database service, and no cloud dependency. Only `127.0.0.1:4010` is published. Docker Desktop is the only host prerequisite.

SQLite uses WAL, immediate write transactions, a 10-second busy timeout, and one pooled connection. The entrypoint migrates and seeds before serving requests. Content keys and old wording remain reserved to prevent overwriting historical corrections. Content events preserve snapshots; edits increment the revision, and learning progress is tied to that revision. Review attempt tokens and due-time checks prevent duplicate grading across double-clicks or stale tabs.

## Local entry and equal capabilities

Both role passwords default to empty, including the existing local `.env`. The sign-in page hides the corresponding input and only asks the user to press the entry button. Both roles can practice, create/import/edit/export cards, record an optional review, archive, and restore. `/cards` is the shared studio; old `/parent` and `/parent/export` links remain compatible. Roles determine a starting screen and label, not permissions. These routes share an authenticated LiveView session, so moving from learning to Card studio works without a separate authorization boundary.

The app retains signed HTTP-only SameSite cookies, CSRF protection, session expiry, and credential-version checking. Optional non-empty passphrases can be configured later, but setting one does not give its role extra privileges. Failed password entry is throttled; password-free entry needs no throttling. The random signing secret stays in the ignored owner-only `.env` and is preserved during this change.

## Available cards and optional review

New and imported cards have status `active` and are immediately eligible for practice. This means available, not linguistically verified. The migration converts earlier `proposed` and `approved` availability states to `active`, retaining revisions, notes, source, review records, and progress. Archived cards remain archived.

Import ignores incoming status, reviewer, and IDs. Optional review records an actual person’s name when they explicitly choose to do so, but never controls practice availability. Editing clears the review name while leaving an active card available. Archived cards remain archived through edits until restored.

The card editor generates an internal concept key when creating a card; the user only needs Albanian, English, and a topic. Validation runs as the form changes, and failed saves show all errors. Invalid changesets are rejected before considering an empty changes map a successful no-op; this fixes the case where clearing a required field silently closed the editor.

The flashcard screen defaults to All cards, querying every active card regardless of due date or prior practice, with independent topic/level filters. Optional Daily practice retains the incremental schedule: up to three new cards per UTC day plus five due reviews per session. All-card grading can introduce more words and record early practice. Early remembered repeats preserve the existing streak and due date; struggling again schedules a retry. Answer tokens still prevent duplicate submissions. There is one household learner’s progress, shared by both role views.

## Data and assets

All data stays in the named local volume. Backups use the SQLite online backup API and are integrity-checked. Restore validates application tables/columns before replacing data, backs up the current state, and stops only this app. JSON exports transfer vocabulary, not all history or progress.

Bundled Twemoji SVGs come from the original reference project with source URLs, CC BY 4.0 attribution, and license. There are no external fonts, arbitrary media URLs, child identities, analytics, or AI calls. The reference project remains independently usable and unchanged. Audio, quizzes, media uploads, multi-user profiles, print integration, and cloud deployment remain outside this MVP.

## Prior Oracle inspection

Before the user narrowed the MVP to local Docker, read-only OCI/SSH inspection on October 24, 2026 found the existing ARM64 `qbot` instance (2 OCPUs / 8 GB RAM) with Hermes and Photon running separately. No production configuration, credential files, containers, networking, or DNS was changed. Oracle and SSH credentials were mounted read-only into temporary tooling and never copied into this project. Domain/hosting work remains out of scope.

## References and checks

- [Phoenix release deployment](https://hexdocs.pm/phoenix/releases.html)
- [SQLite adapter configuration and transaction behavior](https://github.com/elixir-sqlite/ecto_sqlite3/blob/main/lib/ecto/adapters/sqlite3.ex)
- [Verification record](verification.md)

All builds, dependency installation, tests, and browser automation run in Docker. Tests cover both roles’ equal access, password-free entry, optional configured passwords, immediate availability, edits and validation feedback, optional reviews, archival/restoration, atomic imports, historical duplicates, revisions, and practice scheduling. Browser QA uses synthetic data in a disposable database, never the actual learning volume.
