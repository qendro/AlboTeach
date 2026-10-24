defmodule Albo.Fixtures do
  def card(attrs \\ %{}) do
    n = System.unique_integer([:positive])

    {:ok, card} =
      Albo.Learning.save_card(
        %Albo.Learning.Card{},
        Map.merge(
          %{
            "concept" => "fixture.item#{n}",
            "albanian" => "Synthetic shqip #{n}",
            "english" => "Synthetic English #{n}",
            "category" => "fixtures",
            "source" => "Software fixture, not linguistic evidence"
          },
          attrs
        ),
        1
      )

    card
  end

  def login(conn, role) do
    Plug.Test.init_test_session(conn, %{
      "role" => role,
      "signed_at" => System.system_time(:second),
      "auth_version" => Albo.Auth.fingerprint(role)
    })
  end
end
