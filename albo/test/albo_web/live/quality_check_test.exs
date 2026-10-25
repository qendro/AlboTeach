defmodule AlboWeb.QualityCheckTest do
  use AlboWeb.ConnCase
  import Phoenix.LiveViewTest
  import Albo.Fixtures
  alias Albo.Learning

  test "quality flags and notes persist, export for an agent, and can be cleared", %{conn: conn} do
    card = card()
    signed = login(conn, "parent")
    {:ok, view, _} = live(signed, "/cards")

    assert has_element?(view, ".studio-table th", "Quality check")
    refute has_element?(view, ".studio-table th", "Status")

    view
    |> form("#quality-form-#{card.id}",
      quality: %{
        quality_language: "true",
        quality_image: "true",
        quality_delete: "true",
        quality_notes: "Use a more natural Prishtina phrase and a clearer picture."
      }
    )
    |> render_change()

    view |> element("#quality-save-all") |> render_click()

    saved = Learning.get_card!(card.id)
    assert saved.quality_language && saved.quality_image && saved.quality_delete
    assert saved.quality_notes == "Use a more natural Prishtina phrase and a clearer picture."
    assert saved.status == "active"
    assert saved.revision == card.revision
    assert saved.albanian == card.albanian

    exported = signed |> get("/cards/export") |> Map.fetch!(:resp_body) |> Jason.decode!()
    assert [entry] = exported["cards"]
    assert entry["quality_language"] && entry["quality_image"] && entry["quality_delete"]
    assert entry["quality_notes"] == saved.quality_notes

    {:ok, reloaded, _} = live(signed, "/cards")
    assert has_element?(reloaded, "#quality-#{card.id}_quality_language[checked]")
    assert has_element?(reloaded, "#quality-#{card.id}_quality_image[checked]")
    assert has_element?(reloaded, "#quality-#{card.id}_quality_delete[checked]")

    assert has_element?(
             reloaded,
             "#quality-#{card.id}_quality_notes[value='#{saved.quality_notes}']"
           )

    reloaded
    |> form("#quality-form-#{card.id}",
      quality: %{
        quality_language: "false",
        quality_image: "false",
        quality_delete: "false",
        quality_notes: ""
      }
    )
    |> render_change()

    reloaded |> element("#quality-save-all") |> render_click()

    cleared = Learning.get_card!(card.id)
    refute cleared.quality_language || cleared.quality_image || cleared.quality_delete
    assert cleared.quality_notes == ""
  end

  test "save all persists drafts across cards and filters", %{conn: conn} do
    first = card()
    second = card()
    {:ok, view, _} = live(login(conn, "parent"), "/cards")

    view
    |> form("#quality-form-#{first.id}",
      quality: %{quality_notes: "Draft note", quality_image: "true"}
    )
    |> render_change()

    view
    |> form("#quality-form-#{second.id}", quality: %{quality_language: "true"})
    |> render_change()

    view |> form("#card-filters", filters: %{search: "no matching card"}) |> render_change()
    view |> element("#quality-save-all") |> render_click()
    view |> form("#card-filters", filters: %{search: ""}) |> render_change()

    assert has_element?(view, "#quality-#{first.id}_quality_notes[value='Draft note']")
    assert has_element?(view, "#quality-#{first.id}_quality_image[checked]")
    assert Learning.get_card!(first.id).quality_notes == "Draft note"
    assert Learning.get_card!(first.id).quality_image
    assert Learning.get_card!(second.id).quality_language
    assert has_element?(view, "#quality-save-all[disabled]")
  end
end
