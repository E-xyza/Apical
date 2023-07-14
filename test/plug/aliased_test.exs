defmodule ApicalTest.Plug.AliasedTest do
  use ApicalTest.EndpointCase, with: Plug
  alias Plug.Conn

  use Apical.Plug.Controller

  def aliased(conn, _params) do
    Conn.send_resp(conn, 200, "OK")
  end

  test "GET /" do
    assert %{
             status: 200,
             body: "OK"
           } = Req.get!("http://localhost:#{@port}/")
  end
end

defmodule ApicalTest.Plug.AliasedTest.Router do
  use Apical.Plug.Router

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
    operation_ids: [testGet: [alias: :aliased]],
    controller: ApicalTest.Plug.AliasedTest,
    encoding: "application/yaml"
  )
end
