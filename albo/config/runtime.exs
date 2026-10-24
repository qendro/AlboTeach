import Config
config :albo, AlboWeb.Endpoint, http: [port: String.to_integer(System.get_env("PORT", "4000"))]
if System.get_env("PHX_SERVER"), do: config(:albo, AlboWeb.Endpoint, server: true)

if config_env() != :test do
  passwords =
    Map.new([{"learner", "LEARNER_PASSWORD"}, {"parent", "PARENT_PASSWORD"}], fn {role, key} ->
      value = System.get_env(key, "")

      if value != "" && String.length(value) < 16,
        do: raise("#{key} must contain at least 16 characters")

      {role, value}
    end)

  config :albo, :passwords, passwords
end

if config_env() == :prod do
  host = System.get_env("PHX_HOST", "localhost")
  scheme = if host in ["localhost", "127.0.0.1"], do: "http", else: "https"

  origins =
    if host in ["localhost", "127.0.0.1"], do: ["//localhost", "//127.0.0.1"], else: ["//#{host}"]

  extra_origins =
    System.get_env("PHX_EXTRA_ORIGINS", "")
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)

  config :albo, Albo.Repo,
    database: System.fetch_env!("DATABASE_PATH"),
    pool_size: 1,
    journal_mode: :wal,
    busy_timeout: 10_000

  config :albo, AlboWeb.Endpoint,
    url: [
      host: host,
      port:
        if(scheme == "https",
          do: 443,
          else: String.to_integer(System.get_env("LOCAL_PORT", "4010"))
        ),
      scheme: scheme
    ],
    check_origin: origins ++ extra_origins,
    http: [ip: {0, 0, 0, 0}],
    secret_key_base: System.fetch_env!("SECRET_KEY_BASE")
end
