defmodule Albo.Learning.Progress do
  use Ecto.Schema

  schema "progress" do
    field :card_id, :integer
    field :revision, :integer
    field :streak, :integer, default: 0
    field :reviews, :integer, default: 0
    field :due_at, :utc_datetime
    timestamps(type: :utc_datetime)
  end
end
