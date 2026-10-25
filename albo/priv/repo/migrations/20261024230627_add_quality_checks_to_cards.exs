defmodule Albo.Repo.Migrations.AddQualityChecksToCards do
  use Ecto.Migration

  def change do
    alter table(:cards) do
      add :quality_language, :boolean, null: false, default: false
      add :quality_image, :boolean, null: false, default: false
      add :quality_delete, :boolean, null: false, default: false
      add :quality_notes, :text, null: false, default: ""
    end
  end
end
