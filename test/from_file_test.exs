defmodule ApicalTest.FromFileTest do
  defmodule Router do
    use Phoenix.Router

    require Apical

    Apical.router_from_file(
      "test/_support/from_file_test.yaml",
      root: "/",
      controller: ApicalTest.FromFileTest
    )
  end

  use ApicalTest.EndpointCase
  alias Plug.Conn

  def route(conn, params) do
    conn
    |> Conn.put_resp_header("content-type", "application/json")
    |> Conn.send_resp(200, Jason.encode!(params))
  end

  test "GET /", %{conn: conn} do
    assert %{"number" => 47} =
             conn
             |> get("/47")
             |> json_response(200)
  end

  test "GET errors", %{conn: conn} do
    assert_raise Apical.Exceptions.ParameterError,
                 "Parameter Error in operation route (in path): value `-42` at `/` fails schema criterion at `#/paths/~1%7Bnumber%7D/get/parameters/0/schema/minimum`",
                 fn ->
                   get(conn, "/-42")
                 end
  end
end
