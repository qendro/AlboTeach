defmodule AlboWeb.SessionController do
  use AlboWeb, :controller

  def new(conn, params) do
    role = if params["role"] == "parent", do: "parent", else: "learner"

    render(conn, :new,
      form: Phoenix.Component.to_form(%{"role" => role}, as: :login),
      role: role,
      password_required: Albo.Auth.password_required?(role)
    )
  end

  def create(conn, %{"login" => params}) do
    if !Albo.Auth.password_required?(params["role"]) || Albo.LoginLimiter.allow?(conn.remote_ip) do
      if Albo.Auth.authenticate(params["role"], Map.get(params, "password", "")) do
        role = params["role"]

        conn
        |> configure_session(renew: true)
        |> clear_session()
        |> put_session(:role, role)
        |> put_session(:signed_at, System.system_time(:second))
        |> put_session(:auth_version, Albo.Auth.fingerprint(role))
        |> redirect(to: if(role == "parent", do: "/cards", else: "/"))
      else
        conn
        |> put_flash(:error, "That passphrase didn’t match. Please try again.")
        |> redirect(to: if(params["role"] == "parent", do: "/login?role=parent", else: "/login"))
      end
    else
      conn
      |> put_status(:too_many_requests)
      |> text("Too many attempts. Please wait a minute and try again.")
    end
  end

  def create(conn, _), do: conn |> put_status(:bad_request) |> text("Invalid sign-in form")

  def delete(conn, _),
    do: conn |> clear_session() |> configure_session(drop: true) |> redirect(to: "/login")
end
