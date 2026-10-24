defmodule Albo.Learning.Review do
  use Ecto.Schema

  schema "reviews" do
    field :card_id, :integer
    field :revision, :integer
    field :result, :string
    field :token, :string
    field :introduced, :boolean
    timestamps(type: :utc_datetime, updated_at: false)
  end
end
