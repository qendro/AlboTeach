defmodule Albo.Repo.Migrations.AddCardGroupingAndOrder do
  use Ecto.Migration

  def up do
    alter table(:cards) do
      add :subcategory, :string, null: false, default: ""

      add :sort_order, :integer,
        null: false,
        default: 1,
        check: %{name: "cards_sort_order_positive", expr: "sort_order > 0"}
    end

    execute """
    WITH positions AS (
      SELECT id, ROW_NUMBER() OVER (ORDER BY category, id) AS position FROM cards
    )
    UPDATE cards SET sort_order = (SELECT position FROM positions WHERE positions.id = cards.id)
    """

    create unique_index(:cards, [:sort_order])
  end

  def down do
    drop unique_index(:cards, [:sort_order])

    alter table(:cards) do
      remove :subcategory
      remove :sort_order
    end
  end
end
