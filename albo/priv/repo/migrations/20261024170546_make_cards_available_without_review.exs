defmodule Albo.Repo.Migrations.MakeCardsAvailableWithoutReview do
  use Ecto.Migration

  def change do
    # Availability is independent of linguistic review. Preserve reviewer metadata and all progress.
    execute "UPDATE cards SET status = 'active' WHERE status IN ('proposed', 'approved')",
            "UPDATE cards SET status = 'proposed' WHERE status = 'active'"
  end
end
