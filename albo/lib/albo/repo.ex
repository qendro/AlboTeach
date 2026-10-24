defmodule Albo.Repo do
  use Ecto.Repo,
    otp_app: :albo,
    adapter: Ecto.Adapters.SQLite3
end
