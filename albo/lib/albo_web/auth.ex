defmodule AlboWeb.Auth do
  import Plug.Conn, except: [assign: 3]
  import Phoenix.LiveView
  import Phoenix.Component, only: [assign: 3]
  def init(action), do: action
  def call(conn, :require_login), do: require_login(conn, [])

  def require_login(conn, _) do
    if Albo.Auth.valid?(get_session(conn)),
      do: conn,
      else: conn |> Phoenix.Controller.redirect(to: "/login") |> halt()
  end

  def on_mount(_required, _params, session, socket) do
    if Albo.Auth.valid?(session) do
      socket =
        socket
        |> assign(:role, session["role"])
        |> attach_hook(:session_expiry, :handle_event, fn _event, _params, socket ->
          if Albo.Auth.valid?(session),
            do: {:cont, socket},
            else: {:halt, redirect(socket, to: "/login")}
        end)

      {:cont, socket}
    else
      {:halt, redirect(socket, to: "/login")}
    end
  end
end
