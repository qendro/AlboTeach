defmodule Albo.Learning do
  @moduledoc "Immediately available vocabulary and one household learner's practice history."
  import Ecto.Query
  alias Albo.Repo
  alias Albo.Learning.{Card, Progress, Review, CardKey, ContentEvent}

  def list_cards, do: Repo.all(from c in Card, order_by: [asc: c.category, asc: c.id])
  def get_card!(id), do: Repo.get!(Card, id)
  def change_card(card, attrs \\ %{}), do: Card.changeset(card, attrs)

  def save_quality_check(id, attrs) do
    Repo.transaction(fn ->
      case get_card!(id) |> Card.quality_changeset(attrs) |> Repo.update() do
        {:ok, saved} ->
          audit(saved, "quality_check")
          saved

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  def save_quality_checks(drafts) do
    Repo.transaction(fn ->
      Enum.map(drafts, fn {id, attrs} ->
        case save_quality_check(id, attrs) do
          {:ok, card} -> card
          {:error, changeset} -> Repo.rollback(changeset)
        end
      end)
    end)
  end

  def save_card(card, attrs, expected_revision) do
    Repo.transaction(fn ->
      current = if card.id, do: get_card!(card.id), else: card
      if current.id && current.revision != expected_revision, do: Repo.rollback(:stale)
      cs = Card.changeset(current, attrs)

      # validate_required can remove a blank field from changes while retaining its error.
      # Reject invalid changesets before treating an empty changes map as a successful no-op.
      if !cs.valid?, do: Repo.rollback(cs)

      if map_size(cs.changes) == 0 && current.id do
        current
      else
        cs =
          cs
          |> Ecto.Changeset.put_change(
            :status,
            if(current.status == "archived", do: "archived", else: "active")
          )
          |> Ecto.Changeset.put_change(:reviewer, nil)
          |> Ecto.Changeset.put_change(
            :revision,
            if(current.id, do: current.revision + 1, else: 1)
          )

        if duplicate?(Ecto.Changeset.apply_changes(cs), current.id), do: Repo.rollback(:duplicate)

        case Repo.insert_or_update(cs) do
          {:ok, saved} ->
            remember_keys(saved)
            audit(saved, if(current.id, do: "edited", else: "created"))
            saved

          {:error, error} ->
            Repo.rollback(error)
        end
      end
    end)
  end

  def decide(id, revision, decision, reviewer \\ nil)
      when decision in ["reviewed", "active", "archived"] do
    Repo.transaction(fn ->
      card = get_card!(id)
      if card.revision != revision, do: Repo.rollback(:stale)

      changes =
        if decision == "reviewed" do
          if !is_binary(reviewer) || String.trim(reviewer) == "" || String.length(reviewer) > 100,
            do: Repo.rollback(:reviewer_required)

          [reviewer: String.trim(reviewer)]
        else
          [status: decision]
        end

      saved = card |> Ecto.Changeset.change(changes) |> Repo.update!()
      audit(saved, decision)
      saved
    end)
  end

  def import_json(json) when is_binary(json) and byte_size(json) <= 200_000 do
    with {:ok, %{"cards" => cards}} when is_list(cards) and length(cards) <= 300 <-
           Jason.decode(json) do
      Repo.transaction(fn ->
        Enum.reduce(Enum.with_index(cards, 1), %{added: 0, skipped: 0}, fn {attrs, row}, acc ->
          if !is_map(attrs), do: Repo.rollback({:invalid_row, row})
          cs = Card.changeset(%Card{}, Map.put_new(attrs, "source", "AI proposal"))
          if !cs.valid?, do: Repo.rollback({:invalid_row, row})

          if duplicate?(Ecto.Changeset.apply_changes(cs), nil) do
            Map.update!(acc, :skipped, &(&1 + 1))
          else
            card = Repo.insert!(cs)
            remember_keys(card)
            audit(card, "imported")
            Map.update!(acc, :added, &(&1 + 1))
          end
        end)
      end)
    else
      _ -> {:error, :invalid_json}
    end
  end

  def import_json(_), do: {:error, :invalid_json}

  def export_json do
    cards =
      Enum.map(
        list_cards(),
        &Map.take(
          &1,
          Card.fields() ++ Card.quality_fields() ++ [:id, :revision, :status, :reviewer]
        )
      )

    Jason.encode!(%{schema_version: 1, cards: cards}, pretty: true)
  end

  def seed do
    if Repo.aggregate(Card, :count) == 0 do
      {:ok, _} = Application.app_dir(:albo, "priv/starter.json") |> File.read!() |> import_json()
    end

    :ok
  end

  def stats(now \\ DateTime.utc_now()) do
    today = day_start(now)
    available = Repo.aggregate(from(c in Card, where: c.status == "active"), :count)

    learned =
      Repo.aggregate(
        from(p in Progress,
          join: c in Card,
          on: c.id == p.card_id,
          where: c.status == "active" and c.revision == p.revision and p.streak >= 2
        ),
        :count
      )

    practiced =
      Repo.one(
        from r in Review, where: r.inserted_at >= ^today, select: count(r.card_id, :distinct)
      )

    %{available: available, learned: learned, practiced: practiced}
  end

  def topics do
    Repo.all(
      from c in Card,
        where: c.status == "active",
        group_by: c.category,
        order_by: c.category,
        select: %{id: c.category, name: c.category, count: count(c.id)}
    )
  end

  def session(category \\ "all", difficulty \\ "all", now \\ DateTime.utc_now()) do
    introduced = introductions(now)

    base =
      from c in Card,
        left_join: p in Progress,
        on: c.id == p.card_id,
        where: c.status == "active"

    base =
      if category == "all", do: base, else: from([c, p] in base, where: c.category == ^category)

    base =
      if difficulty == "all",
        do: base,
        else: from([c, p] in base, where: c.difficulty == ^difficulty)

    due =
      Repo.all(
        from [c, p] in base,
          where: p.revision == c.revision and p.due_at <= ^now,
          order_by: [asc: p.due_at, asc: c.id],
          limit: 5,
          select: c
      )

    new =
      Repo.all(
        from [c, p] in base,
          where: is_nil(p.id) or p.revision != c.revision,
          order_by: c.id,
          limit: ^max(0, 3 - introduced),
          select: c
      )

    due ++ new
  end

  def flashcards(category \\ "all", difficulty \\ "all") do
    query = from c in Card, where: c.status == "active", order_by: c.id

    query =
      if category == "all", do: query, else: from(c in query, where: c.category == ^category)

    query =
      if difficulty == "all",
        do: query,
        else: from(c in query, where: c.difficulty == ^difficulty)

    Repo.all(query)
  end

  def grade(id, revision, result, token, now \\ DateTime.utc_now(), mode \\ :daily)
      when result in ["again", "remembered"] and mode in [:daily, :all] do
    now = DateTime.truncate(now, :second)

    Repo.transaction(fn ->
      card = get_card!(id)
      if card.status != "active" || card.revision != revision, do: Repo.rollback(:stale)

      if Repo.exists?(from r in Review, where: r.token == ^token),
        do: Repo.rollback(:already_recorded)

      previous = Repo.get_by(Progress, card_id: id)
      fresh = previous == nil || previous.revision != revision
      early = !fresh && DateTime.compare(previous.due_at, now) == :gt
      if mode == :daily && early, do: Repo.rollback(:not_due)
      if mode == :daily && fresh && introductions(now) >= 3, do: Repo.rollback(:daily_limit)

      streak =
        cond do
          result == "again" -> 0
          fresh -> 1
          early -> previous.streak
          true -> previous.streak + 1
        end

      days = Enum.at([1, 3, 7, 14, 30], min(max(streak - 1, 0), 4))

      due =
        if early && result == "remembered",
          do: previous.due_at,
          else: DateTime.add(now, if(result == "again", do: 600, else: days * 86_400), :second)

      progress = previous || %Progress{card_id: id}

      progress
      |> Ecto.Changeset.change(
        revision: revision,
        streak: streak,
        reviews: if(fresh, do: 1, else: previous.reviews + 1),
        due_at: due
      )
      |> Repo.insert_or_update!()

      Repo.insert_all(Review, [
        %{
          card_id: id,
          revision: revision,
          result: result,
          token: token,
          introduced: fresh,
          inserted_at: now
        }
      ])

      :recorded
    end)
  end

  def current?(card),
    do:
      Repo.exists?(
        from c in Card,
          where: c.id == ^card.id and c.revision == ^card.revision and c.status == "active"
      )

  defp day_start(now), do: DateTime.new!(DateTime.to_date(now), ~T[00:00:00], "Etc/UTC")

  defp introductions(now) do
    today = day_start(now)

    Repo.one(
      from r in Review,
        where: r.inserted_at >= ^today and r.introduced == true,
        select: count(r.card_id, :distinct)
    )
  end

  defp normalize(value),
    do:
      value
      |> to_string()
      |> String.normalize(:nfc)
      |> String.downcase()
      |> String.replace(~r/[^\p{L}\p{N}]+/u, " ")
      |> String.trim()

  defp keys(card),
    do:
      Enum.map(
        [:concept, :albanian, :english],
        &{Atom.to_string(&1), normalize(Map.get(card, &1))}
      )

  defp duplicate?(card, own_id) do
    Enum.any?(keys(card), fn {kind, value} ->
      query = from k in CardKey, where: k.kind == ^kind and k.value == ^value
      query = if own_id, do: from(k in query, where: k.card_id != ^own_id), else: query
      Repo.exists?(query)
    end)
  end

  defp remember_keys(card) do
    Repo.insert_all(
      CardKey,
      Enum.map(keys(card), fn {kind, value} -> %{card_id: card.id, kind: kind, value: value} end),
      on_conflict: :nothing
    )
  end

  defp audit(card, action) do
    snapshot =
      Map.take(card, Card.fields() ++ Card.quality_fields() ++ [:revision, :status, :reviewer])
      |> Jason.encode!()

    Repo.insert_all(ContentEvent, [
      %{
        card_id: card.id,
        action: action,
        snapshot: snapshot,
        inserted_at: DateTime.utc_now() |> DateTime.truncate(:second)
      }
    ])
  end
end
