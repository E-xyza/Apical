defmodule ApicalTest.Plug.GetPathTest do
  use ApicalTest.EndpointCase, with: Plug
  alias Plug.Conn

  use Apical.Plug.Controller

  def testGet(conn, params) do
    conn
    |> Conn.put_resp_header("content-type", "application/json")
    |> Conn.send_resp(200, Jason.encode!(params))
  end

  test "GET /one/two2" do
    assert %{
             status: 200,
             body: %{
               "one" => "one",
               "two" => "2"
             }
           } = Req.get!("http://localhost:#{@port}/one/two2")
  end
end

defmodule ApicalTest.Plug.GetPathTest.Router do
  use Apical.Plug.Router

  require Apical

  Apical.router_from_string(
    """
    openapi: 3.1.0
    info:
      title: TestGet
      version: 1.0.0
    paths:
      "/{one}/two{two}":
        get:
          operationId: testGet
          responses:
            "200":
              description: OK
    """,
    for: Plug,
    root: "/",
    controller: ApicalTest.Plug.GetPathTest,
    encoding: "application/yaml"
  )
end
