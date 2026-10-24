# MVP validation

Validation performed in the build environment on October 23, 2026 (America/Chicago).

- 12 unittest cases passed. The PDF test independently checks actual PDF text coordinates for both portrait flip directions, 8/10-card layouts, multiple sheets and an incomplete final sheet.
- Storage tests passed for Unicode duplicates, preserved corrections, atomic imports/reviews, stale revisions, combined selection filters, explicit print guards, copied images and SQLite/media backups.
- A distributable wheel was built and installed to a separate directory without dependencies being reinstalled. Its CLI imported all 12 sample cards and rendered the four-page draft successfully, verifying packaged fonts and image assets.
- The isolated `examples/demo_workflow.py` ran successfully: draft import, visual review export, correction, explicit software-fixture approval, PDF render and approved JSON export. No starter-card approvals were created.
- All four supplied starter PDF pages and both calibration pages were rendered to PNG and inspected for glyphs, clipping, illustration placement, mirrored order and partial-sheet blanks.
- ReportLab 4.4.9, Pillow 12.3.0 and pypdf 6.10.0 were available in the build environment. pypdf is a test dependency only; the app's runtime uses ReportLab and Pillow.

The supplied collection has 12 proposed, zero approved cards. The language is a reviewable AI proposal, not linguistically verified content. No physical printer was available, and the user's desktop environment has not yet been installed or tested. The included calibration PDF checks physical feed offsets locally.
