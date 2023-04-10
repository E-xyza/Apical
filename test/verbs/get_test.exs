defmodule ApicalTest.Verbs.GetTest do
  use ApicalTest.ConnCase
  use Phoenix.Router

  test "GET /", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "OK"
  end
end
