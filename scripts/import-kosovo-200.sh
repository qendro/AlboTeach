#!/bin/sh
# Uses the application's supported transactional importer; never overwrites cards.
set -eu
cd "$(dirname "$0")/.."
./scripts/backup.sh
docker compose exec -T app /app/bin/albo rpc '
path = Application.app_dir(:albo, "priv/collections/kosovo-200/import.json")
case Albo.Learning.import_json(File.read!(path)) do
  {:ok, counts} -> IO.inspect(counts, label: "Collection import")
  {:error, reason} -> raise "Import rolled back: #{inspect(reason)}"
end
'
