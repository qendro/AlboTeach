defmodule AlboWeb.PracticeLive do
  use AlboWeb, :live_view
  alias Albo.Learning
  alias Albo.Learning.Card

  def mount(params, _, socket) do
    topic = Map.get(params, "topic", "all")
    difficulty = Map.get(params, "difficulty", "all")
    mode = if params["mode"] == "daily", do: :daily, else: :all

    cards =
      if mode == :daily,
        do: Learning.session(topic, difficulty),
        else: Learning.flashcards(topic, difficulty)

    {:ok,
     socket
     |> assign(
       page_title: "Flashcards",
       queue: cards,
       total: length(cards),
       completed: 0,
       skipped: 0,
       remembered: 0,
       revealed: false,
       started: false,
       topic: topic,
       mode: mode,
       difficulty: difficulty,
       filter_form:
         to_form(%{"topic" => topic, "difficulty" => difficulty, "mode" => Atom.to_string(mode)},
           as: :filters
         ),
       topic_options: [
         {"All topics", "all"}
         | Enum.map(Learning.topics(), &{String.capitalize(&1.name), &1.name})
       ]
     )
     |> next_attempt()}
  end

  def handle_event("filter", %{"filters" => params}, socket) do
    {:noreply,
     push_navigate(socket,
       to:
         ~p"/practice?topic=#{params["topic"]}&difficulty=#{params["difficulty"]}&mode=#{params["mode"]}"
     )}
  end

  def handle_event("reveal", _, %{assigns: %{queue: [card | _]}} = socket) do
    if Learning.current?(card),
      do: {:noreply, assign(socket, revealed: true, started: true)},
      else:
        {:noreply,
         socket
         |> put_flash(:info, "This card was updated. Let’s get your latest cards.")
         |> push_navigate(to: "/practice")}
  end

  def handle_event(
        "next",
        %{"attempt" => attempt},
        %{assigns: %{queue: [_card | rest], attempt: attempt}} = socket
      ) do
    {:noreply,
     socket
     |> assign(queue: rest, revealed: false, skipped: socket.assigns.skipped + 1)
     |> next_attempt()}
  end

  def handle_event("hide-answer", _, socket), do: {:noreply, assign(socket, revealed: false)}

  def handle_event("restart", _, %{assigns: %{mode: :all}} = socket) do
    cards = Learning.flashcards(socket.assigns.topic, socket.assigns.difficulty)

    {:noreply,
     socket
     |> assign(
       queue: cards,
       total: length(cards),
       completed: 0,
       skipped: 0,
       remembered: 0,
       revealed: false
     )
     |> next_attempt()}
  end

  def handle_event(
        "grade",
        %{"result" => result, "attempt" => attempt},
        %{assigns: %{revealed: true, queue: [card | rest], attempt: attempt}} = socket
      )
      when result in ["again", "remembered"] do
    case Learning.grade(
           card.id,
           card.revision,
           result,
           attempt,
           DateTime.utc_now(),
           socket.assigns.mode
         ) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(
           queue: rest,
           revealed: false,
           completed: socket.assigns.completed + 1,
           remembered: socket.assigns.remembered + if(result == "remembered", do: 1, else: 0)
         )
         |> next_attempt()}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           "Your cards have changed or today’s new words are complete. Your saved progress is safe."
         )
         |> push_navigate(to: "/practice")}
    end
  end

  def handle_event(_, _, socket), do: {:noreply, socket}

  defp next_attempt(socket),
    do: assign(socket, attempt: Base.url_encode64(:crypto.strong_rand_bytes(18), padding: false))

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} role={@role} active="practice">
      <div class="page-heading">
        <div>
          <span class="eyebrow">A FEW MINUTES FOR YOU</span><h1>
            Make a little progress<span class="coral">.</span>
          </h1><p>Explore every card, or choose a shorter daily practice.</p>
        </div><.link navigate="/" class="text-link">Back to my learning</.link>
      </div>
      <.form for={@filter_form} id="practice-filters" phx-change="filter" class="filter-row">
        <.input
          field={@filter_form[:mode]}
          type="select"
          label="Cards"
          options={[{"All cards", "all"}, {"Daily practice", "daily"}]}
        />
        <.input field={@filter_form[:topic]} type="select" label="Topic" options={@topic_options} /><.input
          field={@filter_form[:difficulty]}
          type="select"
          label="Level"
          options={[{"All levels", "all"}, {"Beginner", "beginner"}, {"Growing", "growing"}]}
        />
      </.form>
      <p id="practice-mode-note" class="muted">
        {if @mode == :all,
          do:
            "Showing every active card that matches your filters, including cards you’ve practiced before.",
          else: "A short session of due reviews and up to 3 new cards today."}
      </p>
      <.link
        :if={@topic != "all" || @difficulty != "all" || @mode != :all}
        navigate="/practice"
        id="show-all-cards"
        class="text-link"
      >Show all cards</.link>
      <%= if @queue != [] do %>
        <% card = hd(@queue) %>
        <section class="practice-area" aria-label="Practice session">
          <div class="session-progress">
            <span id="card-counter">Card {@completed + @skipped + 1} of {@total}</span><span>Little by little, you’ve got this.</span>
          </div>
          <progress value={@completed + @skipped} max={@total} aria-label="Session progress"></progress>
          <div class={["flashcard", @revealed && "is-revealed"]} id="practice-card" aria-live="polite">
            <span class="pill soft-green">{String.capitalize(card.category)} · {String.capitalize(
              card.difficulty
            )}</span>
            <img
              :if={card.image not in [nil, ""]}
              src={"/images/cards/#{Card.display_image(card.image)}.svg"}
              alt=""
              class="flashcard-image"
            />
            <span :if={card.image in [nil, ""]} class="phrase-art" aria-hidden="true">“ ”</span>
            <span class="eyebrow">{if @revealed, do: "IN ALBANIAN", else: "HOW DO YOU SAY…"}</span>
            <h2 id="card-word" lang={if @revealed, do: "sq", else: "en"}>
              {if @revealed, do: card.albanian, else: card.english}
            </h2>
            <p :if={@revealed} class="translation">{card.english}</p>
            <p :if={!@revealed} class="card-prompt">Take your time. Try saying it out loud.</p>
            <button :if={!@revealed} id="reveal-card" phx-click="reveal" class="button primary">Turn the card
            <.icon name="hero-arrow-path" /></button>
            <button
              :if={@revealed}
              id="flip-back"
              type="button"
              phx-click="hide-answer"
              class="button secondary"
            >Turn card back <.icon name="hero-arrow-path" /></button>
            <p :if={@revealed} class="card-prompt">Say it once more. How did that feel?</p>
          </div>
          <div :if={@revealed} class="grade-buttons">
            <button
              id="grade-again"
              phx-click="grade"
              phx-value-result="again"
              phx-value-attempt={@attempt}
              phx-disable-with="Saving…"
              class="button secondary"
            ><.icon name="hero-arrow-path" /> Still learning</button><button
              id="grade-remembered"
              phx-click="grade"
              phx-value-result="remembered"
              phx-value-attempt={@attempt}
              phx-disable-with="Saving…"
              class="button primary"
            ><.icon name="hero-check" /> I remembered!</button>
          </div>
          <div class="next-card-row">
            <button
              id="next-card"
              type="button"
              phx-click="next"
              phx-value-attempt={@attempt}
              class="button secondary"
            >Next card <.icon name="hero-arrow-right" /></button><span>Skip without recording an answer.</span>
          </div>
          <p :if={@revealed} class="session-hint">
            Choose “Still learning” or “I remembered!” to save your answer and move to the next card.
          </p>
          <p class="session-hint">No rush. No scores to beat. Just a little more Albanian.</p>
        </section>
      <% else %>
        <section class="session-complete" id="session-complete">
          <span class="celebration">✦</span><span class="eyebrow">{if @completed > 0,
            do: "THAT’S A LITTLE WIN",
            else: "ALL AT YOUR OWN PACE"}</span><h2>
            {if @completed > 0, do: "A little closer, already.", else: "Your next words can wait."}
          </h2><p>
            {cond do
              @completed > 0 ->
                "You practiced #{@completed} cards and remembered #{@remembered}. Try one with your family today!"

              @skipped > 0 ->
                "You skipped #{@skipped} cards without recording answers. You can practice them again whenever you’re ready."

              @mode == :all ->
                "No cards match these filters. Choose All topics and All levels, or add cards in Card studio."

              true ->
                "No cards are due in this topic right now. Add cards in Card studio, try another topic, or come back when your next practice is due."
            end}
          </p><button
            :if={@mode == :all && @total > 0}
            id="restart-cards"
            type="button"
            phx-click="restart"
            class="button primary"
          >Start again <.icon name="hero-arrow-path" /></button><.link
            navigate="/"
            class="button secondary"
          >Back to my learning <.icon name="hero-arrow-right" /></.link><p
            :if={@mode == :daily}
            class="session-hint"
          >
            New words arrive gently: up to 3 per day. “Still learning” cards return after 10 minutes.
          </p>
        </section>
      <% end %>
    </Layouts.app>
    """
  end
end
