defmodule AlboWeb.ExportController do
  use AlboWeb, :controller

  def index(conn, _) do
    send_download(conn, {:binary, Albo.Learning.export_json()},
      filename: "alboteach-vocabulary.json",
      content_type: "application/json"
    )
  end
end
