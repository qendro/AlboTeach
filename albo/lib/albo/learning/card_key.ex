defmodule Albo.Learning.CardKey do
  use Ecto.Schema

  schema "card_keys" do
    field :card_id, :integer
    field :kind, :string
    field :value, :string
  end
end
