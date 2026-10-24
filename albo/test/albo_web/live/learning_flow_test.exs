defmodule AlboWeb.LearningFlowTest do
  use AlboWeb.ConnCase
  import Phoenix.LiveViewTest
  import Albo.Fixtures
  alias Albo.Learning

  test "both roles have the same studio and export access; entry still creates a session", %{
    conn: conn
  } do
    assert redirected_to(get(conn, "/")) == "/login"
    assert redirected_to(get(conn, "/cards/export")) == "/login"

    for role <- ["learner", "parent"] do
      signed = login(conn, role)
      assert get(signed, "/cards/export").status == 200
      assert get(signed, "/parent/export").status == 200
      {:ok, studio, _} = live(signed, "/cards")
      assert has_element?(studio, "#new-card")
      assert has_element?(studio, "#import-open")
      {:ok, legacy, _} = live(signed, "/parent")
      assert has_element?(legacy, "#new-card")
    end
  end

  test "learner sees new cards immediately and an add-cards link for an empty collection", %{
    conn: conn
  } do
    {:ok, empty, _} = live(login(conn, "learner"), "/")
    assert has_element?(empty, "#no-cards a[href='/cards']")
    card()
    {:ok, view, _} = live(login(conn, "learner"), "/")
    refute has_element?(view, "#no-cards")
    assert has_element?(view, "#topics a")
    assert has_element?(view, "nav a[href='/cards']")
    {:ok, practice, _} = live(login(conn, "learner"), "/practice")
    assert has_element?(practice, "#practice-card")
  end

  test "reveal, grade, and resume avoid duplicate progress", %{conn: conn} do
    card = card()
    {:ok, view, _} = live(login(conn, "learner"), "/practice?mode=daily")
    assert has_element?(view, "#reveal-card")
    refute has_element?(view, "#grade-remembered")
    view |> element("#reveal-card") |> render_click()
    assert has_element?(view, "#card-word[lang=sq]", card.albanian)
    view |> element("#flip-back") |> render_click()
    assert has_element?(view, "#card-word[lang=en]", card.english)
    view |> element("#reveal-card") |> render_click()
    view |> element("#grade-remembered") |> render_click()
    assert has_element?(view, "#session-complete")
    assert Learning.stats().practiced == 1
    {:ok, fresh, _} = live(login(conn, "learner"), "/practice?mode=daily")
    assert has_element?(fresh, "#session-complete")
  end

  test "all topics contains every active card, even after the daily limit and previous practice",
       %{conn: conn} do
    cards = for n <- 1..7, do: card(%{"category" => if(n <= 4, do: "food", else: "home")})
    archived = card()
    {:ok, _} = Learning.decide(archived.id, 1, "archived")

    for card <- Enum.take(cards, 3),
        do: Learning.grade(card.id, 1, "remembered", "daily-#{card.id}")

    assert Learning.session() == []
    {:ok, view, _} = live(login(conn, "learner"), "/practice")

    for {card, index} <- Enum.with_index(cards, 1) do
      assert has_element?(view, "#card-counter", "Card #{index} of 7")
      assert has_element?(view, "#card-word", card.english)
      view |> element("#next-card") |> render_click()
    end

    assert has_element?(view, "#session-complete")
    view |> element("#restart-cards") |> render_click()
    assert has_element?(view, "#card-counter", "Card 1 of 7")

    for _card <- cards do
      view |> element("#reveal-card") |> render_click()
      view |> element("#grade-remembered") |> render_click()
    end

    assert has_element?(view, "#session-complete")
    assert Learning.stats().practiced == 7
    {:ok, food, _} = live(login(conn, "learner"), "/practice?topic=food")
    assert has_element?(food, "#card-counter", "Card 1 of 4")
    assert has_element?(food, "#show-all-cards")
  end

  test "next card skips without recording answers and ignores duplicate clicks", %{conn: conn} do
    first = card()
    second = card()
    {:ok, view, _} = live(login(conn, "learner"), "/practice")
    assert has_element?(view, "#card-word", first.english)
    view |> element("#reveal-card") |> render_click()

    attempt =
      render(view)
      |> LazyHTML.from_fragment()
      |> LazyHTML.query("#next-card")
      |> LazyHTML.attribute("phx-value-attempt")
      |> hd()

    view |> element("#next-card") |> render_click()
    assert has_element?(view, "#card-word[lang=en]", second.english)
    assert has_element?(view, "#card-counter", "Card 2 of 2")
    render_click(view, "next", %{"attempt" => attempt})
    assert has_element?(view, "#card-word", second.english)
    assert Learning.stats().practiced == 0
    view |> element("#next-card") |> render_click()
    assert has_element?(view, "#session-complete")
    assert length(Learning.session()) == 2
  end

  for role <- ["learner", "parent"] do
    test "#{role} can edit, review optionally, archive, restore, and create without an internal key",
         %{conn: conn} do
      card = card()
      {:ok, view, _} = live(login(conn, unquote(role)), "/cards")
      view |> element("#edit-#{card.id}") |> render_click()
      assert has_element?(view, "#card-form")

      view
      |> form("#card-form", card: %{albanian: "Edited synthetic translation"})
      |> render_change()

      view
      |> form("#card-form", card: %{albanian: "Edited synthetic translation"})
      |> render_submit()

      edited = Learning.get_card!(card.id)
      assert edited.albanian == "Edited synthetic translation"
      assert edited.status == "active"
      assert edited.revision == 2
      assert has_element?(view, "#vocabulary", edited.albanian)
      view |> element("#edit-#{card.id}") |> render_click()

      view
      |> form("#review-form", review: %{reviewer: "Software test fixture"})
      |> render_submit()

      assert Learning.get_card!(card.id).reviewer == "Software test fixture"
      view |> element("#archive-card") |> render_click()
      assert Learning.get_card!(card.id).status == "archived"
      view |> element("#edit-#{card.id}") |> render_click()
      view |> element("#archive-card") |> render_click()
      assert Learning.get_card!(card.id).status == "active"
      view |> element("#new-card") |> render_click()

      view
      |> form("#card-form",
        card: %{
          albanian: "Added synthetic word",
          english: "Added synthetic meaning",
          category: "fixtures"
        }
      )
      |> render_submit()

      assert length(Learning.list_cards()) == 2
      added = Enum.find(Learning.list_cards(), &(&1.id != card.id))
      assert added.status == "active"
      assert String.starts_with?(added.concept, "card.")
    end
  end

  test "learner imports are immediately available; duplicates do not overwrite edits", %{
    conn: conn
  } do
    existing = card()
    learner = login(conn, "learner")
    {:ok, view, _} = live(learner, "/cards")
    view |> element("#import-open") |> render_click()

    json =
      Jason.encode!(%{
        cards: [
          Map.take(existing, Albo.Learning.Card.fields()),
          %{
            concept: "fixture.imported",
            albanian: "Imported synthetic word",
            english: "Imported synthetic meaning",
            category: "imported"
          }
        ]
      })

    view |> form("#import-form", import: %{json: json}) |> render_submit()
    refute has_element?(view, "#import-modal")
    assert length(Learning.list_cards()) == 2
    assert [_] = Learning.session("imported")
    response = get(learner, "/cards/export")
    assert get_resp_header(response, "content-disposition") |> hd() =~ "attachment"
    assert Jason.decode!(response.resp_body)["cards"] |> length() == 2
  end

  test "invalid edits show feedback and preserve saved wording", %{conn: conn} do
    card = card()
    {:ok, view, _} = live(login(conn, "learner"), "/cards")
    view |> element("#edit-#{card.id}") |> render_click()
    view |> form("#card-form", card: %{albanian: ""}) |> render_submit()
    assert has_element?(view, "#card-modal .field-error")
    assert Learning.get_card!(card.id).albanian == card.albanian
  end
end
