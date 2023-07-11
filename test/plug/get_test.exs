defmodule ApicalTest.Plug.GetTest do
  defmodule Router do
    require Apical

    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: TestGet
        version: 1.0.0
      paths:
        "/":
          get:
            operationId: testGet
            responses:
              "200":
                description: OK
      """,
      for: Plug,
      root: "/",
      controller: ApicalTest.Verbs.GetTest,
      encoding: "application/yaml"
    )
  end

  use ApicalTest.EndpointCase, with: Plug
  alias Plug.Conn

  def testGet(conn, _params) do
    Conn.send_resp(conn, 200, "OK")
  end

  test "GET /", %{conn: conn} do
    Req.get!("http://localhost:#{@port}/") |> dbg(limit: 25)
  end
end
