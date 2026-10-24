defmodule Albo.Learning.ContentEvent do
  use Ecto.Schema

  schema "content_events" do
    field :card_id, :integer
    field :action, :string
    field :snapshot, :string
    timestamps(type: :utc_datetime, updated_at: false)
  end
end
