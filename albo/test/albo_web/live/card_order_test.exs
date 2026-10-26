defmodule AlboWeb.CardOrderTest do
  use AlboWeb.ConnCase
  import Phoenix.LiveViewTest
  import Albo.Fixtures
  alias Albo.{Learning, Printing}

  test "columns, arrows, URL sorting and guarded moves work for both roles", %{conn: conn} do
    a = card(%{"category" => "Zulu", "subcategory" => "One"})
    b = card(%{"category" => "Alpha", "subcategory" => "Two"})

    for role <- ["learner", "parent"] do
      {:ok, view, _} = live(login(conn, role), "/cards")
      assert row_ids(view) == ["cards-#{a.id}", "cards-#{b.id}"]
      assert has_element?(view, "#move-up-#{a.id}[disabled]")
      assert has_element?(view, "#move-down-#{b.id}[disabled]")
      view |> element("#move-up-#{b.id}") |> render_click()
      assert row_ids(view) == ["cards-#{b.id}", "cards-#{a.id}"]
      view |> element("#move-down-#{b.id}") |> render_click()
      view |> element("#sort-topic") |> render_click()
      assert_patch(view, "/cards?direction=asc&sort=topic")
      assert row_ids(view) == ["cards-#{b.id}", "cards-#{a.id}"]
      assert has_element?(view, "th[aria-sort=ascending] #sort-topic")
      assert has_element?(view, "#move-down-#{a.id}[disabled]")
      assert Learning.get_card!(a.id).sort_order == 1
      view |> element("#sort-topic") |> render_click()
      assert row_ids(view) == ["cards-#{a.id}", "cards-#{b.id}"]
      view |> element("#sort-order") |> render_click()
      view |> form("#card-filters", filters: %{search: "Zulu", status: "all"}) |> render_change()
      assert has_element?(view, "#move-down-#{a.id}[disabled]")

      render_click(view, "move", %{
        "id" => to_string(a.id),
        "direction" => "down",
        "position" => "1",
        "neighbor" => to_string(b.id)
      })

      assert Learning.get_card!(a.id).sort_order == 1
    end
  end

  test "new subtopics can be saved, suggested within their topic, searched and sorted", %{
    conn: conn
  } do
    food = card(%{"category" => "Food", "subcategory" => "Fruit"})
    card(%{"category" => "Home", "subcategory" => "Rooms"})
    {:ok, view, _} = live(login(conn, "parent"), "/cards")
    view |> element("#edit-#{food.id}") |> render_click()
    assert has_element?(view, "#card_subcategory[value=Fruit]")
    assert has_element?(view, "#subtopic-suggestions option[value=Fruit]")
    refute has_element?(view, "#subtopic-suggestions option[value=Rooms]")
    view |> form("#card-form", card: %{subcategory: "Vegetables"}) |> render_submit()
    assert Learning.get_card!(food.id).subcategory == "Vegetables"

    view
    |> form("#card-filters", filters: %{search: "Vegetables", status: "all"})
    |> render_change()

    assert row_ids(view) == ["cards-#{food.id}"]
    view |> element("#sort-subtopic") |> render_click()
    assert has_element?(view, "th[aria-sort=ascending] #sort-subtopic")
  end

  test "print preview and signed download follow the active sort across hidden selections", %{
    conn: conn
  } do
    a =
      card(%{
        "albanian" => "Zulu synthetic",
        "english" => "Alpha synthetic",
        "category" => "Food"
      })

    b =
      card(%{
        "albanian" => "Alpha synthetic",
        "english" => "Zulu synthetic",
        "category" => "Home"
      })

    {:ok, view, _} = live(login(conn, "learner"), "/cards")
    view |> element("#select-visible") |> render_click()
    view |> element("#sort-albanian") |> render_click()
    view |> form("#card-filters", filters: %{search: "Food", status: "all"}) |> render_change()
    view |> element("#print-open") |> render_click()
    assert preview_ids(view) == [to_string(b.id), to_string(a.id)]
    assert {:ok, cards} = Printing.selected_cards(print_token(view))
    assert Enum.map(cards, & &1.id) == [b.id, a.id]
    view |> element("#close-print") |> render_click()
    view |> element("#sort-english") |> render_click()
    view |> element("#print-open") |> render_click()
    assert preview_ids(view) == [to_string(a.id), to_string(b.id)]
    assert {:ok, cards} = Printing.selected_cards(print_token(view))
    assert Enum.map(cards, & &1.id) == [a.id, b.id]
  end

  test "bulk deletion requires confirmation, keeps hidden selections visible, and compacts positions",
       %{conn: conn} do
    a = card(%{"category" => "Food"})
    b = card(%{"category" => "Home"})
    c = card(%{"category" => "Food"})
    {:ok, view, _} = live(login(conn, "parent"), "/cards")
    view |> element("#print-select-#{a.id}") |> render_click()
    view |> element("#print-select-#{c.id}") |> render_click()
    view |> form("#card-filters", filters: %{search: "Home", status: "all"}) |> render_change()
    view |> element("#delete-selected") |> render_click()
    assert has_element?(view, "#delete-title", "Delete 2 cards?")
    assert has_element?(view, "#delete-preview", a.english)
    assert has_element?(view, "#delete-preview", c.english)
    view |> element("#cancel-delete") |> render_click()
    assert length(Learning.list_cards()) == 3
    view |> element("#delete-selected") |> render_click()
    view |> element("#confirm-delete") |> render_click()
    refute has_element?(view, "#delete-modal")
    assert has_element?(view, "#order-#{b.id}", "1")
    assert has_element?(view, "#print-selected-count", "0 selected")
    assert [remaining] = Learning.list_cards()
    assert remaining.id == b.id
  end

  test "another open studio refreshes positions and deletion also removes staged quality drafts",
       %{conn: conn} do
    a = card()
    b = card()
    {:ok, first, _} = live(login(conn, "parent"), "/cards")
    {:ok, second, _} = live(login(conn, "learner"), "/cards")
    first |> element("#move-up-#{b.id}") |> render_click()
    assert has_element?(second, "#order-#{b.id}", "1")

    second
    |> form("#quality-form-#{a.id}", quality: %{quality_notes: "Unsaved synthetic draft"})
    |> render_change()

    assert {:ok, 1} = Learning.delete_cards([a])
    refute has_element?(second, "#quality-form-#{a.id}")
    assert has_element?(second, "#quality-save-all[disabled]")

    render_click(second, "change-quality", %{
      "id" => to_string(a.id),
      "quality" => %{"quality_notes" => "Stale draft"}
    })

    render_click(second, "edit", %{"id" => to_string(a.id)})
    refute has_element?(second, "#card-modal")
  end

  test "archived cards can be deleted individually through the editor", %{conn: conn} do
    a = card()
    {:ok, _} = Learning.decide(a.id, 1, "archived")
    {:ok, view, _} = live(login(conn, "parent"), "/cards")
    view |> element("#edit-#{a.id}") |> render_click()
    view |> element("#delete-card") |> render_click()
    view |> element("#confirm-delete") |> render_click()
    assert Learning.list_cards() == []
    assert has_element?(view, "#cards-empty")
  end

  defp row_ids(view),
    do:
      view
      |> render()
      |> LazyHTML.from_fragment()
      |> LazyHTML.query("#vocabulary tr")
      |> LazyHTML.attribute("id")

  defp preview_ids(view),
    do:
      view
      |> render()
      |> LazyHTML.from_fragment()
      |> LazyHTML.query("#print-preview-cards li")
      |> LazyHTML.attribute("data-card-id")

  defp print_token(view),
    do:
      view
      |> render()
      |> LazyHTML.from_fragment()
      |> LazyHTML.query("#print-download-form input[name=selection]")
      |> LazyHTML.attribute("value")
      |> hd()
end
