defmodule Albo.Release do
  @moduledoc "Release-only database preparation."
  def prepare do
    Application.load(:albo)

    for repo <- Application.fetch_env!(:albo, :ecto_repos) do
      {:ok, _, _} =
        Ecto.Migrator.with_repo(repo, fn repo ->
          Ecto.Migrator.run(repo, :up, all: true)
        end)
    end
  end
end
