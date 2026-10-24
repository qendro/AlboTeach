defmodule AlboWeb.DashboardLive do
  use AlboWeb, :live_view
  alias Albo.Learning

  def mount(_, _, socket) do
    topics = Learning.topics()

    {:ok,
     socket
     |> assign(
       page_title: "My learning",
       stats: Learning.stats(),
       ready: length(Learning.session()),
       topics_empty: topics == []
     )
     |> stream(:topics, topics)}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} role={@role} active="learn">
      <div class="page-heading">
        <div>
          <span class="eyebrow">ONE LITTLE STEP AT A TIME</span><h1>
            Your next words start here<span class="coral">.</span>
          </h1><p>Everyday Albanian, for the people and moments you love.</p>
        </div><span class="pill soft-green">Kosovo Albanian</span>
      </div>
      <section class="hero-panel">
        <div class="hero-copy">
          <span class="eyebrow">A LITTLE PRACTICE, A LOT OF POSSIBILITY</span><h2>
            Little words.<br />Big connections.
          </h2><p>
            Learn a few words. Say them out loud.<br />Bring them into your next family conversation.
          </p><.link navigate="/practice" id="start-practice" class="button dark">{if @ready > 0,
            do: "Let’s practice",
            else: "Check my flashcards"}<.icon name="hero-arrow-right" /></.link><span class="hero-caption">Just a few minutes. Always at your pace.</span>
        </div>
        <div class="hero-art" aria-hidden="true">
          <span class="art-circle"></span><span class="art-star star-one">✦</span><span class="art-star star-two">✦</span><div class="art-card art-back">
            <img src="/images/cards/house.svg" alt="" /><span>At home</span>
          </div><div class="art-card art-front">
            <span class="art-card-label">LITTLE MOMENTS</span><img
              src="/images/cards/apple.svg"
              alt=""
            /><span>Around the table</span><i></i>
          </div><div class="art-sticker">Made for<br /><b>real life.</b></div>
        </div>
      </section>
      <section class="stats-grid" aria-label="Learning progress">
        <div class="stat">
          <span class="stat-icon mint"><.icon name="hero-book-open" /></span><div>
            <strong>{@stats.available}</strong><span>Words to explore</span>
          </div>
        </div>
        <div class="stat">
          <span class="stat-icon peach"><.icon name="hero-check" /></span><div>
            <strong>{@stats.practiced}</strong><span>Practiced today · goal 3</span>
          </div>
        </div>
        <div class="stat">
          <span class="stat-icon lavender"><.icon name="hero-sparkles" /></span><div>
            <strong>{@stats.learned}</strong><span>Words getting familiar</span>
          </div>
        </div>
      </section>
      <div class="section-heading">
        <div>
          <span class="eyebrow">WORDS FOR YOUR WORLD</span><h2>Pick a little corner of life</h2>
        </div><span class="muted">A few new words each day.</span>
      </div>
      <section :if={@topics_empty} class="welcome-empty" id="no-cards">
        <span class="empty-symbol">✦</span><div>
          <h3>Make room for your first words.</h3><p>
            Create a card or import a collection. Your words will be ready to practice right away.
          </p>
          <.link navigate="/cards" class="text-link">Add your cards <span aria-hidden="true">→</span></.link>
        </div>
      </section>
      <section id="topics" class="topic-grid" phx-update="stream">
        <.link
          :for={{id, topic} <- @streams.topics}
          id={id}
          navigate={~p"/practice?topic=#{topic.name}"}
          class={"topic-card #{tone(topic.name)}"}
        ><span class="topic-art"><img src={"/images/cards/#{image(topic.name)}.svg"} alt="" /></span><span class="topic-count">{topic.count} {if topic.count ==
                                                                                                                                                   1,
                                                                                                                                                 do:
                                                                                                                                                   "card",
                                                                                                                                                 else:
                                                                                                                                                   "cards"}</span><h3>
          {title(topic.name)}
        </h3><p>{description(topic.name)}</p><span class="topic-bottom">Explore words
        <.icon name="hero-arrow-right" /></span></.link>
      </section>
      <div class="learning-note">
        <span>✦</span><p>
          <b>A little tip</b>
          Try a word with someone in your family. A real conversation is the best place to practice.
        </p>
      </div>
    </Layouts.app>
    """
  end

  defp image("food"), do: "apple"
  defp image("household"), do: "house"
  defp image(_), do: "book"
  defp tone("food"), do: "peach"
  defp tone("household"), do: "mint"
  defp tone(_), do: "lavender"
  defp title("food"), do: "Around the table"
  defp title("household"), do: "Home, sweet home"
  defp title("conversation"), do: "Let’s talk"
  defp title(value), do: String.capitalize(value)
  defp description("food"), do: "The words that bring us together."
  defp description("household"), do: "Little things in familiar places."
  defp description(_), do: "Make a little more conversation."
end
