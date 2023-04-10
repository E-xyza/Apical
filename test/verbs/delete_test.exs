defmodule ApicalTest.Verbs.DeleteTest do
  defmodule Router do
    use Phoenix.Router

    require Apical
    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: TestDelete
        version: 1.0.0
      paths:
        "/":
          delete:
            operationId: testDelete
            responses:
              "200":
                description: OK
      """,
      controller: ApicalTest.Verbs.DeleteTest,
      content_type: "application/yaml"
    )
  end

  use ApicalTest.ConnCase
  alias Plug.Conn

  def testDelete(conn, _params) do
    Conn.send_resp(conn, 200, "OK")
  end

  test "DELETE /", %{conn: conn} do
    assert %{
      resp_body: "OK",
      status: 200
    } = delete(conn, "/")
  end
end
