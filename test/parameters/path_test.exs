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
        "/style/default-array/{array}":
          get:
            operationId: pathParamDefaultArray
            parameters:
              - name: array
                in: path
                required: true
                schema:
                  type: array
        "/style/matrix-array/{array}":
          get:
            operationId: pathParamMatrixArray
            parameters:
              - name: array
                in: path
                required: true
                style: matrix
                schema:
                  type: array
        "/style/matrix-array-explode/{array}":
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
        "/style/label-array/{array}":
          get:
            operationId: pathParamLabelArray
            parameters:
              - name: array
                in: path
                required: true
                style: label
                schema:
                  type: array
        "/style/simple-array/{array}":
          get:
            operationId: pathParamSimpleArray
            parameters:
              - name: array
                in: path
                required: true
                style: simple
                schema:
                  type: array
        "/style/default-object/{object}":
          get:
            operationId: pathParamDefaultObject
            parameters:
              - name: object
                in: path
                required: true
                schema:
                  type: object
        "/style/matrix-object/{object}":
          get:
            operationId: pathParamMatrixObject
            parameters:
              - name: object
                in: path
                required: true
                style: matrix
                schema:
                  type: object
        "/style/matrix-object-explode/{object}":
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
        "/style/label-object/{object}":
          get:
            operationId: pathParamLabelObject
            parameters:
              - name: object
                in: path
                required: true
                style: label
                schema:
                  type: object
        "/style/label-object-explode/{object}":
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
        "/style/simple-object/{object}":
          get:
            operationId: pathParamSimpleObject
            parameters:
              - name: object
                in: path
                required: true
                style: simple
                schema:
                  type: object
        "/style/simple-object-explode/{object}":
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
        "/marshal/array/{array}":
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
        "/marshal/object/{object}":
          get:
            operationId: pathParamMarshalObject
            parameters:
              - name: object
                in: path
                required: true
                schema:
                  type: object
                  properties:
                    foo:
                      type: integer
                  patternProperties:
                    "^b.*":
                      type: boolean
                  additionalProperties:
                    type: integer
        "/marshal/boolean/{boolean}":
          get:
            operationId: pathParamMarshalBoolean
            parameters:
              - name: boolean
                in: path
                required: true
                schema:
                  type: boolean
        "/style/boolean-matrix/{boolean}":
          get:
            operationId: pathParamBooleanMatrix
            parameters:
              - name: boolean
                in: path
                required: true
                style: matrix
                schema:
                  type: boolean
        "/style/boolean-label/{boolean}":
          get:
            operationId: pathParamBooleanLabel
            parameters:
              - name: boolean
                in: path
                required: true
                style: label
                schema:
                  type: boolean
        "/marshal/number/{number}":
          get:
            operationId: pathParamNumber
            parameters:
              - name: number
                in: path
                required: true
                schema:
                  type: number
        "/marshal/multitype/{multitype}":
          get:
            operationId: pathParamMultitype
            parameters:
              - name: multitype
                in: path
                required: true
                schema:
                  type: [integer, number, string, "null", boolean]
        "/marshal/nullablearray/{array}":
          get:
            operationId: pathParamNullableArray
            parameters:
              - name: array
                in: path
                required: true
                style: matrix
                schema:
                  type: ["null", array]
        "/marshal/nullableobject/{object}":
          get:
            operationId: pathParamNullableObject
            parameters:
              - name: object
                in: path
                required: true
                style: matrix
                schema:
                  type: ["null", object]
      """,
      root: "/",
      controller: ApicalTest.Parameters.PathTest,
      content_type: "application/yaml",
      styles: [{"x-custom", {__MODULE__, :x_custom}}]
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
      pathParamSimpleObject pathParamSimpleObjectExplode
      pathParamMarshalObject pathParamMarshalBoolean pathParamBooleanMatrix pathParamBooleanLabel
      pathParamNumber pathParamMultitype pathParamNullableArray pathParamNullableObject
    )a do
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
      assert %{"array" => ["foo", "bar"]} =
               conn
               |> get("/style/default-array/foo,bar")
               |> json_response(200)
    end

    test "matrix works", %{conn: conn} do
      assert %{"array" => ["foo", "bar"]} =
               conn
               |> get("/style/matrix-array/;array=foo,bar")
               |> json_response(200)
    end

    test "matrix fails if you don't have semicolon", %{conn: conn} do
      assert_raise Apical.Exceptions.ParameterError,
                   "Parameter Error in operation pathParamMatrixArray (in path): matrix style `array=foo,bar` for parameter `array` is missing a leading semicolon, use format: `;array=...`",
                   fn ->
                     get(conn, "/style/matrix-array/array=foo,bar")
                   end
    end

    test "matrix fails if you don't match name", %{conn: conn} do
      assert_raise Apical.Exceptions.ParameterError,
                   "Parameter Error in operation pathParamMatrixArray (in path): matrix key `value` provided for array named `array`, use format: `;array=...`",
                   fn ->
                     get(conn, "/style/matrix-array/;value=foo,bar")
                   end
    end

    test "exploded matrix works", %{conn: conn} do
      assert %{"array" => ["foo", "bar"]} =
               conn
               |> get("/style/matrix-array-explode/;array=foo;array=bar")
               |> json_response(200)
    end

    test "exploded matrix fails if any entry don't match name", %{conn: conn} do
      assert_raise Apical.Exceptions.ParameterError,
                   "Parameter Error in operation pathParamMatrixArrayExplode (in path): matrix key `value` provided for array named `array`, use format: `;array=...;array=...`",
                   fn ->
                     get(conn, "/style/matrix-array-explode/;array=foo;value=bar")
                   end
    end

    test "label works", %{conn: conn} do
      assert %{"array" => ["foo", "bar"]} =
               conn
               |> get("/style/label-array/.foo.bar")
               |> json_response(200)
    end

    test "label errors if you forget the initial dot", %{conn: conn} do
      assert_raise Apical.Exceptions.ParameterError,
                   "Parameter Error in operation pathParamLabelArray (in path): label style `foo.bar` for parameter `array` is missing a leading dot, use format: `.value1.value2.value3...`",
                   fn ->
                     get(conn, "/style/label-array/foo.bar")
                   end
    end

    test "simple works", %{conn: conn} do
      assert %{"array" => ["foo", "bar"]} =
               conn
               |> get("/style/simple-array/foo,bar")
               |> json_response(200)
    end
  end

  describe "for arrays with inner types" do
    test "marshalling works", %{conn: conn} do
      assert %{"array" => [1, "bar", 3]} =
               conn
               |> get("/marshal/array/1,bar,3")
               |> json_response(200)
    end
  end

  describe "for styled path parameters with object type" do
    test "default works", %{conn: conn} do
      assert %{"object" => %{"foo" => "bar"}} =
               conn
               |> get("/style/default-object/foo,bar")
               |> json_response(200)
    end

    test "matrix works", %{conn: conn} do
      assert %{"object" => %{"foo" => "bar"}} =
               conn
               |> get("/style/matrix-object/;object=foo,bar")
               |> json_response(200)
    end

    test "matrix fails without semicolon", %{conn: conn} do
      assert_raise Apical.Exceptions.ParameterError,
                   "Parameter Error in operation pathParamMatrixObject (in path): matrix style `object=foo,bar` for parameter `object` is missing a leading semicolon, use format: `;object=...`",
                   fn ->
                     get(conn, "/style/matrix-object/object=foo,bar")
                   end
    end

    test "matrix fails if you don't match name", %{conn: conn} do
      assert_raise Apical.Exceptions.ParameterError,
                   "Parameter Error in operation pathParamMatrixObject (in path): matrix key `value` provided for array named `object`, use format: `;object=...`",
                   fn ->
                     get(conn, "/style/matrix-object/;value=foo,bar")
                   end
    end

    test "matrix fails if you don't have an even number of params", %{conn: conn} do
      assert_raise Apical.Exceptions.ParameterError,
                   "Parameter Error in operation pathParamMatrixObject (in path): matrix object parameter `;object=foo,bar,baz` for parameter `object` has an odd number of entries",
                   fn ->
                     get(conn, "/style/matrix-object/;object=foo,bar,baz")
                   end
    end

    test "matrix exploded works", %{conn: conn} do
      assert %{"object" => %{"foo" => "bar", "baz" => "quux"}} =
               conn
               |> get("/style/matrix-object-explode/;foo=bar;baz=quux")
               |> json_response(200)
    end

    test "matrix exploded works with empty string", %{conn: conn} do
      assert %{"object" => %{"foo" => "bar", "baz" => ""}} =
               conn
               |> get("/style/matrix-object-explode/;foo=bar;baz=")
               |> json_response(200)
    end

    test "matrix exploded works with empty string with no equals", %{conn: conn} do
      assert %{"object" => %{"foo" => "bar", "baz" => ""}} =
               conn
               |> get("/style/matrix-object-explode/;foo=bar;baz")
               |> json_response(200)
    end

    test "label works", %{conn: conn} do
      assert %{"object" => %{"foo" => "bar"}} =
               conn
               |> get("/style/label-object/.foo.bar")
               |> json_response(200)
    end

    test "label fails if you don't have an even number of params", %{conn: conn} do
      assert_raise Apical.Exceptions.ParameterError,
                   "Parameter Error in operation pathParamLabelObject (in path): label object parameter `.foo.bar.baz` for parameter `object` has an odd number of entries",
                   fn ->
                     get(conn, "/style/label-object/.foo.bar.baz")
                   end
    end

    test "label exploded works", %{conn: conn} do
      assert %{"object" => %{"foo" => "bar", "baz" => "quux"}} =
               conn
               |> get("/style/label-object-explode/.foo=bar.baz=quux")
               |> json_response(200)
    end

    test "label exploded fails if you don't have an even number of params", %{conn: conn} do
      assert_raise Apical.Exceptions.ParameterError,
                   "Parameter Error in operation pathParamLabelObjectExplode (in path): label object parameter `.foo=bar=baz` for parameter `object` has a malformed entry: `foo=bar=baz`",
                   fn ->
                     get(conn, "/style/label-object-explode/.foo=bar=baz")
                   end
    end

    test "simple works", %{conn: conn} do
      assert %{"object" => %{"foo" => "bar"}} =
               conn
               |> get("/style/simple-object/foo,bar")
               |> json_response(200)
    end

    test "simple raises 400 on non-even number of values", %{conn: conn} do
      assert_raise Apical.Exceptions.ParameterError,
                   "Parameter Error in operation pathParamSimpleObject (in path): comma delimited object parameter `foo,bar,baz` for parameter `object` has an odd number of entries",
                   fn ->
                     get(conn, "/style/simple-object/foo,bar,baz")
                   end
    end

    test "simple exploded works", %{conn: conn} do
      assert %{"object" => %{"foo" => "bar", "baz" => "quux"}} =
               conn
               |> get("/style/simple-object-explode/foo=bar,baz=quux")
               |> json_response(200)
    end

    test "simple exploded raises 400 on malformed values", %{conn: conn} do
      assert_raise Apical.Exceptions.ParameterError,
                   "Parameter Error in operation pathParamSimpleObjectExplode (in path): comma delimited object parameter `foo=bar=baz` for parameter `object` has a malformed entry: `foo=bar=baz`",
                   fn ->
                     get(conn, "/style/simple-object-explode/foo=bar=baz")
                   end
    end
  end

  describe "for objects with inner types" do
    test "marshalling works", %{conn: conn} do
      assert %{"object" => %{"foo" => 1, "bar" => true, "quux" => 3}} =
               conn
               |> get("/marshal/object/foo,1,bar,true,quux,3")
               |> json_response(200)
    end
  end

  describe "for boolean schemas" do
    test "true works", %{conn: conn} do
      assert %{"boolean" => true} =
               conn
               |> get("/marshal/boolean/true")
               |> json_response(200)
    end

    test "false works", %{conn: conn} do
      assert %{"boolean" => false} =
               conn
               |> get("/marshal/boolean/false")
               |> json_response(200)
    end

    test "other string fails", %{conn: conn} do
      assert_raise ParameterError,
                   "Parameter Error in operation pathParamMarshalBoolean (in path): value \"not-a-boolean\" at `/` fails schema criterion at `#/paths/~1marshal~1boolean~1%7Bboolean%7D/get/parameters/0/schema/type`",
                   fn ->
                     get(conn, "/marshal/boolean/not-a-boolean")
                   end
    end
  end

  describe "for boolean-matrix schemas" do
    test "true works", %{conn: conn} do
      assert %{"boolean" => true} =
               conn
               |> get("/style/boolean-matrix/;boolean=true")
               |> json_response(200)
    end

    test "false works", %{conn: conn} do
      assert %{"boolean" => false} =
               conn
               |> get("/style/boolean-matrix/;boolean=false")
               |> json_response(200)
    end

    test "tag is true", %{conn: conn} do
      assert %{"boolean" => true} =
               conn
               |> get("/style/boolean-matrix/;boolean")
               |> json_response(200)
    end

    test "other string fails", %{conn: conn} do
      assert_raise ParameterError,
                   "Parameter Error in operation pathParamBooleanMatrix (in path): value \"not-a-boolean\" at `/` fails schema criterion at `#/paths/~1style~1boolean-matrix~1%7Bboolean%7D/get/parameters/0/schema/type`",
                   fn ->
                     get(conn, "/style/boolean-matrix/;boolean=not-a-boolean")
                   end
    end
  end

  describe "for boolean-label schemas" do
    test "true works", %{conn: conn} do
      assert %{"boolean" => true} =
               conn
               |> get("/style/boolean-label/.true")
               |> json_response(200)
    end

    test "false works", %{conn: conn} do
      assert %{"boolean" => false} =
               conn
               |> get("/style/boolean-label/.false")
               |> json_response(200)
    end

    test "other string fails", %{conn: conn} do
      assert_raise ParameterError,
                   "Parameter Error in operation pathParamBooleanLabel (in path): value \"not-a-boolean\" at `/` fails schema criterion at `#/paths/~1style~1boolean-label~1%7Bboolean%7D/get/parameters/0/schema/type`",
                   fn ->
                     get(conn, "/style/boolean-label/.not-a-boolean")
                   end
    end
  end

  describe "for number schemas" do
    test "floating point works", %{conn: conn} do
      assert %{"number" => 4.5} =
               conn
               |> get("/marshal/number/4.5")
               |> json_response(200)
    end

    test "integer works", %{conn: conn} do
      assert %{"number" => 4} =
               conn
               |> get("/marshal/number/4")
               |> json_response(200)
    end

    test "string fails", %{conn: conn} do
      assert_raise ParameterError, fn ->
        get(conn, "/marshal/number/foo")
      end
    end
  end

  describe "for multitype schemas" do
    test "floating point works", %{conn: conn} do
      assert %{"multitype" => 4.5} =
               conn
               |> get("/marshal/multitype/4.5")
               |> json_response(200)
    end

    test "integer works", %{conn: conn} do
      assert %{"multitype" => 4} =
               conn
               |> get("/marshal/multitype/4")
               |> json_response(200)
    end

    test "boolean works", %{conn: conn} do
      assert %{"multitype" => true} =
               conn
               |> get("/marshal/multitype/true")
               |> json_response(200)
    end

    test "null works with explicit null", %{conn: conn} do
      assert %{"multitype" => nil} =
               conn
               |> get("/marshal/multitype/null")
               |> json_response(200)
    end

    test "null works with string", %{conn: conn} do
      assert %{"multitype" => "string"} =
               conn
               |> get("/marshal/multitype/string")
               |> json_response(200)
    end
  end

  describe "for nullable object" do
    test "basic object works", %{conn: conn} do
      assert %{"object" => %{"foo" => "bar"}} =
               conn
               |> get("/marshal/nullableobject/;object=foo,bar")
               |> json_response(200)
    end

    test "null object works", %{conn: conn} do
      assert %{"object" => nil} =
               conn
               |> get("/marshal/nullableobject/;object")
               |> json_response(200)
    end

    test "empty object works", %{conn: conn} do
      assert %{"object" => %{}} =
               conn
               |> get("/marshal/nullableobject/;object=")
               |> json_response(200)
    end
  end

  describe "for nullable array" do
    test "basic array works", %{conn: conn} do
      assert %{"array" => ["foo", "bar"]} =
               conn
               |> get("/marshal/nullablearray/;array=foo,bar")
               |> json_response(200)
    end

    test "null array works", %{conn: conn} do
      assert %{"array" => nil} =
               conn
               |> get("/marshal/nullablearray/;array")
               |> json_response(200)
    end

    test "setting null will be treated as an array element", %{conn: conn} do
      assert %{"array" => ["null"]} =
               conn
               |> get("/marshal/nullablearray/;array=null")
               |> json_response(200)
    end

    test "empty array works", %{conn: conn} do
      assert %{"array" => []} =
               conn
               |> get("/marshal/nullablearray/;array=")
               |> json_response(200)
    end
  end

  describe "for custom style" do
    test "works"
  end

  describe "for schema" do
    test "works"
  end
end
