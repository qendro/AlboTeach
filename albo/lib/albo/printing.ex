defmodule Albo.Printing do
  @moduledoc "Bounded, offline PDF downloads using a revision-checked collection snapshot."
  import Ecto.Query
  alias Albo.{Learning, Repo}
  alias Albo.Learning.Card
  @salt "physical-flashcards"

  def selection_token(cards) do
    Phoenix.Token.sign(AlboWeb.Endpoint, @salt, Enum.map(cards, &{&1.id, &1.revision}))
  end

  def record_download(cards) do
    ids = Enum.map(cards, & &1.id)
    Repo.update_all(from(c in Card, where: c.id in ^ids), inc: [print_count: 1])
    Phoenix.PubSub.broadcast(Albo.PubSub, "cards:printing", :print_counts_updated)
  end

  def selected_cards(token) when is_binary(token) do
    with {:ok, revisions} when is_list(revisions) and length(revisions) in 1..300 <-
           Phoenix.Token.verify(AlboWeb.Endpoint, @salt, token, max_age: 3600) do
      cards =
        Learning.list_cards()
        |> Enum.filter(&({&1.id, &1.revision} in revisions and &1.status == "active"))
        |> Enum.sort_by(& &1.id)

      if length(cards) == length(revisions),
        do: {:ok, cards},
        else:
          {:error,
           "A selected card changed or was archived. Refresh your selection and try again."}
    else
      _ ->
        {:error,
         "Select 1 to 300 cards. If this page has been open for an hour, refresh it first."}
    end
  end

  def selected_cards(_), do: {:error, "Select at least one card to print."}

  def options(params) when is_map(params) do
    with per_sheet when per_sheet in ["8", "10", "21"] <- Map.get(params, "per_sheet", "8"),
         flip when flip in ["long-edge", "short-edge"] <- Map.get(params, "flip", "long-edge"),
         image_side when image_side in ["albanian", "english"] <-
           Map.get(params, "image_side", "albanian"),
         {:ok, x} <- offset(Map.get(params, "back_x_mm", "0")),
         {:ok, y} <- offset(Map.get(params, "back_y_mm", "0")) do
      {:ok,
       %{
         per_sheet: String.to_integer(per_sheet),
         flip: flip,
         image_side: image_side,
         back_x_mm: x,
         back_y_mm: y
       }}
    else
      _ ->
        {:error,
         "Choose a valid layout, picture side, duplex flip, and offsets between -5 and 5 mm."}
    end
  end

  def options(_), do: {:error, "Choose valid print settings."}

  defp offset(value) when is_binary(value) do
    case Float.parse(value) do
      {number, ""} when number >= -5 and number <= 5 -> {:ok, number}
      _ -> :error
    end
  end

  defp offset(_), do: :error

  def pdf(cards, options, calibration \\ false) do
    directory =
      Path.join(
        System.tmp_dir!(),
        "alboteach-print-" <> Base.url_encode64(:crypto.strong_rand_bytes(18), padding: false)
      )

    File.mkdir!(directory)
    File.chmod!(directory, 0o700)

    try do
      input = Path.join(directory, "cards.json")
      output = Path.join(directory, "cards.pdf")

      File.write!(
        input,
        Jason.encode!(%{
          cards: Enum.map(cards, &Map.take(&1, [:id, :revision, :albanian, :english, :image])),
          options: options,
          calibration: calibration
        })
      )

      script = Application.app_dir(:albo, "priv/printing/render.py")

      case System.cmd("python3", [script, input, output], stderr_to_stdout: true) do
        {_, 0} ->
          File.read(output)

        {message, _} ->
          case Jason.decode(message) do
            {:ok, %{"error" => error}} -> {:error, error}
            _ -> {:error, "The PDF could not be created. Please try again."}
          end
      end
    rescue
      _ ->
        {:error,
         "The PDF could not be created. Check that the app image includes the print dependencies."}
    after
      File.rm_rf(directory)
    end
  end
end
