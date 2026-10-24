# All dependencies and compilation stay inside Docker.
FROM elixir:1.18.4-otp-27-slim AS build
RUN apt-get update && apt-get install -y --no-install-recommends build-essential git ca-certificates \
    && rm -rf /var/lib/apt/lists/*
ENV MIX_ENV=prod HEX_CACERTS_PATH=/etc/ssl/certs/ca-certificates.crt
WORKDIR /app
RUN mix local.hex --force && mix local.rebar --force
COPY mix.exs mix.lock ./
COPY config/config.exs config/prod.exs config/
RUN mix deps.get --only prod && mix deps.compile
COPY lib lib
COPY priv priv
COPY assets assets
RUN mix compile && mix assets.deploy
COPY config/runtime.exs config/runtime.exs
# Runtime configuration must be included when assembling the release.
RUN mix release

FROM debian:bookworm-slim AS runtime
RUN apt-get update && apt-get install -y --no-install-recommends libstdc++6 openssl libncurses6 ca-certificates sqlite3 curl python3 python3-reportlab \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --uid 10001 app \
    && mkdir -p /data /backups && chown app:app /data /backups
WORKDIR /app
COPY --from=build --chown=app:app /app/_build/prod/rel/albo ./
COPY --chown=app:app docker/entrypoint.sh ./entrypoint.sh
USER app
ENV PHX_SERVER=true PORT=4000 DATABASE_PATH=/data/albo.sqlite ERL_FLAGS="+S 2:2" LANG=C.UTF-8 LC_ALL=C.UTF-8
EXPOSE 4000
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 CMD curl -fsS http://127.0.0.1:4000/health || exit 1
ENTRYPOINT ["/app/entrypoint.sh"]
