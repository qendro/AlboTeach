defmodule Albo.LearningTest do
  use Albo.DataCase
  import Albo.Fixtures
  alias Albo.{Learning, Repo}
  alias Albo.Learning.{Card, Progress, Review, ContentEvent}

  test "cards are immediately available; optional review is separate; edits retain historical keys" do
    card = card()
    assert card.status == "active"
    assert [^card] = Learning.session()
    assert {:error, :reviewer_required} = Learning.decide(card.id, 1, "reviewed", "")
    assert {:ok, reviewed} = Learning.decide(card.id, 1, "reviewed", "Software test fixture")
    assert [^reviewed] = Learning.session()

    assert {:ok, edited} =
             Learning.save_card(reviewed, %{"albanian" => "Corrected synthetic wording"}, 1)

    assert edited.status == "active"
    assert edited.reviewer == nil
    assert edited.revision == 2
    assert [^edited] = Learning.session()
    assert {:error, :stale} = Learning.decide(card.id, 1, "reviewed", "Software test fixture")
    assert {:error, :stale} = Learning.save_card(reviewed, %{"english" => "Stale edit"}, 1)

    assert {:error, :duplicate} =
             Learning.save_card(
               %Card{},
               %{
                 "concept" => "fixture.old",
                 "albanian" => card.albanian,
                 "english" => "Other synthetic meaning",
                 "category" => "fixtures"
               },
               1
             )

    assert Repo.aggregate(ContentEvent, :count) == 3
  end

  test "JSON imports preserve existing content, ignore approval fields, skip duplicates, and are atomic" do
    card = card()

    json =
      Jason.encode!(%{
        cards: [
          Map.take(card, Card.fields()) |> Map.put(:status, "approved"),
          %{
            concept: "fixture.new",
            albanian: "New synthetic word",
            english: "New synthetic meaning",
            category: "fixtures",
            status: "approved",
            reviewer: "Forged"
          }
        ]
      })

    assert {:ok, %{added: 1, skipped: 1}} = Learning.import_json(json)
    imported = Repo.get_by!(Card, concept: "fixture.new")
    assert imported.status == "active"
    assert imported.reviewer == nil
    assert Learning.get_card!(card.id).status == "active"

    bad =
      Jason.encode!(%{
        cards: [
          %{
            concept: "fixture.atomic",
            albanian: "Atomic synthetic word",
            english: "Atomic synthetic meaning",
            category: "fixtures"
          },
          %{concept: "missing"}
        ]
      })

    assert {:error, {:invalid_row, 2}} = Learning.import_json(bad)
    refute Repo.get_by(Card, concept: "fixture.atomic")
    assert {:error, :invalid_json} = Learning.import_json("[]")
    assert {:error, :invalid_json} = Learning.import_json(String.duplicate("x", 200_001))
  end

  test "daily cap, due ordering, no immediate repeats, and idempotent reviews" do
    cards = for _ <- 1..5, do: card()
    now = ~U[2026-10-24 12:00:00Z]
    assert length(Learning.session("all", "all", now)) == 3

    for card <- Enum.take(cards, 3) do
      assert {:ok, :recorded} = Learning.grade(card.id, 1, "remembered", "first-#{card.id}", now)
    end

    assert Learning.session("all", "all", now) == []
    first = hd(cards)

    assert {:error, :already_recorded} =
             Learning.grade(first.id, 1, "remembered", "first-#{first.id}", now)

    assert {:error, :not_due} = Learning.grade(first.id, 1, "remembered", "different-tab", now)
    fourth = Enum.at(cards, 3)
    assert {:error, :daily_limit} = Learning.grade(fourth.id, 1, "again", "fourth", now)
    assert Repo.aggregate(Review, :count) == 3
    assert Learning.stats(now).practiced == 3
    tomorrow = DateTime.add(now, 86_400)
    assert length(Learning.session("all", "all", tomorrow)) == 5
    assert {:ok, :recorded} = Learning.grade(first.id, 1, "remembered", "tomorrow", tomorrow)
    assert Repo.get_by!(Progress, card_id: first.id).streak == 2
    assert Learning.stats(tomorrow).learned == 1
  end

  test "still learning returns after ten minutes; an archived or revised card cannot be graded" do
    card = card()
    now = ~U[2026-10-24 12:00:00Z]
    assert {:ok, :recorded} = Learning.grade(card.id, 1, "again", "again", now)
    assert Learning.session("all", "all", DateTime.add(now, 599)) == []
    assert [^card] = Learning.session("all", "all", DateTime.add(now, 600))
    {:ok, _} = Learning.decide(card.id, 1, "archived", "Software test fixture")

    assert {:error, :stale} =
             Learning.grade(card.id, 1, "remembered", "archived", DateTime.add(now, 700))
  end

  test "topic and difficulty filters; seed does not mark cards reviewed or duplicates a collection" do
    approved = card(%{"category" => "fixture-topic", "difficulty" => "growing"})
    assert Learning.session("fixture-topic", "beginner") == []
    assert [^approved] = Learning.session("fixture-topic", "growing")
    Learning.seed()
    assert length(Learning.list_cards()) == 1
    assert Jason.decode!(Learning.export_json())["schema_version"] == 1
  end

  test "fresh collection seeds exactly twelve available but unreviewed cards" do
    Learning.seed()
    Learning.seed()
    assert length(Learning.list_cards()) == 12
    assert Enum.all?(Learning.list_cards(), &(&1.status == "active" && &1.reviewer == nil))
    assert length(Learning.session()) == 3
    assert length(Learning.flashcards()) == 12
  end

  test "all-card practice accepts more than three new cards without inflating early recall streaks" do
    now = ~U[2026-10-24 12:00:00Z]
    cards = for _ <- 1..5, do: card()

    for card <- cards do
      assert {:ok, :recorded} =
               Learning.grade(card.id, 1, "remembered", "all-#{card.id}", now, :all)
    end

    assert length(Learning.flashcards()) == 5
    assert Learning.session("all", "all", now) == []
    first = hd(cards)
    original = Repo.get_by!(Progress, card_id: first.id)
    assert {:ok, :recorded} = Learning.grade(first.id, 1, "remembered", "repeat", now, :all)
    repeated = Repo.get_by!(Progress, card_id: first.id)
    assert repeated.streak == original.streak
    assert repeated.due_at == original.due_at
    assert repeated.reviews == original.reviews + 1
  end
end
