#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
if [ -f albo/.env ]; then
  echo 'Existing local credentials preserved in albo/.env.'
  exit 0
fi
umask 077
# Docker supplies the runtime; nothing is installed on the host.
docker run --rm elixir:1.18.4-otp-27-slim elixir -e '
random = fn n -> :crypto.strong_rand_bytes(n) |> Base.url_encode64(padding: false) end
IO.puts("SECRET_KEY_BASE=#{random.(64)}")
IO.puts("LEARNER_PASSWORD=")
IO.puts("PARENT_PASSWORD=")
' > albo/.env.tmp
mv albo/.env.tmp albo/.env
chmod 600 albo/.env
echo 'Local settings created with password-free entry in albo/.env (readable only by your user).'
