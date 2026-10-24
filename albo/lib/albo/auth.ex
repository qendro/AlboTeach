defmodule Albo.Auth do
  @moduledoc "Separate household and parent passphrases; no child profile or email required."
  def authenticate(role, password) when role in ["learner", "parent"] and is_binary(password) do
    expected = Application.fetch_env!(:albo, :passwords)[role]
    is_binary(expected) && Plug.Crypto.secure_compare(digest(password), digest(expected))
  end

  def authenticate(_, _), do: false

  def password_required?(role),
    do: Application.fetch_env!(:albo, :passwords)[role] not in [nil, ""]

  def fingerprint(role) do
    secret = Application.fetch_env!(:albo, AlboWeb.Endpoint)[:secret_key_base]

    :crypto.mac(:hmac, :sha256, secret, Application.fetch_env!(:albo, :passwords)[role] || "")
    |> Base.url_encode64(padding: false)
  end

  def valid?(%{"role" => role, "signed_at" => timestamp, "auth_version" => version})
      when role in ["learner", "parent"] and is_integer(timestamp) and is_binary(version) do
    age = System.system_time(:second) - timestamp
    age >= 0 && age < 43_200 && Plug.Crypto.secure_compare(version, fingerprint(role))
  end

  def valid?(_), do: false
  defp digest(value), do: :crypto.hash(:sha256, value)
end
