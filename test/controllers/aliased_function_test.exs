defmodule ApicalTest.Controllers.AliasedFunctionTest do
  defmodule Router do
    use Phoenix.Router

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
      root: "/",
      controller: ApicalTest.Controllers.AliasedFunctionTest,
      operation_ids: [testGet: [alias: :aliased]],
      content_type: "application/yaml"
    )
  end

  require ApicalTest.EndpointCase
  ApicalTest.EndpointCase.define_endpoint()

  use ApicalTest.EndpointCase
  alias Plug.Conn

  def aliased(conn, _params) do
    Conn.send_resp(conn, 200, "OK")
  end

  test "GET /", %{conn: conn} do
    assert %{
             resp_body: "OK",
             status: 200
           } = get(conn, "/")
  end
end
