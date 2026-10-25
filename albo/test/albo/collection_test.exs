defmodule Albo.CollectionTest do
  use Albo.DataCase
  alias Albo.{Learning, Repo}
  alias Albo.Learning.Card

  test "the expansion imports to 200, keeps starters intact, and is safe to repeat" do
    Learning.seed()
    originals = Learning.list_cards()
    json = File.read!(Application.app_dir(:albo, "priv/collections/kosovo-200/import.json"))
    assert {:ok, %{added: 188, skipped: 0}} = Learning.import_json(json)
    assert Repo.aggregate(Card, :count) == 200
    for original <- originals, do: assert(Learning.get_card!(original.id) == original)
    assert {:ok, %{added: 0, skipped: 188}} = Learning.import_json(json)
    assert Enum.all?(Learning.list_cards(), &(&1.reviewer == nil && &1.status == "active"))

    for card <- Learning.list_cards(), card.image not in [nil, ""] do
      display_image = Card.display_image(card.image)
      assert String.starts_with?(display_image, "color-")

      assert File.exists?(
               Application.app_dir(:albo, "priv/static/images/cards/#{display_image}.svg")
             )

      assert File.exists?(Application.app_dir(:albo, "priv/printing/images/#{display_image}.png"))

      assert File.exists?(
               Application.app_dir(:albo, "priv/static/images/cards/#{card.image}.svg")
             )

      assert File.exists?(Application.app_dir(:albo, "priv/printing/images/#{card.image}.png"))
    end
  end
end
