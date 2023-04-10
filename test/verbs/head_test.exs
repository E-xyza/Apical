defmodule ApicalTest.Verbs.HeadTest do
  defmodule Router do
    use Phoenix.Router

    require Apical
    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: TestHead
        version: 1.0.0
      paths:
        "/":
          head:
            operationId: testHead
            responses:
              "200":
                description: OK
      """,
      controller: ApicalTest.Verbs.HeadTest,
      content_type: "application/yaml"
    )
  end

  use ApicalTest.ConnCase
  alias Plug.Conn

  def testHead(conn, _params) do
    Conn.send_resp(conn, 200, "OK")
  end

  test "HEAD /", %{conn: conn} do
    # NB: HEAD requests should not have a response body
    assert %{
      resp_body: "",
      status: 200
    } = head(conn, "/")
  end
end
