defmodule AlboWeb.PrintController do
  use AlboWeb, :controller
  alias Albo.Printing

  def index(conn, _params), do: redirect(conn, to: ~p"/cards")

  def create(conn, params) do
    calibration = params["kind"] == "calibration"

    with {:ok, options} <- Printing.options(params["print"] || %{}),
         {:ok, cards} <-
           if(calibration, do: {:ok, []}, else: Printing.selected_cards(params["selection"])),
         {:ok, pdf} <- Printing.pdf(cards, options, calibration) do
      unless calibration, do: Printing.record_download(cards)

      filename =
        cond do
          calibration -> "alboteach-calibration.pdf"
          options.sides == "albanian" -> "alboteach-albanian.pdf"
          true -> "alboteach-flashcards.pdf"
        end

      send_download(conn, {:binary, pdf},
        filename: filename,
        content_type: "application/pdf"
      )
    else
      {:error, message} ->
        conn |> put_flash(:error, message) |> redirect(to: ~p"/cards")
    end
  end
end
