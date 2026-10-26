defmodule Albo.Learning.CardOrder do
  @moduledoc "Deterministic studio sorting, independent of saved manual positions."
  @sorts ~w(order albanian english topic subtopic level)

  def sorts, do: @sorts

  def sort(cards, field \\ "order", direction \\ "asc") do
    fields =
      case field do
        "albanian" -> [:albanian]
        "english" -> [:english]
        "topic" -> [:category, :subcategory]
        "subtopic" -> [:subcategory, :category]
        "level" -> [:difficulty]
        _ -> [:sort_order]
      end

    Enum.sort(cards, fn left, right ->
      case compare(left, right, fields, direction) do
        :eq -> {left.sort_order, left.id} <= {right.sort_order, right.id}
        :lt -> true
        :gt -> false
      end
    end)
  end

  defp compare(_, _, [], _), do: :eq

  defp compare(left, right, [field | rest], direction) do
    l = value(left, field)
    r = value(right, field)

    result =
      cond do
        l == r -> :eq
        field == :subcategory && l == "" -> :gt
        field == :subcategory && r == "" -> :lt
        direction == "desc" -> if(l > r, do: :lt, else: :gt)
        l < r -> :lt
        true -> :gt
      end

    if result == :eq, do: compare(left, right, rest, direction), else: result
  end

  defp value(card, :sort_order), do: card.sort_order
  defp value(card, :difficulty), do: if(card.difficulty == "beginner", do: 0, else: 1)

  defp value(card, field),
    do: card |> Map.fetch!(field) |> to_string() |> String.normalize(:nfc) |> String.downcase()
end
