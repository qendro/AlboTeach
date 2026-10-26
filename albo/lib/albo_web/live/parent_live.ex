defmodule AlboWeb.ParentLive do
  use AlboWeb, :live_view
  alias Albo.{Learning, Printing}
  alias Albo.Learning.{Card, CardOrder}

  def mount(_, _, socket) do
    if connected?(socket), do: Phoenix.PubSub.subscribe(Albo.PubSub, "cards:printing")
    if connected?(socket), do: Phoenix.PubSub.subscribe(Albo.PubSub, "cards:collection")

    {:ok,
     socket
     |> assign(
       page_title: "Card studio",
       editing: nil,
       import_open: false,
       print_open: false,
       delete_cards: [],
       sort: "order",
       sort_direction: "asc",
       studio_path: "/cards",
       selected: MapSet.new(),
       quality_forms: %{},
       quality_drafts: %{},
       selection_size: 1,
       print_form:
         to_form(
           %{
             "per_sheet" => "8",
             "sides" => "both",
             "flip" => "long-edge",
             "image_side" => "albanian",
             "art_style" => "color",
             "back_x_mm" => "0",
             "back_y_mm" => "0"
           },
           as: :print
         ),
       filter_form: to_form(%{"search" => "", "status" => "all"}, as: :filters),
       search: "",
       status: "all",
       import_form: to_form(%{"json" => ""}, as: :import),
       review_form: to_form(%{"reviewer" => ""}, as: :review)
     )
     |> load_cards()}
  end

  def handle_params(params, uri, socket) do
    sort = if params["sort"] in CardOrder.sorts(), do: params["sort"], else: "order"
    direction = if params["direction"] == "desc", do: "desc", else: "asc"

    {:noreply,
     socket
     |> assign(sort: sort, sort_direction: direction, studio_path: URI.parse(uri).path)
     |> load_cards()}
  end

  defp load_cards(socket) do
    all =
      CardOrder.sort(Learning.list_cards(), socket.assigns.sort, socket.assigns.sort_direction)

    positions = Map.new(all, &{&1.sort_order, &1.id})
    ids = Enum.map(all, & &1.id)
    drafts = Map.take(socket.assigns.quality_drafts, ids)

    cards =
      Enum.filter(all, fn card ->
        (socket.assigns.status == "all" || card.status == socket.assigns.status) &&
          String.contains?(
            String.downcase(
              Enum.join([card.english, card.albanian, card.category, card.subcategory], " ")
            ),
            String.downcase(String.trim(socket.assigns.search))
          )
      end)

    selected =
      all
      |> Enum.filter(
        &(&1.status == "active" && MapSet.member?(socket.assigns.selected, to_string(&1.id)))
      )

    selected_ids = MapSet.new(selected, &to_string(&1.id))
    visible_ids = cards |> Enum.filter(&(&1.status == "active")) |> Enum.map(&to_string(&1.id))
    visible_selected = Enum.count(visible_ids, &MapSet.member?(selected_ids, &1))

    selection_state =
      cond do
        visible_selected == 0 -> "none"
        visible_selected == length(visible_ids) -> "all"
        true -> "mixed"
      end

    socket
    |> assign(
      selected: selected_ids,
      selected_cards: selected,
      selection_state: selection_state,
      selected_count: length(selected),
      selection_token: Printing.selection_token(selected),
      visible_ids: visible_ids,
      new_ids:
        cards
        |> Enum.filter(&(&1.status == "active" && &1.print_count == 0))
        |> Enum.map(&to_string(&1.id)),
      count: length(all),
      available: Enum.count(all, &(&1.status == "active")),
      reviewed: Enum.count(all, &(&1.reviewer not in [nil, ""])),
      can_reorder:
        socket.assigns.sort == "order" && socket.assigns.sort_direction == "asc" &&
          String.trim(socket.assigns.search) == "" && socket.assigns.status == "all",
      neighbors:
        Map.new(all, fn card ->
          {card.id,
           %{
             up: Map.get(positions, card.sort_order - 1),
             down: Map.get(positions, card.sort_order + 1)
           }}
        end),
      sort_form:
        to_form(%{"by" => socket.assigns.sort, "direction" => socket.assigns.sort_direction},
          as: :sort
        ),
      topic_options: all |> Enum.map(& &1.category) |> Enum.uniq() |> Enum.sort(),
      subtopics_by_topic:
        all
        |> Enum.reject(&(&1.subcategory in [nil, ""]))
        |> Enum.group_by(&String.downcase(&1.category), & &1.subcategory)
        |> Map.new(fn {key, values} -> {key, values |> Enum.uniq() |> Enum.sort()} end),
      quality_drafts: drafts,
      quality_forms:
        Enum.reduce(cards, %{}, fn card, forms ->
          Map.put(forms, card.id, quality_form(card, Map.get(drafts, card.id, %{})))
        end),
      empty: cards == []
    )
    |> stream(:cards, cards, reset: true)
    |> stream(:print_cards, selected, reset: true)
  end

  defp change_sort(socket, field, direction) do
    if field in CardOrder.sorts() && direction in ["asc", "desc"] do
      {:noreply,
       push_patch(socket,
         to:
           socket.assigns.studio_path <>
             "?" <> URI.encode_query(%{"sort" => field, "direction" => direction})
       )}
    else
      {:noreply, socket}
    end
  end

  defp quality_form(card, attrs) do
    card |> Card.quality_changeset(attrs) |> to_form(as: :quality, id: "quality-#{card.id}")
  end

  defp stage_quality(socket, id, attrs) do
    case Learning.get_card(id) do
      nil ->
        socket |> load_cards() |> put_flash(:info, "That card was deleted in another window.")

      card ->
        socket
        |> assign(:quality_drafts, Map.put(socket.assigns.quality_drafts, card.id, attrs))
        |> assign(
          :quality_forms,
          Map.put(socket.assigns.quality_forms, card.id, quality_form(card, attrs))
        )
        |> stream_insert(:cards, card)
    end
  end

  def handle_event("sort", %{"field" => field}, socket) do
    direction =
      if socket.assigns.sort == field && socket.assigns.sort_direction == "asc",
        do: "desc",
        else: "asc"

    change_sort(socket, field, direction)
  end

  def handle_event("sort", %{"sort" => params}, socket),
    do: change_sort(socket, params["by"], params["direction"])

  def handle_event(
        "move",
        %{"id" => id, "direction" => direction, "position" => position, "neighbor" => neighbor},
        socket
      ) do
    if socket.assigns.can_reorder do
      case Learning.move_card(id, direction, position, neighbor) do
        {:ok, _} ->
          {:noreply, load_cards(socket)}

        {:error, _} ->
          {:noreply,
           socket
           |> load_cards()
           |> put_flash(
             :error,
             "The order changed in another window. Check the refreshed list and try again."
           )}
      end
    else
      {:noreply,
       socket
       |> load_cards()
       |> put_flash(:info, "Choose # ascending and show all cards to rearrange them.")}
    end
  end

  def handle_event("request-delete", params, socket) do
    socket = load_cards(socket)

    cards =
      if id = params["id"],
        do: Enum.filter(Learning.list_cards(), &(to_string(&1.id) == id)),
        else: socket.assigns.selected_cards

    {:noreply,
     socket
     |> assign(delete_cards: cards, editing: nil)
     |> stream(:delete_cards, cards, reset: true)}
  end

  def handle_event("cancel-delete", _, socket), do: {:noreply, assign(socket, delete_cards: [])}

  def handle_event("delete", _, socket) do
    case Learning.delete_cards(socket.assigns.delete_cards) do
      {:ok, count} ->
        {:noreply,
         socket
         |> assign(delete_cards: [])
         |> load_cards()
         |> put_flash(
           :info,
           "Deleted #{count} #{if count == 1, do: "card", else: "cards"}. Remaining cards keep their sequence."
         )}

      {:error, _} ->
        {:noreply,
         socket
         |> assign(delete_cards: [])
         |> load_cards()
         |> put_flash(
           :error,
           "The selection changed. Review the refreshed cards before deleting."
         )}
    end
  end

  def handle_event("change-quality", %{"id" => id, "quality" => attrs}, socket) do
    {:noreply, stage_quality(socket, id, attrs)}
  end

  def handle_event("save-quality", %{"id" => id, "quality" => attrs}, socket) do
    handle_event("save-all-quality", %{}, stage_quality(socket, id, attrs))
  end

  def handle_event("save-all-quality", _, socket) do
    case Learning.save_quality_checks(socket.assigns.quality_drafts) do
      {:ok, _cards} ->
        {:noreply,
         socket
         |> assign(quality_drafts: %{}, quality_forms: %{})
         |> load_cards()
         |> put_flash(:info, "All quality checks saved.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        form = to_form(changeset, as: :quality, id: "quality-#{changeset.data.id}")

        {:noreply,
         socket
         |> assign(:quality_forms, Map.put(socket.assigns.quality_forms, changeset.data.id, form))
         |> stream_insert(:cards, changeset.data)
         |> put_flash(:error, "Nothing saved. Check the highlighted notes and try again.")}

      {:error, :stale} ->
        {:noreply,
         socket
         |> load_cards()
         |> put_flash(
           :error,
           "A card was deleted in another window. Check the refreshed list and save again."
         )}
    end
  end

  def handle_event("filter", %{"filters" => params}, socket),
    do:
      {:noreply,
       socket
       |> assign(
         search: params["search"],
         status: params["status"],
         filter_form: to_form(params, as: :filters)
       )
       |> load_cards()}

  def handle_event("new", _, socket) do
    concept = "card." <> Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
    {:noreply, edit(socket, %Card{concept: concept})}
  end

  def handle_event("edit", %{"id" => id}, socket) do
    case Learning.get_card(id) do
      nil ->
        {:noreply,
         socket |> load_cards() |> put_flash(:info, "That card was deleted in another window.")}

      card ->
        {:noreply, edit(socket, card)}
    end
  end

  def handle_event("close", _, socket),
    do:
      {:noreply,
       assign(socket, editing: nil, import_open: false, print_open: false, delete_cards: [])}

  def handle_event("toggle-print", %{"id" => id}, socket) do
    selected = socket.assigns.selected

    selected =
      if MapSet.member?(selected, id),
        do: MapSet.delete(selected, id),
        else:
          MapSet.union(
            selected,
            MapSet.new(
              socket.assigns.visible_ids
              |> Enum.drop_while(&(&1 != id))
              |> Enum.take(socket.assigns.selection_size)
            )
          )

    {:noreply, socket |> assign(selected: selected) |> load_cards()}
  end

  def handle_event("select-visible", _, socket) do
    selected =
      if socket.assigns.selection_state == "all",
        do: MapSet.new(),
        else: MapSet.union(socket.assigns.selected, MapSet.new(socket.assigns.visible_ids))

    {:noreply, socket |> assign(selected: selected) |> load_cards()}
  end

  def handle_event("select-new", _, socket) do
    socket = load_cards(socket)
    {:noreply, socket |> assign(selected: MapSet.new(socket.assigns.new_ids)) |> load_cards()}
  end

  def handle_event("selection-settings", %{"size" => size}, socket)
      when size in ["1", "20"] do
    {:noreply, assign(socket, selection_size: String.to_integer(size))}
  end

  def handle_event("selection-settings", _, socket), do: {:noreply, socket}

  def handle_event("open-print", _, socket),
    do: {:noreply, socket |> load_cards() |> assign(print_open: true)}

  def handle_event("print-settings", %{"print" => params}, socket) do
    params = Map.merge(socket.assigns.print_form.params, params)

    case Printing.options(params) do
      {:ok, _} -> {:noreply, assign(socket, print_form: to_form(params, as: :print))}
      {:error, _} -> {:noreply, socket}
    end
  end

  def handle_event("validate", %{"card" => attrs} = params, socket) do
    attrs =
      if params["_target"] == ["card", "category"] &&
           String.downcase(String.trim(attrs["category"] || "")) !=
             String.downcase(socket.assigns.editing.category || ""),
         do: Map.put(attrs, "subcategory", ""),
         else: attrs

    {:noreply,
     assign(socket,
       form: to_form(Learning.change_card(socket.assigns.editing, attrs), action: :validate)
     )}
  end

  def handle_event("save", %{"card" => attrs}, socket) do
    card = socket.assigns.editing
    # The editor can create a stable ID without asking a learner for an internal key.
    attrs =
      if card.id == nil && String.trim(Map.get(attrs, "concept", "")) == "",
        do:
          Map.put(
            attrs,
            "concept",
            "card." <> Base.encode16(:crypto.strong_rand_bytes(8), case: :lower)
          ),
        else: attrs

    attrs =
      if String.trim(Map.get(attrs, "source", card.source || "")) == "",
        do: Map.put(attrs, "source", "Family entry"),
        else: attrs

    case Learning.save_card(card, attrs, card.revision) do
      {:ok, saved} ->
        message =
          if saved.status == "archived",
            do: "Changes saved. This card is still archived.",
            else: "Card saved and ready to practice."

        {:noreply, socket |> assign(editing: nil) |> put_flash(:info, message) |> load_cards()}

      {:error, %Ecto.Changeset{} = cs} ->
        {:noreply,
         assign(socket, form: to_form(cs, action: if(card.id, do: :update, else: :insert)))}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, error(reason))}
    end
  end

  def handle_event("review", %{"review" => params}, socket) do
    card = socket.assigns.editing

    case Learning.decide(card.id, card.revision, "reviewed", params["reviewer"]) do
      {:ok, saved} ->
        {:noreply,
         socket
         |> edit(saved)
         |> put_flash(:info, "Optional review recorded. Card availability is unchanged.")
         |> load_cards()}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, error(reason))}
    end
  end

  def handle_event("set-status", %{"status" => status}, socket)
      when status in ["active", "archived"] do
    card = socket.assigns.editing

    case Learning.decide(card.id, card.revision, status) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(editing: nil)
         |> put_flash(
           :info,
           if(status == "active",
             do: "Card restored and ready to practice.",
             else: "Card archived. You can restore it anytime."
           )
         )
         |> load_cards()}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, error(reason))}
    end
  end

  def handle_event("open-import", _, socket), do: {:noreply, assign(socket, import_open: true)}

  def handle_event("import", %{"import" => %{"json" => json}}, socket) do
    case Learning.import_json(json) do
      {:ok, counts} ->
        {:noreply,
         socket
         |> assign(import_open: false, import_form: to_form(%{"json" => ""}, as: :import))
         |> put_flash(
           :info,
           "#{counts.added} cards ready to practice; #{counts.skipped} duplicates skipped. Existing cards were preserved."
         )
         |> load_cards()}

      {:error, {:invalid_row, row}} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Card #{row} is invalid. Nothing was imported. Check the required fields and allowed images."
         )}

      {:error, _} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Use a JSON object with a cards array: up to 300 cards and 200 KB."
         )}
    end
  end

  def handle_info(:print_counts_updated, socket), do: {:noreply, load_cards(socket)}
  def handle_info(:cards_updated, socket), do: {:noreply, load_cards(socket)}

  defp aria_sort(sort, direction, fields) do
    if sort in fields,
      do: if(direction == "asc", do: "ascending", else: "descending"),
      else: "none"
  end

  defp sort_indicator(sort, direction, field) do
    if sort == field, do: if(direction == "asc", do: "↑", else: "↓"), else: "↕"
  end

  defp edit(socket, card),
    do:
      assign(socket,
        editing: card,
        form: to_form(Learning.change_card(card)),
        review_form: to_form(%{"reviewer" => ""}, as: :review)
      )

  defp error(:stale),
    do: "This card changed in another window. Close and reopen it to load the latest wording."

  defp error(:duplicate),
    do:
      "That concept, Albanian wording, or English meaning already exists, including earlier corrections. Edit the existing card instead."

  defp error(:reviewer_required),
    do: "Add a reviewer’s name to record an optional review, or just save your changes."

  def render(assigns) do
    assigns =
      assign(
        assigns,
        :sheet_count,
        ceil(assigns.selected_count / String.to_integer(assigns.print_form[:per_sheet].value))
      )

    albanian_only = assigns.print_form[:sides].value == "albanian"

    assigns =
      assign(assigns,
        albanian_only: albanian_only,
        page_count: assigns.sheet_count * if(albanian_only, do: 1, else: 2)
      )

    ~H"""
    <Layouts.app flash={@flash} role={@role} active="parent">
      <div class="page-heading">
        <div>
          <span class="eyebrow">YOUR WORDS, YOUR WAY</span><h1>
            Card studio<span class="coral">.</span>
          </h1><p>Create, edit, and print your own flashcards.</p>
        </div><button class="button primary" id="new-card" phx-click="new"><.icon name="hero-plus" />
        Add a card</button>
      </div>
      <div class="studio-banner">
        <span class="banner-symbol">✦</span><div>
          <h3>Add a word. Start using it.</h3><p>
            New and imported cards are ready to practice immediately. You can check the wording, make corrections, or add a family review whenever you like.
          </p>
        </div>
      </div>
      <div class="studio-stats">
        <span><b>{@count}</b> total cards</span><span><b>{@available}</b> ready to practice</span><span><b>{@reviewed}</b>
        optionally reviewed</span>
      </div>
      <section class="content-panel">
        <div class="studio-tools">
          <.form for={@filter_form} id="card-filters" phx-change="filter" class="filter-row">
            <.input
              field={@filter_form[:search]}
              type="search"
              placeholder="Find a word or topic…"
              label="Search cards"
            /><.input
              field={@filter_form[:status]}
              label="Show"
              type="select"
              options={[
                {"All cards", "all"},
                {"Ready to practice", "active"},
                {"Archived", "archived"}
              ]}
            />
          </.form><div class="tool-buttons">
            <button
              id="quality-save-all"
              phx-click="save-all-quality"
              class="button primary"
              disabled={map_size(@quality_drafts) == 0}
              phx-disable-with="Saving…"
            >Save all</button>
            <button id="print-open" phx-click="open-print" class="button secondary"><.icon name="hero-printer" />
            Print cards{if @selected_count > 0, do: " (#{@selected_count})"}</button>
            <button id="import-open" phx-click="open-import" class="button secondary">Import JSON</button><.link
              href="/cards/export"
              class="button secondary"
            ><.icon name="hero-arrow-down-tray" /> Export</.link>
          </div>
        </div>
        <div
          class="studio-selection"
          id="studio-selection"
          role="region"
          aria-label="Card selection tools"
        >
          <div class="studio-selection-status">
            <span
              id="select-all-control"
              class="studio-select"
              phx-hook="SelectionCheckbox"
              phx-update="ignore"
              data-state={@selection_state}
              data-disabled={to_string(@visible_ids == [])}
            >
              <.input
                type="checkbox"
                id="select-visible"
                name="select-visible"
                phx-click="select-visible"
                checked={@selection_state == "all"}
                disabled={@visible_ids == []}
                aria-checked={
                  if @selection_state == "mixed",
                    do: "mixed",
                    else: to_string(@selection_state == "all")
                }
                aria-label="Select or unselect all shown cards"
                title="Select or unselect all shown cards"
              />
            </span>
            <label for="select-visible" id="print-selected-count" aria-live="polite"><b>{@selected_count}</b>
            selected</label>
          </div>
          <div class="studio-selection-actions">
            <button
              id="select-new"
              phx-click="select-new"
              class="studio-select-new"
              disabled={@visible_ids == []}
              title="Select only shown cards that have never been printed"
            >
              <.icon name="hero-sparkles" /> Select new
            </button>
            <div class="studio-selection-size" role="group" aria-label="Cards selected per click">
              <span>Per click</span>
              <div class="studio-segmented">
                <button
                  id="selection-size-1"
                  type="button"
                  phx-click="selection-settings"
                  phx-value-size="1"
                  aria-pressed={to_string(@selection_size == 1)}
                  title="Select one card at a time"
                >1</button>
                <button
                  id="selection-size-20"
                  type="button"
                  phx-click="selection-settings"
                  phx-value-size="20"
                  aria-pressed={to_string(@selection_size == 20)}
                  title="Select a card and the next 19 available cards"
                >20</button>
              </div>
            </div>
          </div>
        </div>
        <div class="studio-order-toolbar">
          <p id="reorder-help">
            <%= if @can_reorder do %>
              Use the arrows to arrange cards. Printing follows the selected sort.
            <% else %>
              To rearrange cards, choose # ascending and show all cards without a search.
            <% end %>
          </p>
          <.form for={@sort_form} id="studio-sort-controls" phx-change="sort">
            <.input
              field={@sort_form[:by]}
              label="Sort by"
              type="select"
              options={[
                {"# · Manual order", "order"},
                {"Albanian", "albanian"},
                {"English", "english"},
                {"Topic", "topic"},
                {"Sub-topic", "subtopic"},
                {"Level", "level"}
              ]}
            />
            <.input
              field={@sort_form[:direction]}
              label="Direction"
              type="select"
              options={[
                {"Ascending", "asc"},
                {"Descending", "desc"}
              ]}
            />
          </.form>
          <button
            id="delete-selected"
            type="button"
            phx-click="request-delete"
            class="studio-delete"
            disabled={@selected_count == 0}
          >
            <.icon name="hero-trash" /> Delete selected
          </button>
        </div>
        <div class="table-scroll">
          <table class="vocab-table studio-table">
            <thead>
              <tr>
                <th scope="col"><span class="sr-only">Selection</span></th>
                <th scope="col" aria-sort={aria_sort(@sort, @sort_direction, ["order"])}>
                  <button
                    id="sort-order"
                    class="studio-sort-button"
                    phx-click="sort"
                    phx-value-field="order"
                    aria-label="Sort by manual order"
                  ># <span>{sort_indicator(@sort, @sort_direction, "order")}</span></button>
                </th>
                <th scope="col">Picture</th>
                <th scope="col" aria-sort={aria_sort(@sort, @sort_direction, ["albanian", "english"])}>
                  <button
                    id="sort-albanian"
                    class="studio-sort-button"
                    phx-click="sort"
                    phx-value-field="albanian"
                  >Albanian <span>{sort_indicator(@sort, @sort_direction, "albanian")}</span></button>
                  /
                  <button
                    id="sort-english"
                    class="studio-sort-button"
                    phx-click="sort"
                    phx-value-field="english"
                  >English <span>{sort_indicator(@sort, @sort_direction, "english")}</span></button>
                </th>
                <th
                  :for={
                    {field, label} <- [
                      {"topic", "Topic"},
                      {"subtopic", "Sub-topic"},
                      {"level", "Level"}
                    ]
                  }
                  scope="col"
                  aria-sort={aria_sort(@sort, @sort_direction, [field])}
                >
                  <button
                    id={"sort-#{field}"}
                    class="studio-sort-button"
                    phx-click="sort"
                    phx-value-field={field}
                  >{label} <span>{sort_indicator(@sort, @sort_direction, field)}</span></button>
                </th>
                <th scope="col">Quality check</th><th
                  scope="col"
                  title="Successful flashcard PDF downloads"
                >
                  Printed
                </th><th>
                  <span class="sr-only">Actions</span>
                </th>
              </tr>
            </thead><tbody id="vocabulary" phx-update="stream">
              <tr
                :for={{id, card} <- @streams.cards}
                id={id}
                class={MapSet.member?(@selected, to_string(card.id)) && "studio-row-selected"}
              >
                <td class="studio-selection-cell">
                  <span class="studio-select">
                    <.input
                      type="checkbox"
                      id={"print-select-#{card.id}"}
                      name={"print-select-#{card.id}"}
                      checked={MapSet.member?(@selected, to_string(card.id))}
                      disabled={card.status == "archived"}
                      aria-label={"Select #{card.english} for printing"}
                      phx-click="toggle-print"
                      phx-value-id={card.id}
                    />
                  </span>
                </td>
                <td class="studio-order-cell">
                  <span id={"order-#{card.id}"} class="studio-position">{card.sort_order}</span>
                  <div class="studio-move-buttons">
                    <button
                      :for={
                        {direction, icon} <- [
                          {"up", "hero-chevron-up"},
                          {"down", "hero-chevron-down"}
                        ]
                      }
                      id={"move-#{direction}-#{card.id}"}
                      type="button"
                      phx-click="move"
                      phx-value-id={card.id}
                      phx-value-direction={direction}
                      phx-value-position={card.sort_order}
                      phx-value-neighbor={
                        Map.fetch!(@neighbors[card.id], if(direction == "up", do: :up, else: :down))
                      }
                      disabled={
                        !@can_reorder ||
                          is_nil(
                            Map.fetch!(
                              @neighbors[card.id],
                              if(direction == "up", do: :up, else: :down)
                            )
                          )
                      }
                      aria-label={"Move #{card.english} #{direction}"}
                      title={
                        if @can_reorder,
                          do: "Move #{direction}",
                          else: "Choose # ascending and show all cards to rearrange"
                      }
                      phx-disable-with="…"
                    >
                      <.icon name={icon} />
                    </button>
                  </div>
                </td>
                <td class="studio-picture-cell">
                  <img
                    :if={card.image not in [nil, ""]}
                    src={"/images/cards/#{Card.display_image(card.image)}.svg"}
                    alt=""
                  /><span :if={card.image in [nil, ""]} class="word-placeholder">“</span>
                </td>
                <td class="studio-content-cell">
                  <div class="word-cell">
                    <div>
                      <strong lang="sq">{card.albanian}</strong><span>{card.english}</span>
                    </div>
                  </div>
                </td><td class="studio-topic-cell">{card.category}</td><td class="studio-subtopic-cell">
                  {if card.subcategory in [nil, ""], do: "—", else: card.subcategory}
                </td><td class="studio-level-cell">
                  {String.capitalize(card.difficulty)}
                </td><td class="studio-quality-cell">
                  <.form
                    for={@quality_forms[card.id]}
                    id={"quality-form-#{card.id}"}
                    class="studio-quality-form"
                    phx-change="change-quality"
                    phx-submit="save-quality"
                    phx-value-id={card.id}
                  >
                    <div class="studio-quality-flags">
                      <label
                        :for={
                          {field, icon, label} <- [
                            {:quality_language, "hero-language", "Prishtina / less formal wording"},
                            {:quality_image, "hero-photo", "Update, change or add picture"},
                            {:quality_delete, "hero-trash", "Delete"}
                          ]
                        }
                        class="studio-quality-option"
                        title={label}
                      >
                        <input type="hidden" name={@quality_forms[card.id][field].name} value="false" />
                        <.input
                          field={@quality_forms[card.id][field]}
                          type="checkbox"
                          value="true"
                          checked={
                            Phoenix.HTML.Form.normalize_value(
                              "checkbox",
                              @quality_forms[card.id][field].value
                            )
                          }
                        />
                        <.icon name={icon} /><span class="sr-only">{label}</span>
                      </label>
                    </div>
                    <div class="studio-quality-note">
                      <.input
                        field={@quality_forms[card.id][:quality_notes]}
                        aria-label={"Quality check notes for #{card.english}"}
                        placeholder="Quick note…"
                        maxlength="2000"
                      />
                    </div>
                  </.form>
                </td><td
                  class="studio-print-count"
                  id={"print-count-#{card.id}"}
                  data-print-count={card.print_count}
                >
                  <span class={[
                    "pill",
                    if(card.print_count == 0, do: "soft-gray", else: "soft-green")
                  ]}>{if card.print_count == 0, do: "Never", else: "#{card.print_count}×"}</span>
                </td><td class="studio-actions-cell">
                  <button
                    id={"edit-#{card.id}"}
                    class="text-link"
                    phx-click="edit"
                    phx-value-id={card.id}
                  >Edit card <span aria-hidden="true">→</span></button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
        <div :if={@empty} id="cards-empty" class="table-empty">
          No cards match. Try another search, or add a new card.
        </div>
        <p class="studio-count-note">
          Printed counts successful PDF downloads from this update onward, including reprints. Test sheets do not count.
        </p>
      </section>
      <div class="learning-note">
        <.icon name="hero-sparkles" /><p>
          <b>Everyone can make cards.</b>
          Parents and learners share these tools and the same collection. Daily practice introduces up to three new cards.
        </p>
      </div>
      <div
        :if={@print_open}
        class="modal-backdrop"
        id="print-modal"
        role="dialog"
        aria-modal="true"
        aria-labelledby="print-title"
        phx-window-keydown="close"
        phx-key="Escape"
      >
        <section class="modal">
          <div class="modal-heading">
            <div>
              <span class="eyebrow">FROM YOUR CARD STUDIO</span><h2 id="print-title">
                Print flashcards
              </h2>
            </div>
            <button
              id="close-print"
              phx-click="close"
              class="icon-button"
              aria-label="Close print settings"
            ><.icon name="hero-x-mark" /></button>
          </div>
          <p class="editor-note">
            <%= if @albanian_only do %>
              Albanian words and pictures only, ready to print single-sided and cut out.
            <% else %>
              Albanian on the front, English on the back. Choose which side shows the picture, or print Albanian only.
            <% end %>
          </p>
          <p :if={@selected_count == 0} id="print-empty" class="editor-note">
            Select cards using the checkboxes in Card studio.
            <span :if={!@albanian_only}>You can also download a test sheet below.</span>
          </p>
          <details :if={@selected_count > 0} id="print-preview" class="studio-print-preview" open>
            <summary>
              Print order · {@selected_count} {if @selected_count == 1, do: "card", else: "cards"}
            </summary>
            <p>Across each row, then down the page. Includes selected cards hidden by your search.</p>
            <ol id="print-preview-cards" phx-update="stream">
              <li :for={{id, card} <- @streams.print_cards} id={id} data-card-id={card.id}>
                <img
                  :if={card.image not in [nil, ""]}
                  src={"/images/cards/#{Card.display_image(card.image)}.svg"}
                  alt=""
                />
                <div><strong lang="sq">{card.albanian}</strong><span>{card.english}</span></div>
              </li>
            </ol>
          </details>
          <.form
            for={@print_form}
            id="print-download-form"
            action={~p"/cards/print/pdf"}
            method="post"
            target="_blank"
            rel="noopener"
          >
            <.input type="hidden" name="selection" value={@selection_token} />
            <div class="form-grid">
              <.input
                field={@print_form[:sides]}
                phx-change="print-settings"
                type="select"
                label="Sides to print"
                options={[{"Both sides · Albanian & English", "both"}, {"Albanian only", "albanian"}]}
              />
              <.input
                field={@print_form[:per_sheet]}
                phx-change="print-settings"
                type="select"
                label="Cards per sheet · US Letter"
                options={[
                  {"8 cards · 4.25 × 2.75 in", "8"},
                  {"10 cards · 4.25 × 2.2 in", "10"},
                  {"21 cards · 3 × 7 grid", "21"}
                ]}
              />
              <.input
                :if={!@albanian_only}
                field={@print_form[:flip]}
                phx-change="print-settings"
                type="select"
                label="Double-sided printing"
                options={[{"Flip on long edge", "long-edge"}, {"Flip on short edge", "short-edge"}]}
              />
              <.input
                :if={!@albanian_only}
                field={@print_form[:image_side]}
                phx-change="print-settings"
                type="select"
                label="Picture side"
                options={[{"Albanian side (front)", "albanian"}, {"English side (back)", "english"}]}
              />
              <.input
                field={@print_form[:art_style]}
                phx-change="print-settings"
                type="select"
                label="Printer artwork"
                options={[
                  {"Color illustrations · white space", "color"},
                  {"Black outlines · least ink", "outline"},
                  {"Saved card artwork", "original"}
                ]}
              />
            </div>
            <%!-- Keep native expansion and in-progress offsets when live counters/settings update. --%>
            <details
              :if={!@albanian_only}
              class="editor-details"
              id="print-adjustments"
              phx-update="ignore"
            >
              <summary>Adjust back alignment (optional)</summary>
              <p class="muted">
                Positive X moves backs right; positive Y moves them up. Use the same offsets for your test sheet and cards.
              </p>
              <div class="form-grid">
                <.input
                  field={@print_form[:back_x_mm]}
                  phx-change="print-settings"
                  type="number"
                  label="Horizontal (mm)"
                  min="-5"
                  max="5"
                  step="0.1"
                  required
                />
                <.input
                  field={@print_form[:back_y_mm]}
                  phx-change="print-settings"
                  type="number"
                  label="Vertical (mm)"
                  min="-5"
                  max="5"
                  step="0.1"
                  required
                />
              </div>
            </details>
            <div class="studio-print-summary" aria-live="polite">
              <strong>{@selected_count} cards</strong>
              <span id="print-page-count">{@sheet_count} {if @sheet_count == 1,
                do: "sheet",
                else: "sheets"} · {@page_count} PDF {if @page_count == 1, do: "page", else: "pages"}</span>
            </div>
            <p :if={@selected_count > 300} id="print-limit" class="field-error">
              Choose up to 300 cards per PDF.
            </p>
            <div class="studio-print-actions">
              <button
                id="download-cards"
                type="submit"
                name="kind"
                value="cards"
                class="button primary"
                disabled={@selected_count == 0 || @selected_count > 300}
              >
                <.icon name="hero-arrow-down-tray" /> {if @albanian_only,
                  do: "Download Albanian PDF",
                  else: "Download front & back PDF"}
              </button>
              <button
                :if={!@albanian_only}
                id="download-calibration"
                type="submit"
                name="kind"
                value="calibration"
                class="button secondary"
              >Download test sheet</button>
            </div>
          </.form>
          <p id="print-help" class="studio-print-help">
            Print at <b>Actual size / 100%</b>
            <%= if @albanian_only do %>
              on US Letter, single-sided. Cut along the guides between cards.
            <% else %>
              on US Letter, double-sided with your chosen flip setting. Try the numbered test sheet first, then cut along the front guides.
            <% end %>
          </p>
        </section>
      </div>
      <div
        :if={@editing}
        class="modal-backdrop"
        id="card-modal"
        role="dialog"
        aria-modal="true"
        aria-labelledby="editor-title"
        phx-window-keydown="close"
        phx-key="Escape"
      >
        <section class="modal">
          <div class="modal-heading">
            <div>
              <span class="eyebrow">YOUR VOCABULARY</span><h2 id="editor-title">
                {if @editing.id, do: "Edit your card", else: "Add a little language"}
              </h2>
            </div><button
              id="close-editor"
              phx-click="close"
              class="icon-button"
              aria-label="Close editor"
            ><.icon name="hero-x-mark" /></button>
          </div>
          <p class="editor-note">
            {if @editing.status == "archived",
              do:
                "This card is archived. Save changes here, then restore it when you want to practice it.",
              else: "Save once and you’re ready to practice. Reviewing is optional."}
          </p>
          <.form for={@form} id="card-form" phx-change="validate" phx-submit="save">
            <div class="form-grid">
              <.input field={@form[:albanian]} label="Kosovo Albanian" required maxlength="160" /><.input
                field={@form[:english]}
                label="English meaning"
                required
                maxlength="160"
              /><.input
                field={@form[:category]}
                label="Topic"
                placeholder="food, household, conversation…"
                list="topic-suggestions"
                required
                maxlength="50"
              /><.input
                field={@form[:subcategory]}
                label="Sub-topic (optional)"
                placeholder="fruit, rooms, greetings…"
                list="subtopic-suggestions"
                maxlength="50"
              />
              <datalist id="topic-suggestions"><option :for={topic <- @topic_options} value={topic} /></datalist>
              <datalist id="subtopic-suggestions"><option
                :for={
                  subtopic <-
                    Map.get(
                      @subtopics_by_topic,
                      String.downcase(to_string(@form[:category].value)),
                      []
                    )
                }
                value={subtopic}
              /></datalist>
              <.input
                field={@form[:difficulty]}
                label="Level"
                type="select"
                options={[{"Beginner", "beginner"}, {"Growing", "growing"}]}
              /><.input
                field={@form[:image]}
                label="Illustration"
                type="select"
                options={[
                  {"No illustration", ""} | Enum.map(Card.images(), &{String.capitalize(&1), &1})
                ]}
              />
            </div>
            <.input
              field={@form[:notes]}
              label="Notes (optional)"
              type="textarea"
              rows="3"
              maxlength="2000"
            />
            <details class="editor-details">
              <summary>More details (optional)</summary><.input
                field={@form[:concept]}
                label="Stable concept key"
                placeholder="Leave blank to generate a key"
                maxlength="100"
              /><.input field={@form[:source]} label="Source" maxlength="200" />
            </details>
            <button id="save-card" type="submit" class="button primary" phx-disable-with="Saving…">Save card</button>
          </.form>
          <section :if={@editing.id} class="review-panel">
            <div class="saved-preview">
              <span lang="sq">{@editing.albanian}</span><span>↔</span><span>{@editing.english}</span>
            </div><p class="muted">
              Revision {@editing.revision}{if @editing.reviewer,
                do: " · Reviewed by #{@editing.reviewer}"}
            </p>
            <details id="optional-review" class="editor-details">
              <summary>Optional: record a review of the saved wording</summary><p class="muted">
                Save any edits first. This is only a note about who checked the wording; it does not control practice.
              </p><.form for={@review_form} id="review-form" phx-submit="review">
                <.input field={@review_form[:reviewer]} label="Reviewed by" required maxlength="100" /><button
                  id="mark-reviewed"
                  class="button secondary"
                  phx-disable-with="Saving…"
                >Mark saved wording reviewed</button>
              </.form>
            </details>
            <button
              id="archive-card"
              type="button"
              phx-click="set-status"
              phx-value-status={if @editing.status == "archived", do: "active", else: "archived"}
              class="button secondary"
            >{if @editing.status == "archived", do: "Restore card", else: "Archive card"}</button>
            <button
              id="delete-card"
              type="button"
              phx-click="request-delete"
              phx-value-id={@editing.id}
              class="studio-delete"
            >Delete card permanently</button>
          </section>
        </section>
      </div>
      <div
        :if={@import_open}
        class="modal-backdrop"
        id="import-modal"
        role="dialog"
        aria-modal="true"
        aria-labelledby="import-title"
        phx-window-keydown="close"
        phx-key="Escape"
      >
        <section class="modal">
          <div class="modal-heading">
            <div>
              <span class="eyebrow">ROOM FOR MORE WORDS</span><h2 id="import-title">Import cards</h2>
            </div><button phx-click="close" class="icon-button" aria-label="Close import"><.icon name="hero-x-mark" /></button>
          </div><p>
            Paste a reference-project export or a JSON draft. Cards become available immediately. Duplicates are skipped and existing wording is preserved.
          </p><pre class="json-example" phx-no-curly-interpolation>{"cards": [{"concept": "food.apple", "albanian": "mollë", "english": "apple", "category": "food", "source": "AI proposal"}]}</pre><p class="muted">
            Required: concept, albanian, english, category. Optional: subcategory, difficulty (beginner/growing), notes, source, image. New cards append in import order. Maximum 300 cards / 200 KB.
          </p><.form for={@import_form} id="import-form" phx-submit="import">
            <.input
              field={@import_form[:json]}
              label="JSON cards"
              type="textarea"
              rows="10"
              required
              maxlength="200000"
            /><button id="import-submit" class="button primary" phx-disable-with="Importing…">Import cards</button>
          </.form>
        </section>
      </div>
      <div
        :if={@delete_cards != []}
        class="modal-backdrop"
        id="delete-modal"
        role="dialog"
        aria-modal="true"
        aria-labelledby="delete-title"
        phx-window-keydown="cancel-delete"
        phx-key="Escape"
      >
        <section class="modal">
          <div class="modal-heading">
            <h2 id="delete-title">
              Delete {length(@delete_cards)} {if length(@delete_cards) == 1, do: "card", else: "cards"}?
            </h2>
            <button
              id="close-delete"
              type="button"
              phx-click="cancel-delete"
              class="icon-button"
              aria-label="Cancel deletion"
            ><.icon name="hero-x-mark" /></button>
          </div>
          <p>
            This permanently removes these cards and their practice history. Remaining cards keep their sequence and are renumbered. Picture files stay available.
          </p>
          <ul id="delete-preview" phx-update="stream" class="studio-delete-preview">
            <li :for={{id, card} <- @streams.delete_cards} id={id}>
              {card.albanian} / {card.english}
            </li>
          </ul>
          <div class="studio-print-actions">
            <button
              id="cancel-delete"
              type="button"
              phx-click="cancel-delete"
              class="button secondary"
            >Keep cards</button>
            <button
              id="confirm-delete"
              type="button"
              phx-click="delete"
              class="button studio-delete-confirm"
              phx-disable-with="Deleting…"
            >Delete permanently</button>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
