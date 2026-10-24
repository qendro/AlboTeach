#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
[ "$#" -eq 2 ] && [ "$1" = --replace-local-data ] || { echo 'Usage: ./scripts/restore.sh --replace-local-data backups/NAME.sqlite' >&2; exit 1; }
[ -f "$2" ] || { echo 'Backup file not found.' >&2; exit 1; }
backup_dir=$(cd "$(dirname "$2")" && pwd)
backup="$backup_dir/$(basename "$2")"
check=$(docker run --rm --network none --user 0 -v "$backup:/backup.sqlite:ro" --entrypoint sqlite3 alboteach:local /backup.sqlite 'PRAGMA integrity_check;')
[ "$check" = ok ] || { echo 'Backup integrity check failed. Local data has not changed.' >&2; exit 1; }
docker run --rm --network none --user 0 -v "$backup:/backup.sqlite:ro" --entrypoint sqlite3 alboteach:local /backup.sqlite \
  'SELECT version FROM schema_migrations LIMIT 0; SELECT concept, albanian, english, revision, status FROM cards LIMIT 0; SELECT card_id, revision, due_at FROM progress LIMIT 0; SELECT token, introduced FROM reviews LIMIT 0;' \
  || { echo 'This is not a compatible AlboTeach backup. Local data has not changed.' >&2; exit 1; }
# Preserve the current state before replacing it.
./scripts/backup.sh
docker compose stop app
docker run --rm --network none --user 0 -v alboteach_learning_data:/data -v "$backup:/backup.sqlite:ro" --entrypoint sh alboteach:local -c '
  cp /backup.sqlite /data/albo.restore.sqlite
  chown 10001:10001 /data/albo.restore.sqlite
  chmod 600 /data/albo.restore.sqlite
  rm -f /data/albo.sqlite-wal /data/albo.sqlite-shm
  mv /data/albo.restore.sqlite /data/albo.sqlite
'
docker compose up -d --wait app
echo 'Local data restored. The previous state is preserved in backups/.'
