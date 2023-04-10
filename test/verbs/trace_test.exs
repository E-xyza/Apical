defmodule ApicalTest.Verbs.TraceTest do
  defmodule Router do
    use Phoenix.Router

    require Apical
    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: TestTrace
        version: 1.0.0
      paths:
        "/":
          trace:
            operationId: testTrace
            responses:
              "200":
                description: OK
      """,
      controller: ApicalTest.Verbs.TraceTest,
      content_type: "application/yaml"
    )
  end

  use ApicalTest.ConnCase
  alias Plug.Conn

  def testTrace(conn, _params) do
    Conn.send_resp(conn, 200, "OK")
  end

  test "TRACE /", %{conn: conn} do
    assert %{
      resp_body: "OK",
      status: 200
    } = trace(conn, "/")
  end
end
