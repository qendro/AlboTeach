#!/bin/sh
set -eu
# Apply schema migrations before serving requests. Starter content is loaded explicitly.
/app/bin/albo eval 'Albo.Release.prepare()'
exec /app/bin/albo start
