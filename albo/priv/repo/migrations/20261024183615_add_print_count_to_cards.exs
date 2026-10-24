defmodule Albo.Repo.Migrations.AddPrintCountToCards do
  use Ecto.Migration

  def change do
    alter table(:cards) do
      add :print_count, :integer, null: false, default: 0
    end
  end
end
