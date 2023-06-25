defmodule ApicalTest.Verbs.PostTest do
  defmodule Router do
    use Phoenix.Router

    require Apical

    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: TestPost
        version: 1.0.0
      paths:
        "/":
          post:
            operationId: testPost
            responses:
              "200":
                description: OK
      """,
      root: "/",
      controller: ApicalTest.Verbs.PostTest,
      encoding: "application/yaml"
    )
  end

  use ApicalTest.EndpointCase
  alias Plug.Conn

  def testPost(conn, _params) do
    Conn.send_resp(conn, 200, "OK")
  end

  test "POST /", %{conn: conn} do
    assert %{
             resp_body: "OK",
             status: 200
           } = post(conn, "/")
  end
end
