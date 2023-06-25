defmodule ApicalTest.Verbs.OptionsTest do
  defmodule Router do
    use Phoenix.Router

    require Apical

    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: TestOptions
        version: 1.0.0
      paths:
        "/":
          options:
            operationId: testOptions
            responses:
              "200":
                description: OK
      """,
      root: "/",
      controller: ApicalTest.Verbs.OptionsTest,
      encoding: "application/yaml"
    )
  end

  use ApicalTest.EndpointCase
  alias Plug.Conn

  def testOptions(conn, _params) do
    Conn.send_resp(conn, 200, "OK")
  end

  test "OPTIONS /", %{conn: conn} do
    assert %{
             resp_body: "OK",
             status: 200
           } = options(conn, "/")
  end
end
