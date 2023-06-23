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
            in: query
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

  alias Apical.Exceptions.ParameterError
  alias Plug.Conn

  for operation <- ~w(parameterGet parameterPost)a do
    def unquote(operation)(conn, params) do
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.send_resp(200, Jason.encode!(params))
    end
  end

  describe "for get route with shared parameter" do
    test "fails when missing parameter", %{conn: conn} do
      assert_raise ParameterError, "", fn ->
        get(conn, "/")
      end
    end

    test "fails when not marshallable", %{conn: conn} do
      assert_raise ParameterError, "Parameter Error in operation parameterGet (in query): value `\"foo\"` at `/` fails schema criterion at `#/components/parameters/ParameterObjectTest/schema/type`", fn ->
        get(conn, "/?required=foo")
      end
    end

    test "works when marshallable", %{conn: conn} do
      assert %{"required" => 47} =
               conn
               |> get("/?required=47")
               |> json_response(200)
    end
  end

  describe "for post route with shared parameter" do
    test "fails when missing parameter", %{conn: conn} do
      assert_raise ParameterError, "", fn ->
        post(conn, "/")
      end
    end

    test "fails when not marshallable", %{conn: conn} do
      assert_raise ParameterError, "Parameter Error in operation parameterPost (in query): value `\"foo\"` at `/` fails schema criterion at `#/components/parameters/ParameterObjectTest/schema/type`", fn ->
        post(conn, "/?required=foo")
      end
    end

    test "works when marshallable", %{conn: conn} do
      assert %{"required" => 47} =
               conn
               |> post("/?required=47")
               |> json_response(200)
    end
  end
end
