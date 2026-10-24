defmodule AlboWeb.Router do
  use AlboWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {AlboWeb.Layouts, :root}
    plug :protect_from_forgery

    plug :put_secure_browser_headers, %{
      "content-security-policy" =>
        "default-src 'self'; img-src 'self' data:; style-src 'self' 'unsafe-inline'; script-src 'self'; connect-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'",
      "referrer-policy" => "same-origin",
      "permissions-policy" => "camera=(), microphone=(), geolocation=()",
      "cache-control" => "no-store"
    }
  end

  pipeline :authenticated do
    plug AlboWeb.Auth, :require_login
  end

  scope "/", AlboWeb do
    get "/health", HealthController, :index
  end

  scope "/", AlboWeb do
    pipe_through :browser
    get "/login", SessionController, :new
    post "/login", SessionController, :create
    delete "/logout", SessionController, :delete
  end

  scope "/", AlboWeb do
    pipe_through [:browser, :authenticated]

    get "/cards/export", ExportController, :index
    post "/cards/print/pdf", PrintController, :create
    get "/cards/print", PrintController, :index
    get "/parent/export", ExportController, :index

    live_session :family, on_mount: [{AlboWeb.Auth, :learner}] do
      live "/", DashboardLive
      live "/practice", PracticeLive
      live "/cards", ParentLive
      live "/parent", ParentLive
    end
  end
end
