defmodule AlboWeb.PrintLiveTest do
  use AlboWeb.ConnCase
  import Phoenix.LiveViewTest
  import Albo.Fixtures
  alias Albo.{Learning, Printing}

  test "printing requires login for the page and download", %{conn: conn} do
    assert redirected_to(get(conn, "/cards/print")) == "/login"
    assert redirected_to(post(conn, "/cards/print/pdf", %{})) == "/login"
  end

  test "old print links open Card studio", %{conn: conn} do
    assert redirected_to(get(login(conn, "learner"), "/cards/print")) == "/cards"
  end

  test "empty state allows calibration, while selected cards are required for download", %{
    conn: conn
  } do
    {:ok, view, _} = live(login(conn, "learner"), "/cards")
    assert has_element?(view, "#cards-empty")
    view |> element("#print-open") |> render_click()
    assert has_element?(view, "#print-empty")
    assert has_element?(view, "#download-cards[disabled]")
    refute has_element?(view, "#download-calibration[disabled]")
  end

  test "selection persists across filters, excludes archives, and updates the print summary", %{
    conn: conn
  } do
    first = card(%{"category" => "food", "image" => "apple"})
    second = card(%{"category" => "home"})
    archived = card()
    {:ok, _} = Learning.decide(archived.id, 1, "archived")
    {:ok, view, _} = live(login(conn, "parent"), "/cards")
    assert has_element?(view, "nav a.active[href='/cards']")
    refute has_element?(view, "nav a[href='/cards/print']")
    assert has_element?(view, "#print-select-#{archived.id}[disabled]")
    view |> element("#print-select-#{first.id}") |> render_click()
    assert has_element?(view, "#print-select-#{first.id}[checked]")
    view |> form("#card-filters", filters: %{search: "home", status: "all"}) |> render_change()
    refute has_element?(view, "#cards-#{first.id}")
    assert has_element?(view, "#print-selected-count", "1 selected")
    view |> element("#select-visible") |> render_click()
    assert has_element?(view, "#print-select-#{second.id}[checked]")
    assert has_element?(view, "#print-selected-count", "2 selected")
    view |> form("#card-filters", filters: %{search: "", status: "all"}) |> render_change()
    assert has_element?(view, "#print-select-#{first.id}[checked]")
    clear_print_selection(view)
    view |> element("#print-open") |> render_click()
    assert has_element?(view, "#download-cards[disabled]")
  end

  test "sheet count follows layout settings and the master checkbox toggles selection", %{
    conn: conn
  } do
    for _ <- 1..9, do: card()
    {:ok, view, _} = live(login(conn, "learner"), "/cards")
    view |> element("#select-visible") |> render_click()
    view |> element("#print-open") |> render_click()
    assert has_element?(view, "#print-page-count", "2 sheets · 4 PDF pages")
    view |> element("#print_per_sheet") |> render_change(%{"print" => %{"per_sheet" => "10"}})
    assert has_element?(view, "#print-page-count", "1 sheet · 2 PDF pages")
    view |> element("#close-print") |> render_click()
    view |> element("#select-visible") |> render_click()
    assert has_element?(view, "#print-selected-count", "0 selected")
    view |> element("#select-visible") |> render_click()
    assert has_element?(view, "#print-selected-count", "9 selected")
  end

  test "both roles download a real PDF without modifying wording or progress", %{conn: conn} do
    card = card(%{"albanian" => "Synthetic ë ç", "image" => "apple"})

    for role <- ["learner", "parent"] do
      response =
        post(login(conn, role), "/cards/print/pdf", %{
          "selection" => Printing.selection_token([card])
        })

      assert response.status == 200
      assert get_resp_header(response, "content-type") == ["application/pdf"]

      assert get_resp_header(response, "content-disposition") |> hd() =~
               "alboteach-flashcards.pdf"

      assert String.starts_with?(response.resp_body, "%PDF-")
    end

    assert Learning.get_card!(card.id) == %{card | print_count: 2}
    assert Learning.stats().practiced == 0
  end

  test "created cards can be selected, edited, and printed in the same studio; archiving clears selection",
       %{conn: conn} do
    {:ok, view, _} = live(login(conn, "learner"), "/cards")
    view |> element("#new-card") |> render_click()

    view
    |> form("#card-form",
      card: %{
        albanian: "Synthetic studio card",
        english: "Synthetic printable card",
        category: "fixtures"
      }
    )
    |> render_submit()

    [created] = Learning.list_cards()
    view |> element("#print-select-#{created.id}") |> render_click()
    view |> element("#edit-#{created.id}") |> render_click()

    view
    |> form("#card-form", card: %{english: "Updated synthetic print wording"})
    |> render_submit()

    assert has_element?(view, "#print-select-#{created.id}[checked]")
    view |> element("#print-open") |> render_click()

    token =
      render(view)
      |> LazyHTML.from_fragment()
      |> LazyHTML.query("#print-download-form input[name=selection]")
      |> LazyHTML.attribute("value")
      |> hd()

    assert {:ok, [selected]} = Printing.selected_cards(token)
    assert selected.english == "Updated synthetic print wording"
    assert selected.revision == 2
    view |> element("#close-print") |> render_click()
    view |> element("#edit-#{created.id}") |> render_click()
    view |> element("#archive-card") |> render_click()
    assert has_element?(view, "#print-selected-count", "0 selected")
    assert has_element?(view, "#print-select-#{created.id}[disabled]")
    refute has_element?(view, "#print-select-#{created.id}[checked]")
  end

  test "bad or stale selections and invalid settings produce a recoverable error", %{conn: conn} do
    card = card()
    signed = login(conn, "learner")
    token = Printing.selection_token([card])
    {:ok, saved} = Learning.save_card(card, %{"english" => "Changed synthetic wording"}, 1)
    assert {:error, _} = Printing.selected_cards(token)
    {:ok, _} = Learning.decide(saved.id, saved.revision, "archived")
    assert {:error, _} = Printing.selected_cards(Printing.selection_token([saved]))

    for params <- [
          %{},
          %{"selection" => "tampered"},
          %{"selection" => token},
          %{"kind" => "calibration", "print" => %{"back_x_mm" => "6"}}
        ] do
      response = post(signed, "/cards/print/pdf", params)
      assert redirected_to(response) == "/cards"
      assert Phoenix.Flash.get(response.assigns.flash, :error)
    end
  end

  test "calibration works with no selected cards and chosen layout", %{conn: conn} do
    response =
      post(login(conn, "parent"), "/cards/print/pdf", %{
        "kind" => "calibration",
        "print" => %{"per_sheet" => "10", "flip" => "short-edge", "back_x_mm" => "0.5"}
      })

    assert response.status == 200
    assert String.starts_with?(response.resp_body, "%PDF-")
    assert get_resp_header(response, "content-disposition") |> hd() =~ "calibration.pdf"
  end

  test "3 by 7 layout fits 21 cards per sheet and can download cards and calibration", %{
    conn: conn
  } do
    cards = for _ <- 1..22, do: card()
    signed = login(conn, "learner")
    {:ok, view, _} = live(signed, "/cards")
    view |> element("#select-visible") |> render_click()
    view |> element("#print-open") |> render_click()
    view |> element("#print_per_sheet") |> render_change(%{"print" => %{"per_sheet" => "21"}})
    assert has_element?(view, "#print-page-count", "2 sheets · 4 PDF pages")

    for kind <- ["cards", "calibration"] do
      response =
        post(signed, "/cards/print/pdf", %{
          "selection" => Printing.selection_token(cards),
          "kind" => kind,
          "print" => %{"per_sheet" => "21"}
        })

      assert response.status == 200
      assert String.starts_with?(response.resp_body, "%PDF-")
    end

    assert Learning.get_card!(hd(cards).id).print_count == 1
  end

  test "picture side is selectable, preserved across settings changes, and validated on download",
       %{conn: conn} do
    card = card(%{"image" => "apple"})
    signed = login(conn, "learner")
    {:ok, view, _} = live(signed, "/cards")
    view |> element("#print-open") |> render_click()
    assert has_element?(view, "#print_image_side option[value=albanian][selected]")

    view
    |> element("#print_image_side")
    |> render_change(%{"print" => %{"image_side" => "english"}})

    view |> element("#print_per_sheet") |> render_change(%{"print" => %{"per_sheet" => "21"}})
    view |> element("#close-print") |> render_click()
    view |> element("#print-open") |> render_click()
    assert has_element?(view, "#print_image_side option[value=english][selected]")

    response =
      post(signed, "/cards/print/pdf", %{
        "selection" => Printing.selection_token([card]),
        "print" => %{"image_side" => "english"}
      })

    assert response.status == 200

    invalid =
      post(signed, "/cards/print/pdf", %{
        "selection" => Printing.selection_token([card]),
        "print" => %{"image_side" => "both"}
      })

    assert redirected_to(invalid) == "/cards"
    assert Learning.get_card!(card.id).print_count == 1
  end
end
