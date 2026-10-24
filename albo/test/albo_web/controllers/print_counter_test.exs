defmodule AlboWeb.PrintCounterTest do
  use AlboWeb.ConnCase
  import Albo.Fixtures
  alias Albo.{Learning, Printing}

  test "each PDF increments only included cards once, and counts survive edits and archive/restore",
       %{conn: conn} do
    first = card()
    second = card()
    untouched = card()
    signed = login(conn, "learner")

    assert post(signed, "/cards/print/pdf", %{
             "selection" => Printing.selection_token([first, second])
           }).status == 200

    assert post(signed, "/cards/print/pdf", %{"selection" => Printing.selection_token([first])}).status ==
             200

    assert Learning.get_card!(first.id).print_count == 2
    assert Learning.get_card!(second.id).print_count == 1
    assert Learning.get_card!(untouched.id).print_count == 0

    {:ok, saved} =
      Learning.save_card(
        first,
        %{"english" => "Edited synthetic printed card", "print_count" => 99},
        1
      )

    assert saved.print_count == 2
    {:ok, _} = Learning.decide(saved.id, saved.revision, "archived")
    {:ok, restored} = Learning.decide(saved.id, saved.revision, "active")
    assert restored.print_count == 2
    assert Learning.stats().practiced == 0
  end

  test "calibration, rejected selections, and rendering failures never increase counts", %{
    conn: conn
  } do
    card = card(%{"albanian" => "Unsupported 🫠 glyph"})
    signed = login(conn, "parent")
    token = Printing.selection_token([card])

    assert post(signed, "/cards/print/pdf", %{"selection" => token, "kind" => "calibration"}).status ==
             200

    for params <- [
          %{"selection" => token},
          %{"selection" => "bad token"},
          %{"selection" => token, "print" => %{"back_x_mm" => "99"}}
        ] do
      assert redirected_to(post(signed, "/cards/print/pdf", params)) == "/cards"
      assert Learning.get_card!(card.id).print_count == 0
    end
  end
end
