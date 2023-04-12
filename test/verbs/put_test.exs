defmodule ApicalTest.Verbs.PutTest do
  defmodule Router do
    use Phoenix.Router

    require Apical

    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: TestPut
        version: 1.0.0
      paths:
        "/":
          put:
            operationId: testPut
            responses:
              "200":
                description: OK
      """,
      controller: ApicalTest.Verbs.PutTest,
      content_type: "application/yaml"
    )
  end

  use ApicalTest.ConnCase
  alias Plug.Conn

  def testPut(conn, _params) do
    Conn.send_resp(conn, 200, "OK")
  end

  test "PUT /", %{conn: conn} do
    assert %{
             resp_body: "OK",
             status: 200
           } = put(conn, "/")
  end
end
