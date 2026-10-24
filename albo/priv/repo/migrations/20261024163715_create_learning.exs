defmodule Albo.Repo.Migrations.CreateLearning do
  use Ecto.Migration

  def change do
    create table(:cards) do
      add :concept, :string, null: false
      add :albanian, :string, null: false
      add :english, :string, null: false
      add :category, :string, null: false
      add :difficulty, :string, null: false, default: "beginner"
      add :notes, :text, default: ""
      add :source, :string, default: "Parent entry"
      add :image, :string, default: ""
      add :status, :string, null: false, default: "proposed"
      add :reviewer, :string
      add :revision, :integer, null: false, default: 1
      timestamps(type: :utc_datetime)
    end

    create unique_index(:cards, [:concept])
    create index(:cards, [:status, :category])

    create table(:card_keys) do
      add :card_id, references(:cards), null: false
      add :kind, :string, null: false
      add :value, :string, null: false
    end

    create unique_index(:card_keys, [:kind, :value])

    create table(:progress) do
      add :card_id, references(:cards), null: false
      add :revision, :integer, null: false
      add :streak, :integer, null: false, default: 0
      add :reviews, :integer, null: false, default: 0
      add :due_at, :utc_datetime, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:progress, [:card_id])

    create table(:reviews) do
      add :card_id, references(:cards), null: false
      add :revision, :integer, null: false
      add :result, :string, null: false
      add :token, :string, null: false
      add :introduced, :boolean, null: false, default: false
      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:reviews, [:token])
    create index(:reviews, [:inserted_at])

    create table(:content_events) do
      add :card_id, references(:cards), null: false
      add :action, :string, null: false
      add :snapshot, :text, null: false
      timestamps(type: :utc_datetime, updated_at: false)
    end
  end
end
