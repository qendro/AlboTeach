defmodule AlboWeb.Layouts do
  use AlboWeb, :html
  embed_templates "layouts/*"
  attr :flash, :map, required: true
  attr :role, :string, default: nil
  attr :active, :string, default: "learn"
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="app-shell">
      <aside class="sidebar">
        <a href="/" class="brand"><span class="brand-mark"><.icon name="hero-sparkles" /></span><span>Albo<span class="brand-light">Teach</span><small>A little closer to home.</small></span></a>
        <p class="nav-label">YOUR SPACE</p>
        <nav aria-label="Main navigation">
          <.link navigate="/" class={["nav-item", @active == "learn" && "active"]}><.icon name="hero-squares-2x2" />
          My learning</.link>
          <.link navigate="/practice" class={["nav-item", @active == "practice" && "active"]}><.icon name="hero-book-open" />
          Flashcards</.link>
          <.link
            navigate="/cards"
            class={["nav-item", @active == "parent" && "active"]}
          ><.icon name="hero-adjustments-horizontal" /> Card studio</.link>
        </nav>
        <div class="sidebar-note">
          <span class="tiny-star">✦</span><h3>Made for real life.</h3><p>
            Small steps today.<br />More to say with family tomorrow.
          </p><span class="note-line"></span>
        </div>
        <div class="sidebar-bottom">
          <span class="private"><.icon name="hero-lock-closed" /> Your family’s space</span><.link
            href="/logout"
            method="delete"
            class="signout"
          >Sign out</.link>
        </div>
      </aside>
      <div class="workspace">
        <header class="topbar">
          <span>LEARN A LITTLE. CONNECT A LOT.</span><div class="profile">
            <span class="status-dot"></span>{if @role == "parent",
              do: "Parent space",
              else: "Let’s learn together"}<span class="avatar">{if @role == "parent",
              do: "P",
              else: "L"}</span>
            <.link href="/logout" method="delete" class="mobile-signout">Sign out</.link>
          </div>
        </header>
        <main id="main-content">{render_slot(@inner_block)}</main>
        <footer class="footer">
          <span>Made for conversations that matter.</span><a
            href="/images/cards/credits.json"
            target="_blank"
            rel="noopener"
          >Illustration credits · Microsoft, Twemoji, Lucide &amp; AlboTeach</a>
        </footer>
      </div>
    </div>
    <.flash_group flash={@flash} />
    """
  end

  attr :flash, :map, required: true

  def flash_group(assigns) do
    ~H"""
    <div class="flash-stack" aria-live="polite">
      <div
        :for={kind <- [:info, :error]}
        :if={Phoenix.Flash.get(@flash, kind)}
        class={["flash", kind == :error && "error"]}
        role="alert"
      >
        {Phoenix.Flash.get(@flash, kind)}
        <button
          type="button"
          phx-click="lv:clear-flash"
          phx-value-key={kind}
          aria-label="Dismiss message"
          class="flash-close"
        ><.icon name="hero-x-mark" /></button>
      </div>
    </div>
    <div id="connection-status" class="connection-status" role="status">
      Connection lost. Reconnecting… Your saved progress is safe.
    </div>
    """
  end
end
