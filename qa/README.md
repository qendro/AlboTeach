# Optional browser QA (Docker only)

Build the app first. Run from the repository root with the default empty passwords:

```sh
docker build -t alboteach-browser-qa:local qa
docker run -d --name alboteach-qa --env-file albo/.env \
  -e PHX_HOST=localhost -e DATABASE_PATH=/data/qa.sqlite \
  --tmpfs /data:uid=10001,gid=10001 --tmpfs /tmp:mode=1777 alboteach:local
docker exec alboteach-qa sh -c 'until curl -fsS http://localhost:4000/health >/dev/null; do sleep 1; done'
docker exec alboteach-qa /app/bin/albo rpc 'Albo.Learning.seed()'
docker run --rm --network container:alboteach-qa -e QA_PORT=4000 \
  -v "$PWD/output/connection:/output" --entrypoint node alboteach-browser-qa:local /qa/connection.cjs
docker run --rm --network container:alboteach-qa --env-file albo/.env \
  -v "$PWD/output/browser-updated:/output" alboteach-browser-qa:local
docker rm -f alboteach-qa
docker run -d --name alboteach-print-qa --env-file albo/.env \
  -e PHX_HOST=localhost -e DATABASE_PATH=/data/qa.sqlite \
  --tmpfs /data:uid=10001,gid=10001 --tmpfs /tmp:mode=1777 alboteach:local
docker exec alboteach-print-qa sh -c 'until curl -fsS http://localhost:4000/health >/dev/null; do sleep 1; done'
docker exec alboteach-print-qa /app/bin/albo rpc 'Albo.Learning.seed()'
docker run --rm --network container:alboteach-print-qa \
  -v "$PWD/output/printing:/output" --entrypoint node alboteach-browser-qa:local /qa/printing.cjs
docker rm -f alboteach-print-qa
```

Printing QA uses a separate fresh QA database. It verifies selection across searches, select all/new, 20-card forward selection with more than 20 synthetic cards, live print counters and persistence after reload, real card and calibration downloads for both roles, 8/10/21-card layouts and both flip settings, Albanian/English picture placement, alignment offsets, mobile overflow, and browser errors. The 3 × 7 layout is exercised with 24 cards to verify its partial second sheet. Downloaded PDFs and screenshots are saved to `output/printing/`. Renderer regressions run with `docker compose run --rm tools python3 -m unittest discover -s test/printing -v`; these inspect picture drawing operations on each page and verify revision footers are absent.

The script waits for health before browsing. It verifies one-click entry for both roles, immediate starter/imported/created card availability, full learner and parent studio access, actual edit/save/reopen, optional review, archive/restore, practice, export, mobile overflow, and browser errors. Screenshots use desktop 1440×1050 and mobile 390×844.

The QA app has no host port and uses an isolated memory-backed database. New cards and optional reviewer names are clearly labeled synthetic software fixtures. It never uses `alboteach_learning_data`. Playwright and browsers run inside Docker; nothing is installed on the host.

The connection regression visits both `localhost` and `127.0.0.1`, verifies the warning is hidden while connected, flips both ways, advances with Next card, and simulates a dropped socket to verify the warning appears and then clears on reconnection. For the exact published-port configuration, start the QA app with `-e PORT=4010` and run the scripts with `-e QA_PORT=4010` and `-e QA_BASE_URL=http://127.0.0.1:4010` respectively.

Card ordering QA uses an **empty**, disposable database and `node /qa/card-order.cjs` in the browser image. It covers contiguous allocation, live swaps across two windows, grouping, all sortable headers, URL persistence, mobile controls, hidden print selections, a real ordered PDF, single/bulk deletion, and artwork preservation. Run it again with `QA_PHASE=empty-restart` after restarting the same QA app to verify empty collections remain empty and the next card starts at 1.

The restart check needs a persistent disposable QA volume (a tmpfs is erased when a container restarts). Example, using the built browser image:

```sh
docker run -d --name alboteach-card-order-qa --env-file albo/.env -e PHX_HOST=localhost -e DATABASE_PATH=/data/qa.sqlite -v alboteach-card-order-qa-data:/data --tmpfs /tmp:mode=1777 alboteach:local
docker run --rm --network container:alboteach-card-order-qa -v "$PWD/output/card-order:/output" --entrypoint node alboteach-browser-qa:local /qa/card-order.cjs
docker restart alboteach-card-order-qa
docker run --rm --network container:alboteach-card-order-qa -e QA_PHASE=empty-restart -v "$PWD/output/card-order:/output" --entrypoint node alboteach-browser-qa:local /qa/card-order.cjs
docker rm -f alboteach-card-order-qa
docker volume rm alboteach-card-order-qa-data
```

`studio-readonly.cjs` checks an existing collection without changing database records. It verifies every sortable header, selected-card preview, mobile checkbox interaction, and viewport layout; set `QA_BASE_URL` and `EXPECTED_CARDS` for the intended environment.
