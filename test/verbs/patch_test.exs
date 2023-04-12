defmodule ApicalTest.Verbs.PatchTest do
  defmodule Router do
    use Phoenix.Router

    require Apical

    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: TestPatch
        version: 1.0.0
      paths:
        "/":
          patch:
            operationId: testPatch
            responses:
              "200":
                description: OK
      """,
      controller: ApicalTest.Verbs.PatchTest,
      content_type: "application/yaml"
    )
  end

  use ApicalTest.ConnCase
  alias Plug.Conn

  def testPatch(conn, _params) do
    Conn.send_resp(conn, 200, "OK")
  end

  test "PATCH /", %{conn: conn} do
    assert %{
             resp_body: "OK",
             status: 200
           } = patch(conn, "/")
  end
end
