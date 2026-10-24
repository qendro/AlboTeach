defmodule AlboWeb.HealthController do
  use AlboWeb, :controller

  def index(conn, _) do
    case Ecto.Adapters.SQL.query(Albo.Repo, "SELECT 1", []) do
      {:ok, _} -> json(conn, %{status: "ok"})
      {:error, _} -> conn |> put_status(:service_unavailable) |> json(%{status: "unavailable"})
    end
  end
end
