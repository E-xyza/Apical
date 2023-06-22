defmodule ApicalTest.Refs.RequestBodyObjectTest do
  defmodule Router do
    use Phoenix.Router

    require Apical

    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: RequestBodyObjectTest
        version: 1.0.0
      paths:
        "/":
          post:
            operationId: testPost
            requestBody:
              "$ref": "#/components/requestBodies/RequestBodyObjectTest"
      components:
        requestBodies:
          RequestBodyObjectTest:
            content:
              "application/json":
                schema:
                  type: array
      """,
      root: "/",
      controller: ApicalTest.Refs.RequestBodyObjectTest,
      content_type: "application/yaml"
    )
  end

  use ApicalTest.EndpointCase
  alias Plug.Conn

  def testPost(conn, params) do
    conn
    |> Conn.put_resp_content_type("application/json")
    |> Conn.send_resp(200, Jason.encode!(params))
  end

  @array ["foo", "bar"]

  test "POST /", %{conn: conn} do
    assert %{"_json" => @array} =
             conn
             |> Conn.put_req_header("content-type", "application/json")
             |> post("/", Jason.encode!(@array))
             |> json_response(200)
  end

  test "failure", %{conn: conn} do
    assert_raise Foo, "", fn ->
      conn
      |> Conn.put_req_header("content-type", "application/json")
      |> post("/", Jason.encode!(%{"foo" => "bar"}))
    end
  end
end
