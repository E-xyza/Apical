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

      assert %{"array" => [1, "bar", 3]} = json_response(response, 200)
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

  describe "for objects with inner types" do
    test "marshalling works", %{conn: conn} do
      response = get(conn, "/marshal/object/foo,1,bar,true,quux,3")

      assert %{"object" => %{"foo" => 1, "bar" => true, "quux" => 3}} =
               json_response(response, 200)
    end
  end

  describe "for boolean schemas" do
    test "true works", %{conn: conn} do
      response = get(conn, "/marshal/boolean/true")
      assert %{"boolean" => true} = json_response(response, 200)
    end

    test "false works", %{conn: conn} do
      response = get(conn, "/marshal/boolean/false")
      assert %{"boolean" => false} = json_response(response, 200)
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
      response = get(conn, "/style/boolean-matrix/;boolean=true")
      assert %{"boolean" => true} = json_response(response, 200)
    end

    test "false works", %{conn: conn} do
      response = get(conn, "/style/boolean-matrix/;boolean=false")
      assert %{"boolean" => false} = json_response(response, 200)
    end

    test "tag is true", %{conn: conn} do
      response = get(conn, "/style/boolean-matrix/;boolean")
      assert %{"boolean" => true} = json_response(response, 200)
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
      response = get(conn, "/style/boolean-label/.true")
      assert %{"boolean" => true} = json_response(response, 200)
    end

    test "false works", %{conn: conn} do
      response = get(conn, "/style/boolean-label/.false")
      assert %{"boolean" => false} = json_response(response, 200)
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
      response = get(conn, "/marshal/number/4.5")
      assert %{"number" => 4.5} = json_response(response, 200)
    end

    test "integer works", %{conn: conn} do
      response = get(conn, "/marshal/number/4")
      assert %{"number" => 4} = json_response(response, 200)
    end

    test "string fails", %{conn: conn} do
      assert_raise ParameterError, fn ->
        get(conn, "/marshal/number/foo")
      end
    end
  end

  describe "for multitype schemas" do
    test "floating point works", %{conn: conn} do
      response = get(conn, "/marshal/multitype/4.5")
      assert %{"multitype" => 4.5} = json_response(response, 200)
    end

    test "integer works", %{conn: conn} do
      response = get(conn, "/marshal/multitype/4")
      assert %{"multitype" => 4} = json_response(response, 200)
    end

    test "boolean works", %{conn: conn} do
      response = get(conn, "/marshal/multitype/true")
      assert %{"multitype" => true} = json_response(response, 200)
    end

    test "null works with explicit null", %{conn: conn} do
      response = get(conn, "/marshal/multitype/null")
      assert %{"multitype" => nil} = json_response(response, 200)
    end

    test "null works with string", %{conn: conn} do
      response = get(conn, "/marshal/multitype/string")
      assert %{"multitype" => "string"} = json_response(response, 200)
    end
  end

  describe "for nullable object" do
    test "basic object works", %{conn: conn} do
      response = get(conn, "/marshal/nullableobject/;object=foo,bar")
      assert %{"object" => %{"foo" => "bar"}} = json_response(response, 200)
    end

    test "null object works", %{conn: conn} do
      response = get(conn, "/marshal/nullableobject/;object")
      assert %{"object" => nil} = json_response(response, 200)
    end

    test "empty object works", %{conn: conn} do
      response = get(conn, "/marshal/nullableobject/;object=")
      assert %{"object" => %{}} = json_response(response, 200)
    end
  end

  describe "for nullable array" do
    test "basic array works", %{conn: conn} do
      response = get(conn, "/marshal/nullablearray/;array=foo,bar")
      assert %{"array" => ["foo", "bar"]} = json_response(response, 200)
    end

    test "null array works", %{conn: conn} do
      response = get(conn, "/marshal/nullablearray/;array")
      assert %{"array" => nil} = json_response(response, 200)
    end

    test "setting null will be treated as an array element", %{conn: conn} do
      response = get(conn, "/marshal/nullablearray/;array=null")
      assert %{"array" => ["null"]} = json_response(response, 200)
    end

    test "empty array works", %{conn: conn} do
      response = get(conn, "/marshal/nullablearray/;array=")
      assert %{"array" => []} = json_response(response, 200)
    end
  end
end
