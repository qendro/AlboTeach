defmodule AlboWeb.PrintSelectionTest do
  use AlboWeb.ConnCase
  import Phoenix.LiveViewTest
  import Albo.Fixtures
  alias Albo.{Learning, Printing}

  test "the master checkbox toggles all and exposes a partial selection", %{conn: conn} do
    first = card()
    card()
    archived = card()
    {:ok, _} = Learning.decide(archived.id, 1, "archived")
    {:ok, view, _} = live(login(conn, "learner"), "/cards")
    assert has_element?(view, "#select-all-control[data-state=none]")
    view |> element("#print-select-#{first.id}") |> render_click()
    assert has_element?(view, "#select-all-control[data-state=mixed]")
    view |> element("#select-visible") |> render_click()
    assert has_element?(view, "#select-all-control[data-state=all]")
    assert has_element?(view, "#print-selected-count", "2 selected")
    refute has_element?(view, "#print-select-#{archived.id}[checked]")
    view |> element("#select-visible") |> render_click()
    assert has_element?(view, "#select-all-control[data-state=none]")
    assert has_element?(view, "#print-selected-count", "0 selected")
    refute has_element?(view, "#select-visible[checked]")
  end

  test "select new replaces selection with only visible unprinted active cards", %{conn: conn} do
    printed = card(%{"category" => "food"})
    fresh = card(%{"category" => "food"})
    other = card(%{"category" => "home"})
    archived = card(%{"category" => "food"})
    Printing.record_download([printed])
    {:ok, _} = Learning.decide(archived.id, 1, "archived")
    {:ok, view, _} = live(login(conn, "learner"), "/cards")
    assert has_element?(view, "#print-count-#{printed.id}[data-print-count='1']")
    view |> element("#select-visible") |> render_click()
    assert has_element?(view, "#print-selected-count", "3 selected")
    view |> element("#select-new") |> render_click()
    assert has_element?(view, "#print-selected-count", "2 selected")
    assert has_element?(view, "#print-select-#{fresh.id}[checked]")
    assert has_element?(view, "#print-select-#{other.id}[checked]")
    refute has_element?(view, "#print-select-#{printed.id}[checked]")
    refute has_element?(view, "#print-select-#{archived.id}[checked]")
    view |> form("#card-filters", filters: %{search: "home", status: "all"}) |> render_change()
    view |> element("#select-new") |> render_click()
    assert has_element?(view, "#print-selected-count", "1 selected")
    view |> form("#card-filters", filters: %{search: "", status: "all"}) |> render_change()
    refute has_element?(view, "#print-select-#{fresh.id}[checked]")
    clear_print_selection(view)
    assert has_element?(view, "#print-selected-count", "0 selected")
  end

  test "20-card mode selects forward in displayed order, skips archives, and stops at the end", %{
    conn: conn
  } do
    cards = for _ <- 1..25, do: card()
    archived = Enum.at(cards, 5)
    {:ok, _} = Learning.decide(archived.id, 1, "archived")
    active = Enum.reject(cards, &(&1.id == archived.id))
    {:ok, view, _} = live(login(conn, "parent"), "/cards")
    view |> element("#selection-size-20") |> render_click()
    start = Enum.at(active, 2)
    view |> element("#print-select-#{start.id}") |> render_click()
    assert has_element?(view, "#print-selected-count", "20 selected")

    for card <- Enum.slice(active, 2, 20),
        do: assert(has_element?(view, "#print-select-#{card.id}[checked]"))

    refute has_element?(view, "#print-select-#{hd(active).id}[checked]")
    refute has_element?(view, "#print-select-#{archived.id}[checked]")
    view |> element("#print-select-#{start.id}") |> render_click()
    assert has_element?(view, "#print-selected-count", "19 selected")
    clear_print_selection(view)
    near_end = Enum.at(active, -2)
    view |> element("#print-select-#{near_end.id}") |> render_click()
    assert has_element?(view, "#print-selected-count", "2 selected")
    view |> element("#selection-size-1") |> render_click()
    view |> element("#print-select-#{hd(active).id}") |> render_click()
    assert has_element?(view, "#print-selected-count", "3 selected")
  end

  test "Select new clears previously printed selections when no new cards remain", %{conn: conn} do
    card = card()
    Printing.record_download([card])
    {:ok, view, _} = live(login(conn, "learner"), "/cards")
    view |> element("#select-visible") |> render_click()
    assert has_element?(view, "#print-selected-count", "1 selected")
    view |> element("#select-new") |> render_click()
    assert has_element?(view, "#print-selected-count", "0 selected")
  end

  test "20-card mode never adds hidden cards and preserves earlier selections", %{conn: conn} do
    earlier = card(%{"category" => "earlier"})
    visible = for _ <- 1..22, do: card(%{"category" => "target"})
    hidden = card(%{"category" => "other"})
    {:ok, view, _} = live(login(conn, "learner"), "/cards")
    view |> element("#print-select-#{earlier.id}") |> render_click()
    view |> form("#card-filters", filters: %{search: "target", status: "all"}) |> render_change()
    view |> element("#selection-size-20") |> render_click()
    view |> element("#print-select-#{hd(visible).id}") |> render_click()
    assert has_element?(view, "#print-selected-count", "21 selected")
    view |> form("#card-filters", filters: %{search: "", status: "all"}) |> render_change()
    assert has_element?(view, "#print-select-#{earlier.id}[checked]")
    refute has_element?(view, "#print-select-#{hidden.id}[checked]")
  end

  test "PDF download updates counters live in every open studio and Select new uses the new counts",
       %{conn: conn} do
    printed = card()
    fresh = card()
    signed = login(conn, "learner")
    {:ok, first, _} = live(signed, "/cards")
    {:ok, second, _} = live(login(conn, "parent"), "/cards")
    first |> element("#print-select-#{printed.id}") |> render_click()

    response =
      post(signed, "/cards/print/pdf", %{"selection" => Printing.selection_token([printed])})

    assert response.status == 200

    for view <- [first, second],
        do: assert(has_element?(view, "#print-count-#{printed.id}[data-print-count='1']"))

    first |> element("#select-new") |> render_click()
    assert has_element?(first, "#print-selected-count", "1 selected")
    assert has_element?(first, "#print-select-#{fresh.id}[checked]")
    refute has_element?(first, "#print-select-#{printed.id}[checked]")
  end
end
