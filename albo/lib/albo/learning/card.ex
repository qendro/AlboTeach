defmodule Albo.Learning.Card do
  use Ecto.Schema
  import Ecto.Changeset
  @fields ~w(concept albanian english category difficulty notes source image)a
  @images ~w(apple banana bread egg milk water house door chair bed fish cat cheese cup rice tree sun car fork-knife spoon dog hand book ball)
  schema "cards" do
    field :concept, :string
    field :albanian, :string
    field :english, :string
    field :category, :string
    field :difficulty, :string, default: "beginner"
    field :notes, :string, default: ""
    field :source, :string, default: "Family entry"
    field :image, :string, default: ""
    field :status, :string, default: "active"
    field :reviewer, :string
    field :revision, :integer, default: 1
    field :print_count, :integer, default: 0
    timestamps(type: :utc_datetime)
  end

  def images, do: @images
  def fields, do: @fields

  def changeset(card, attrs) do
    card
    |> cast(attrs, @fields)
    |> validate_required(~w(concept albanian english category difficulty source)a)
    |> validate_length(:concept, max: 100)
    |> validate_format(:concept, ~r/^[a-z0-9][a-z0-9._-]*$/)
    |> validate_length(:albanian, max: 160)
    |> validate_length(:english, max: 160)
    |> validate_length(:category, max: 50)
    |> validate_length(:notes, max: 2000)
    |> validate_length(:source, max: 200)
    |> validate_inclusion(:difficulty, ~w(beginner growing))
    |> validate_inclusion(:image, [nil, "" | @images])
    |> unique_constraint(:concept)
  end
end
