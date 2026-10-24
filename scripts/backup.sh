#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
umask 077
mkdir -p backups
name="alboteach-$(date -u +%Y%m%dT%H%M%SZ).sqlite"
[ ! -e "backups/$name" ] || { echo 'A backup already exists for this second; run again shortly.' >&2; exit 1; }
docker compose exec -T app sqlite3 /data/albo.sqlite ".timeout 10000" ".backup '/tmp/$name'"
check=$(docker compose exec -T app sqlite3 "/tmp/$name" 'PRAGMA integrity_check;')
[ "$check" = ok ] || { echo 'Backup integrity check failed.' >&2; exit 1; }
docker compose exec -T app cat "/tmp/$name" > "backups/$name"
docker compose exec -T app rm "/tmp/$name"
chmod 600 "backups/$name"
echo "Backup verified: backups/$name"
