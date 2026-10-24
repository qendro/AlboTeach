defmodule AlboWeb.SessionControllerTest do
  use AlboWeb.ConnCase

  test "sign in, rotate session, and sign out", %{conn: conn} do
    signed = post(conn, "/login", login: %{role: "learner", password: "learner-test-passphrase"})
    assert redirected_to(signed) == "/"
    assert get_session(signed, :role) == "learner"
    signed = recycle(signed) |> get("/")
    assert signed.status == 200
    logged_out = recycle(signed) |> delete("/logout")
    assert redirected_to(logged_out) == "/login"
    assert get_session(logged_out, :role) == nil
  end

  test "configured passphrases are checked and sessions expire", %{conn: conn} do
    response = post(conn, "/login", login: %{role: "parent", password: "learner-test-passphrase"})
    assert redirected_to(response) == "/login?role=parent"
    assert get_session(response, :role) == nil

    refute Albo.Auth.valid?(%{
             "role" => "parent",
             "signed_at" => System.system_time(:second) - 43_201,
             "auth_version" => Albo.Auth.fingerprint("parent")
           })
  end

  test "empty passwords allow one-click entry for both roles without an input", %{conn: conn} do
    previous = Application.fetch_env!(:albo, :passwords)
    Application.put_env(:albo, :passwords, %{"learner" => "", "parent" => ""})
    on_exit(fn -> Application.put_env(:albo, :passwords, previous) end)

    for role <- ["learner", "parent"] do
      page = get(conn, "/login?role=#{role}")
      document = page.resp_body |> LazyHTML.from_document()
      assert document |> LazyHTML.query("#login-password") |> LazyHTML.to_tree() == []
      signed = post(conn, "/login", login: %{role: role})
      assert redirected_to(signed) == if(role == "parent", do: "/cards", else: "/")
      assert get_session(signed, :role) == role
      assert Albo.Auth.valid?(get_session(signed))
    end
  end

  test "sign-in attempts are throttled", %{conn: conn} do
    conn = %{conn | remote_ip: {198, 51, 100, 45}}

    for _ <- 1..10 do
      assert post(conn, "/login", login: %{role: "learner", password: "wrong"}).status == 302
    end

    assert post(conn, "/login", login: %{role: "learner", password: "wrong"}).status == 429
  end
end
