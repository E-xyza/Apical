defmodule ApicalTest.Parameters.PathTest do
  defmodule Router do
    use Phoenix.Router

    require Apical

    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: PathTest
        version: 1.0.0
      paths:
        "/required/{required}":
          get:
            operationId: pathParamBasic
            parameters:
              - name: required
                in: path
                required: true
        "/deprecated/{deprecated}":
          get:
            operationId: pathParamDeprecated
            parameters:
              - name: deprecated
                in: path
                required: true
                deprecated: true
        "/partial/base.{extension}":
          get:
            operationId: pathParamPartial
            parameters:
              - name: extension
                in: path
                required: true
        "/style/default-array/:array":
          get:
            operationId: pathParamDefaultArray
            parameters:
              - name: array
                in: path
                required: true
                schema:
                  type: array
        "/style/matrix-array/:array":
          get:
            operationId: pathParamMatrixArray
            parameters:
              - name: array
                in: path
                required: true
                style: matrix
                schema:
                  type: array
        "/style/matrix-array-explode/:array":
          get:
            operationId: pathParamMatrixArrayExplode
            parameters:
              - name: array
                in: path
                required: true
                style: matrix
                explode: true
                schema:
                  type: array
        "/style/label-array/:array":
          get:
            operationId: pathParamLabelArray
            parameters:
              - name: array
                in: path
                required: true
                style: label
                schema:
                  type: array
        "/style/simple-array/:array":
          get:
            operationId: pathParamSimpleArray
            parameters:
              - name: array
                in: path
                required: true
                style: simple
                schema:
                  type: array
      """,
      controller: ApicalTest.Parameters.PathTest,
      content_type: "application/yaml",
      styles: [{"x-custom", {__MODULE__, :x_custom}}],
      dump: true
    )

    def x_custom("foo"), do: 47
  end

  use ApicalTest.ConnCase
  alias Plug.Conn
  alias Apical.Exceptions.ParameterError

  for ops <- ~w(pathParamBasic pathParamDeprecated pathParamPartial
      pathParamDefaultArray pathParamMatrixArray pathParamMatrixArrayExplode
      pathParamLabelArray pathParamSimpleArray)a do
    def unquote(ops)(conn, params) do
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.send_resp(200, Jason.encode!(params))
    end
  end

  test "for path, when not required, causes compilation error"

  describe "for a path parameter" do
    test "it serializes as expected", %{conn: conn} do
      assert %{"required" => "foo"} = json_response(get(conn, "/required/foo"), 200)
    end

    test "it fails (with 404) when not present", %{conn: conn} do
      assert_raise Phoenix.Router.NoRouteError, fn ->
        get(conn, "/required/")
      end
    end
  end

  describe "for a deprecated path parameter" do
    test "it returns a 299 header", %{conn: conn} do
      response = get(conn, "/deprecated/deprecated")

      assert {"warning", "299 - the path parameter `deprecated` is deprecated."} =
               List.keyfind(response.resp_headers, "warning", 0)

      assert %{"deprecated" => "deprecated"} = json_response(response, 200)
    end
  end

  describe "for a partial path parameter" do
    test "it serializes as expected", %{conn: conn} do
      assert %{"extension" => "txt"} == json_response(get(conn, "/partial/base.txt"), 200)
    end
  end

  describe "for styled path parameters with array type" do
    test "default works", %{conn: conn} do
      response = get(conn, "/style/default-array/foo,bar")

      assert %{"array" => ["foo", "bar"]} = json_response(response, 200)
    end

    test "matrix works", %{conn: conn} do
      response = get(conn, "/style/matrix-array/;array=foo,bar")

      assert %{"array" => ["foo", "bar"]} = json_response(response, 200)
    end

    test "matrix fails if you don't match name", %{conn: conn} do
      assert_raise Apical.Exceptions.ParameterError,
                   "Parameter Error in operation pathParamMatrixArray (in path): matrix key `value` provided for array named `array`, use format: `;array=...`",
                   fn ->
                     response = get(conn, "/style/matrix-array/;value=foo,bar")
                   end
    end

    test "matrix works when exploded", %{conn: conn} do
      response = get(conn, "/style/matrix-array-explode/;array=foo;array=bar")
      assert %{"array" => ["foo", "bar"]} = json_response(response, 200)
    end

    test "label works", %{conn: conn} do
      response = get(conn, "/style/label-array/.foo.bar")

      assert %{"array" => ["foo", "bar"]} = json_response(response, 200)
    end

    test "simple works", %{conn: conn} do
      response = get(conn, "/style/simple-array/foo,bar")

      assert %{"array" => ["foo", "bar"]} = json_response(response, 200)
    end
  end
end
