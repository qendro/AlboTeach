#!/bin/sh
set -eu
# Run migrations and seed proposals before the HTTP listener starts.
/app/bin/albo eval 'Albo.Release.prepare()'
exec /app/bin/albo start
