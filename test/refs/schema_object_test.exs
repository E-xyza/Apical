defmodule ApicalTest.Refs.SchemaObjectTest do
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
        "/via-parameter":
          get:
            operationId: parameterGet
            parameters:
              - $ref: "#/components/parameters/ParameterObjectTest"
        "/direct":
          get:
            operationId: schemaGet
            parameters:
              - name: required
                in: query
                required: true
                schema:
                  $ref: "#/components/schemas/ParameterSchemaTest"
      components:
        parameters:
          ParameterObjectTest:
            name: required
            in: query
            required: true
            schema:
              $ref: "#/components/schemas/ParameterSchemaTest"
        schemas:
          ParameterSchemaTest:
            type: integer
      """,
      root: "/",
      controller: ApicalTest.Refs.SchemaObjectTest,
      content_type: "application/yaml"
    )
  end

  use ApicalTest.EndpointCase

  alias Apical.Exceptions.ParameterError
  alias Plug.Conn

  for operation <- ~w(parameterGet schemaGet)a do
    def unquote(operation)(conn, params) do
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.send_resp(200, Jason.encode!(params))
    end
  end

  describe "getting direct via parameter" do
    test "fails when missing parameter", %{conn: conn} do
      assert_raise ParameterError,
                   "Parameter Error in operation schemaGet (in query): required parameter `required` not present",
                   fn ->
                     get(conn, "/direct")
                   end
    end

    test "fails when not marshallable", %{conn: conn} do
      assert_raise ParameterError,
                   "Parameter Error in operation schemaGet (in query): value `\"foo\"` at `/` fails schema criterion at `#/components/schemas/ParameterSchemaTest/type`.\nref_trace: [\"/paths/~1direct/get/parameters/0/schema/$ref\"]",
                   fn ->
                     get(conn, "/direct/?required=foo")
                   end
    end

    test "works when marshallable", %{conn: conn} do
      assert %{"required" => 47} =
               conn
               |> get("/direct/?required=47")
               |> json_response(200)
    end
  end

  describe "getting indirect via parameter ref" do
    test "fails when missing parameter", %{conn: conn} do
      assert_raise ParameterError,
                   "Parameter Error in operation parameterGet (in query): required parameter `required` not present",
                   fn ->
                     get(conn, "/via-parameter")
                   end
    end

    test "fails when not marshallable", %{conn: conn} do
      assert_raise ParameterError,
                   "Parameter Error in operation parameterGet (in query): value `\"foo\"` at `/` fails schema criterion at `#/components/schemas/ParameterSchemaTest/type`.\nref_trace: [\"/components/parameters/ParameterObjectTest/schema/$ref\"]",
                   fn ->
                     get(conn, "/via-parameter/?required=foo")
                   end
    end

    test "works when marshallable", %{conn: conn} do
      assert %{"required" => 47} =
               conn
               |> get("/via-parameter/?required=47")
               |> json_response(200)
    end
  end
end
