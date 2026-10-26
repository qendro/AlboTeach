defmodule Albo.CardOrderTest do
  use Albo.DataCase
  import Albo.Fixtures
  alias Albo.{Learning, Printing, Repo}
  alias Albo.Learning.{Card, CardKey, CardOrder, ContentEvent, Progress, Review}

  test "empty collections, imports, skipped duplicates and failed imports keep contiguous positions" do
    assert Learning.list_cards() == []
    first = card(%{"sort_order" => 900})
    assert first.sort_order == 1
    assert card().sort_order == 2

    attrs = %{
      concept: "order.import",
      albanian: "Synthetic ordered import",
      english: "Synthetic ordered meaning",
      category: "fixtures",
      subcategory: "Batch",
      sort_order: 500
    }

    duplicate = Map.take(first, Card.fields())

    assert {:ok, %{added: 1, skipped: 1}} =
             Learning.import_json(Jason.encode!(%{cards: [duplicate, attrs]}))

    assert Enum.map(Learning.list_cards(), & &1.sort_order) == [1, 2, 3]
    assert List.last(Learning.list_cards()).subcategory == "Batch"

    invalid =
      Map.merge(attrs, %{
        concept: "order.rollback",
        albanian: "Rollback synthetic",
        english: "Rollback meaning"
      })

    assert {:error, {:invalid_row, 2}} =
             Learning.import_json(Jason.encode!(%{cards: [invalid, %{}]}))

    assert card().sort_order == 4
  end

  test "swaps preserve content revisions, reviews, practice, print counts and timestamps" do
    first = card()
    second = card()
    {:ok, reviewed} = Learning.decide(second.id, second.revision, "reviewed", "Software fixture")

    assert {:ok, :recorded} =
             Learning.grade(second.id, second.revision, "remembered", "order-practice")

    Printing.record_download([second])
    before = Learning.get_card!(second.id)
    progress = Repo.all(Progress)
    reviews = Repo.all(Review)
    events = Repo.all(ContentEvent)
    token = Printing.selection_token([reviewed, first])

    assert {:ok, moved} = Learning.move_card(second.id, "up", 2, first.id)
    assert moved.sort_order == 1

    assert Map.delete(Map.from_struct(moved), :sort_order) ==
             Map.delete(Map.from_struct(before), :sort_order)

    assert Learning.get_card!(first.id).sort_order == 2
    assert Repo.all(Progress) == progress
    assert Repo.all(Review) == reviews
    assert Repo.all(ContentEvent) == events
    assert {:ok, printed} = Printing.selected_cards(token)
    assert Enum.map(printed, & &1.id) == [second.id, first.id]

    assert {:ok, _} = Learning.move_card(second.id, "down", 1, first.id)
    assert Enum.map(Learning.list_cards(), & &1.id) == [first.id, second.id]
  end

  test "boundary and stale moves do nothing, including when the adjacent card changed" do
    [first, second, third] = for _ <- 1..3, do: card()
    assert {:error, :stale_order} = Learning.move_card(first.id, "up", 1, "")
    assert {:error, :stale_order} = Learning.move_card(third.id, "down", 3, "")
    assert {:ok, _} = Learning.move_card(first.id, "down", 1, second.id)
    assert {:error, :stale_order} = Learning.move_card(first.id, "down", 1, second.id)
    assert {:error, :stale_order} = Learning.move_card(third.id, "up", 3, second.id)
    assert Enum.map(Learning.list_cards(), & &1.id) == [second.id, first.id, third.id]
  end

  test "single and bulk deletion compact gaps, preserve surviving data, and empty collections restart at one" do
    [a, b, c, d, e] = for _ <- 1..5, do: card(%{"image" => "apple"})

    for item <- [b, c] do
      assert {:ok, :recorded} = Learning.grade(item.id, 1, "remembered", "delete-#{item.id}")
    end

    progress = Repo.get_by!(Progress, card_id: c.id)
    assert {:ok, 2} = Learning.delete_cards([b, d])

    assert Enum.map(Learning.list_cards(), &{&1.id, &1.sort_order}) == [
             {a.id, 1},
             {c.id, 2},
             {e.id, 3}
           ]

    assert Repo.get_by!(Progress, card_id: c.id) == progress

    for schema <- [CardKey, ContentEvent, Progress, Review] do
      refute Repo.exists?(from row in schema, where: row.card_id in ^[b.id, d.id])
    end

    assert {:ok, 1} = Learning.delete_cards([a])
    assert Enum.map(Learning.list_cards(), & &1.sort_order) == [1, 2]
    assert card().sort_order == 3
    assert File.exists?(Application.app_dir(:albo, "priv/static/images/cards/apple.svg"))
    assert {:ok, 3} = Learning.delete_cards(Learning.list_cards())
    assert Learning.list_cards() == []
    assert card().sort_order == 1
    assert {:ok, %{rows: []}} = Repo.query("PRAGMA foreign_key_check")
  end

  test "stale bulk deletion rolls back the whole selection and archive retains its position" do
    first = card()
    second = card()
    {:ok, _} = Learning.save_card(second, %{"english" => "Changed synthetic meaning"}, 1)
    assert {:error, :stale} = Learning.delete_cards([first, second])
    assert length(Learning.list_cards()) == 2
    assert {:ok, archived} = Learning.decide(first.id, 1, "archived")
    assert archived.sort_order == 1
    assert card().sort_order == 3
    assert {:ok, restored} = Learning.decide(first.id, 1, "active")
    assert restored.sort_order == 1
  end

  test "database rejects duplicate, zero, negative and missing positions" do
    first = card()
    second = card()

    for position <- [0, -1, nil, first.sort_order] do
      assert {:error, _} =
               Repo.query("UPDATE cards SET sort_order = ? WHERE id = ?", [position, second.id])
    end

    assert Learning.get_card!(second.id).sort_order == 2
  end

  test "group labels are reused within their topic, blank subtopics clear, and exports preserve sequence" do
    first = card(%{"category" => "Food", "subcategory" => "Fruit"})
    second = card(%{"category" => " food ", "subcategory" => " fruit "})
    other = card(%{"category" => "Home", "subcategory" => "fruit"})
    assert {second.category, second.subcategory} == {"Food", "Fruit"}
    assert other.subcategory == "fruit"
    assert {:ok, cleared} = Learning.save_card(second, %{"subcategory" => ""}, 1)
    assert cleared.subcategory == ""
    assert {:ok, _} = Learning.move_card(other.id, "up", 3, second.id)
    exported = Jason.decode!(Learning.export_json())["cards"]
    assert Enum.map(exported, & &1["id"]) == [first.id, other.id, second.id]
    assert Enum.map(exported, & &1["sort_order"]) == [1, 2, 3]
    assert hd(exported)["subcategory"] == "Fruit"
  end

  test "all sorts have stable manual ties, blank subtopics stay last in both directions" do
    a =
      card(%{
        "category" => "Food",
        "subcategory" => "B",
        "difficulty" => "growing",
        "albanian" => "Zulu synthetic",
        "english" => "Alpha synthetic"
      })

    b =
      card(%{
        "category" => "Home",
        "subcategory" => "A",
        "albanian" => "Alpha synthetic",
        "english" => "Zulu synthetic"
      })

    c = card(%{"category" => "Food", "subcategory" => "A"})
    d = card(%{"category" => "Food"})
    cards = [d, c, b, a]
    assert ids(CardOrder.sort(cards)) == ids([a, b, c, d])
    assert ids(CardOrder.sort(cards, "topic")) == ids([c, a, d, b])
    assert ids(CardOrder.sort(cards, "subtopic")) == ids([c, b, a, d])
    assert ids(CardOrder.sort(cards, "subtopic", "desc")) == ids([a, b, c, d])
    assert ids(CardOrder.sort(cards, "level")) == ids([b, c, d, a])
    assert hd(CardOrder.sort(cards, "albanian")).id == b.id
    assert hd(CardOrder.sort(cards, "english")).id == a.id
    assert ids(CardOrder.sort(cards, "invalid")) == ids([a, b, c, d])
    assert Learning.get_card!(a.id).sort_order == 1
  end

  test "signed selections preserve arbitrary order and reject duplicates and malformed payloads" do
    a = card()
    b = card()
    c = card()
    assert {:ok, selected} = Printing.selected_cards(Printing.selection_token([c, a, b]))
    assert ids(selected) == ids([c, a, b])
    assert {:error, _} = Printing.selected_cards(Printing.selection_token([a, a]))
    token = Phoenix.Token.sign(AlboWeb.Endpoint, "physical-flashcards", ["invalid"])
    assert {:error, _} = Printing.selected_cards(token)
  end

  test "blank topics return validation errors and edits to deleted cards are stale" do
    first = card()
    assert {:error, %Ecto.Changeset{}} = Learning.save_card(first, %{"category" => ""}, 1)
    assert {:ok, 1} = Learning.delete_cards([first])
    assert {:error, :stale} = Learning.save_card(first, %{"english" => "Stale synthetic edit"}, 1)
    assert {:error, :stale} = Learning.save_quality_check(first.id, %{"quality_notes" => "Stale"})
    assert {:error, :stale} = Learning.decide(first.id, 1, "archived")
    assert {:error, :stale} = Learning.grade(first.id, 1, "remembered", "deleted-card")
  end

  defp ids(cards), do: Enum.map(cards, & &1.id)
end
