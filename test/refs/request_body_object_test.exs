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
      encoding: "application/yaml"
    )
  end

  use ApicalTest.EndpointCase

  alias Apical.Exceptions.ParameterError
  alias Plug.Conn

  def testPost(conn, params) do
    conn
    |> Conn.put_resp_content_type("application/json")
    |> Conn.send_resp(200, Jason.encode!(params))
  end

  @array ["foo", "bar"]

  def do_post(conn, content) do
    encoded = Jason.encode!(content)
    length = byte_size(encoded)

    conn
    |> Conn.put_req_header("content-type", "application/json")
    |> Conn.put_req_header("content-length", "#{length}")
    |> post("/", Jason.encode!(content))
    |> json_response(200)
  end

  test "POST /", %{conn: conn} do
    assert %{"_json" => @array} = do_post(conn, @array)
  end

  test "failure", %{conn: conn} do
    assert_raise ParameterError,
                 "Parameter Error in operation testPost (in body): value `{\"foo\":\"bar\"}` at `/` fails schema criterion at `#/components/requestBodies/RequestBodyObjectTest/content/application~1json/schema/type`",
                 fn ->
                   do_post(conn, %{"foo" => "bar"})
                 end
  end
end
