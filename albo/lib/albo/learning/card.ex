defmodule Albo.Learning.Card do
  use Ecto.Schema
  import Ecto.Changeset
  @fields ~w(concept albanian english category difficulty notes source image)a
  @quality_fields ~w(quality_language quality_image quality_delete quality_notes)a
  @external_resource Path.expand("../../../priv/static/images/cards/credits.json", __DIR__)
  @images @external_resource |> File.read!() |> Jason.decode!() |> Enum.map(& &1["key"])
  @color_map_path Path.expand("../../../priv/collections/color-art/display-map.json", __DIR__)
  @external_resource @color_map_path
  @color_images @color_map_path |> File.read!() |> Jason.decode!()
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
    field :quality_language, :boolean, default: false
    field :quality_image, :boolean, default: false
    field :quality_delete, :boolean, default: false
    field :quality_notes, :string, default: ""
    timestamps(type: :utc_datetime)
  end

  def images, do: @images
  def fields, do: @fields
  def quality_fields, do: @quality_fields
  def display_image(image), do: Map.get(@color_images, image, image)

  def quality_changeset(card, attrs) do
    card
    |> cast(attrs, @quality_fields, empty_values: [])
    |> validate_length(:quality_notes, max: 2000)
  end

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
