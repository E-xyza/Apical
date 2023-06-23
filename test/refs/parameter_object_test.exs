defmodule ApicalTest.Refs.ParameterObjectTest do
  defmodule Router do
    use Phoenix.Router

    require Apical

    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: ParameterObjectTest
        version: 1.0.0
      paths:
        "/":
          get:
            operationId: parameterGet
            parameters:
              - $ref: "#/components/parameters/ParameterObjectTest"
          post:
            operationId: parameterPost
            parameters:
              - $ref: "#/components/parameters/ParameterObjectTest"
      components:
        parameters:
          ParameterObjectTest:
            name: required
            in: path
            required: true
            schema:
              type: integer
      """,
      root: "/",
      controller: ApicalTest.Refs.ParameterObjectTest,
      content_type: "application/yaml"
    )
  end

  use ApicalTest.EndpointCase
  alias Plug.Conn

  for operation <- ~w(parameterGet parameterPost)a do
    def unquote(operation)(conn, param) do
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.send_resp(200, Jason.encode!(params))
    end
  end

  describe "for get route with shared parameter" do
    test "fails when missing parameter", %{conn: conn} do
      assert_raise Foo, fn ->
        get(conn, "/")
      end
    end

    test "fails when not marshallable", %{conn: conn} do
      assert_raise Foo, fn ->
        get(conn, "/?required=foo")
      end
    end

    test "works when marshallable", %{conn: conn} do
      assert %{"required" => 47} = conn
      |> get("/?required=47")
      |> json_response(200)
    end
  end

  describe "for post route with shared parameter" do
    test "fails when missing parameter", %{conn: conn} do
      assert_raise Foo, fn ->
        post(conn, "/")
      end
    end

    test "fails when not marshallable", %{conn: conn} do
      assert_raise Foo, fn ->
        post(conn, "/?required=foo")
      end
    end


    test "works when marshallable", %{conn: conn} do
      assert %{"required" => 47} = conn
      |> post("/?required=47")
      |> json_response(200)
    end
  end
end
