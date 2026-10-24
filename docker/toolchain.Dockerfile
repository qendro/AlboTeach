FROM elixir:1.18.4-otp-27-slim
RUN apt-get update && apt-get install -y --no-install-recommends build-essential git ca-certificates sqlite3 curl python3 python3-reportlab python3-pypdf poppler-utils \
    && rm -rf /var/lib/apt/lists/*
ENV HEX_CACERTS_PATH=/etc/ssl/certs/ca-certificates.crt
RUN mix local.hex --force && mix local.rebar --force && mix archive.install hex phx_new 1.8.16 --force
WORKDIR /workspace
