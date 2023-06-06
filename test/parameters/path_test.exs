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
        "/style/default-object/:object":
          get:
            operationId: pathParamDefaultObject
            parameters:
              - name: object
                in: path
                required: true
                schema:
                  type: object
        "/style/matrix-object/:object":
          get:
            operationId: pathParamMatrixObject
            parameters:
              - name: object
                in: path
                required: true
                style: matrix
                schema:
                  type: object
        "/style/matrix-object-explode/:object":
          get:
            operationId: pathParamMatrixObjectExplode
            parameters:
              - name: object
                in: path
                required: true
                style: matrix
                explode: true
                schema:
                  type: object
        "/style/label-object/:object":
          get:
            operationId: pathParamLabelObject
            parameters:
              - name: object
                in: path
                required: true
                style: label
                schema:
                  type: object
        "/style/label-object-explode/:object":
          get:
            operationId: pathParamLabelObjectExplode
            parameters:
              - name: object
                in: path
                required: true
                style: label
                explode: true
                schema:
                  type: object
        "/style/simple-object/:object":
          get:
            operationId: pathParamSimpleObject
            parameters:
              - name: object
                in: path
                required: true
                style: simple
                schema:
                  type: object
        "/style/simple-object-explode/:object":
          get:
            operationId: pathParamSimpleObjectExplode
            parameters:
              - name: object
                in: path
                required: true
                explode: true
                style: simple
                schema:
                  type: object
        "/marshal/array/:array":
          get:
            operationId: pathParamMarshalArray
            parameters:
              - name: array
                in: path
                required: true
                style: simple
                schema:
                  type: array
                  prefixItems:
                    - type: integer
                    - type: string
                  items:
                    type: integer
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
      pathParamLabelArray pathParamSimpleArray pathParamMarshalArray
      pathParamDefaultObject pathParamMatrixObject pathParamMatrixObjectExplode
      pathParamLabelObject pathParamLabelObjectExplode
      pathParamSimpleObject pathParamSimpleObjectExplode)a do
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

    test "matrix fails if you don't have semicolon", %{conn: conn} do
      assert_raise Apical.Exceptions.ParameterError,
                   "Parameter Error in operation pathParamMatrixArray (in path): matrix style `array=foo,bar` for parameter `array` is missing a leading semicolon, use format: `;array=...`",
                   fn ->
                     response = get(conn, "/style/matrix-array/array=foo,bar")
                   end
    end

    test "matrix fails if you don't match name", %{conn: conn} do
      assert_raise Apical.Exceptions.ParameterError,
                   "Parameter Error in operation pathParamMatrixArray (in path): matrix key `value` provided for array named `array`, use format: `;array=...`",
                   fn ->
                     response = get(conn, "/style/matrix-array/;value=foo,bar")
                   end
    end

    test "exploded matrix works", %{conn: conn} do
      response = get(conn, "/style/matrix-array-explode/;array=foo;array=bar")
      assert %{"array" => ["foo", "bar"]} = json_response(response, 200)
    end

    test "exploded matrix fails if any entry don't match name", %{conn: conn} do
      assert_raise Apical.Exceptions.ParameterError,
                   "Parameter Error in operation pathParamMatrixArrayExplode (in path): matrix key `value` provided for array named `array`, use format: `;array=...;array=...`",
                   fn ->
                     response = get(conn, "/style/matrix-array-explode/;array=foo;value=bar")
                   end
    end

    test "label works", %{conn: conn} do
      response = get(conn, "/style/label-array/.foo.bar")

      assert %{"array" => ["foo", "bar"]} = json_response(response, 200)
    end

    test "label errors if you forget the initial dot", %{conn: conn} do
      assert_raise Apical.Exceptions.ParameterError,
                   "Parameter Error in operation pathParamLabelArray (in path): label style `foo.bar` for parameter `array` is missing a leading dot, use format: `.value1.value2.value3...`",
                   fn ->
                     response = get(conn, "/style/label-array/foo.bar")
                   end
    end

    test "simple works", %{conn: conn} do
      response = get(conn, "/style/simple-array/foo,bar")

      assert %{"array" => ["foo", "bar"]} = json_response(response, 200)
    end
  end

  describe "for arrays with inner types" do
    test "marshalling works", %{conn: conn} do
      response = get(conn, "/marshal/array/1,bar,3")

      assert %{"marshal-array" => [1, "bar", 3]} = json_response(response, 200)
    end
  end

  describe "for styled path parameters with object type" do
    test "default works", %{conn: conn} do
      response = get(conn, "/style/default-object/foo,bar")

      assert %{"object" => %{"foo" => "bar"}} = json_response(response, 200)
    end

    test "matrix works", %{conn: conn} do
      response = get(conn, "/style/matrix-object/;object=foo,bar")

      assert %{"object" => %{"foo" => "bar"}} = json_response(response, 200)
    end

    test "matrix fails without semicolon", %{conn: conn} do
      assert_raise Apical.Exceptions.ParameterError,
                   "Parameter Error in operation pathParamMatrixObject (in path): matrix style `object=foo,bar` for parameter `object` is missing a leading semicolon, use format: `;object=...`",
                   fn ->
                     response = get(conn, "/style/matrix-object/object=foo,bar")
                   end
    end

    test "matrix fails if you don't match name", %{conn: conn} do
      assert_raise Apical.Exceptions.ParameterError,
                   "Parameter Error in operation pathParamMatrixObject (in path): matrix key `value` provided for array named `object`, use format: `;object=...`",
                   fn ->
                     response = get(conn, "/style/matrix-object/;value=foo,bar")
                   end
    end

    test "matrix fails if you don't have an even number of params", %{conn: conn} do
      assert_raise Apical.Exceptions.ParameterError,
                   "Parameter Error in operation pathParamMatrixObject (in path): matrix object parameter `;object=foo,bar,baz` for parameter `object` has an odd number of entries",
                   fn ->
                     response = get(conn, "/style/matrix-object/;object=foo,bar,baz")
                   end
    end

    test "matrix exploded works", %{conn: conn} do
      response = get(conn, "/style/matrix-object-explode/;foo=bar;baz=quux")

      assert %{"object" => %{"foo" => "bar", "baz" => "quux"}} = json_response(response, 200)
    end

    test "matrix exploded works with empty string", %{conn: conn} do
      response = get(conn, "/style/matrix-object-explode/;foo=bar;baz=")

      assert %{"object" => %{"foo" => "bar", "baz" => ""}} = json_response(response, 200)
    end

    test "matrix exploded works with empty string with no equals", %{conn: conn} do
      response = get(conn, "/style/matrix-object-explode/;foo=bar;baz")

      assert %{"object" => %{"foo" => "bar", "baz" => ""}} = json_response(response, 200)
    end

    test "label works", %{conn: conn} do
      response = get(conn, "/style/label-object/.foo.bar")

      assert %{"object" => %{"foo" => "bar"}} = json_response(response, 200)
    end

    test "label fails if you don't have an even number of params", %{conn: conn} do
      assert_raise Apical.Exceptions.ParameterError,
                   "Parameter Error in operation pathParamLabelObject (in path): label object parameter `.foo.bar.baz` for parameter `object` has an odd number of entries",
                   fn ->
                     response = get(conn, "/style/label-object/.foo.bar.baz")
                   end
    end

    test "label exploded works", %{conn: conn} do
      response = get(conn, "/style/label-object-explode/.foo=bar.baz=quux")

      assert %{"object" => %{"foo" => "bar", "baz" => "quux"}} = json_response(response, 200)
    end

    test "label exploded fails if you don't have an even number of params", %{conn: conn} do
      assert_raise Apical.Exceptions.ParameterError,
                   "Parameter Error in operation pathParamLabelObjectExplode (in path): label object parameter `.foo=bar=baz` for parameter `object` has a malformed entry: `foo=bar=baz`",
                   fn ->
                     response = get(conn, "/style/label-object-explode/.foo=bar=baz")
                   end
    end

    test "simple works", %{conn: conn} do
      response = get(conn, "/style/simple-object/foo,bar")

      assert %{"object" => %{"foo" => "bar"}} = json_response(response, 200)
    end

    test "simple raises 400 on non-even number of values", %{conn: conn} do
      assert_raise Apical.Exceptions.ParameterError,
                   "Parameter Error in operation pathParamSimpleObject (in path): comma delimited object parameter `foo,bar,baz` for parameter `object` has an odd number of entries",
                   fn ->
                     response = get(conn, "/style/simple-object/foo,bar,baz")
                   end
    end

    test "simple exploded works", %{conn: conn} do
      response = get(conn, "/style/simple-object-explode/foo=bar,baz=quux")

      assert %{"object" => %{"foo" => "bar", "baz" => "quux"}} = json_response(response, 200)
    end

    test "simple exploded raises 400 on malformed values", %{conn: conn} do
      assert_raise Apical.Exceptions.ParameterError,
                   "Parameter Error in operation pathParamSimpleObjectExplode (in path): comma delimited object parameter `foo=bar=baz` for parameter `object` has a malformed entry: `foo=bar=baz`",
                   fn ->
                     response = get(conn, "/style/simple-object-explode/foo=bar=baz")
                   end
    end
  end
end
