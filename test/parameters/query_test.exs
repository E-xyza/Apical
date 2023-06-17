defmodule ApicalTest.Parameters.QueryTest do
  defmodule Router do
    use Phoenix.Router

    require Apical

    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: QueryTest
        version: 1.0.0
      paths:
        "/required":
          get:
            operationId: queryParamRequired
            parameters:
              - name: required
                in: query
                required: true
        "/optional":
          get:
            operationId: queryParamOptional
            parameters:
              - name: optional
                in: query
              - name: deprecated
                in: query
                deprecated: true
              - name: explode
                in: query
                explode: true
              - name: style-default-array
                in: query
                schema:
                  type: array
              - name: style-form-array
                in: query
                style: form
                schema:
                  type: array
              - name: style-default-commaDelimited-array
                in: query
                explode: false
                schema:
                  type: array
              - name: style-form-commaDelimited-array
                in: query
                style: form
                explode: false
                schema:
                  type: array
              - name: style-spaceDelimited-array
                in: query
                style: spaceDelimited
                schema:
                  type: array
              - name: style-pipeDelimited-array
                in: query
                style: pipeDelimited
                schema:
                  type: array
              - name: style-default-commaDelimited-object
                in: query
                explode: false
                schema:
                  type: object
              - name: style-form-commaDelimited-object
                in: query
                style: form
                explode: false
                schema:
                  type: object
              - name: style-spaceDelimited-object
                in: query
                style: spaceDelimited
                schema:
                  type: object
              - name: style-pipeDelimited-object
                in: query
                style: pipeDelimited
                schema:
                  type: object
              - name: style-deepObject
                in: query
                style: deepObject
                explode: true
                schema:
                  type: object
              - name: style-custom
                in: query
                style: x-custom
              - name: style-custom-explode
                in: query
                explode: true
                style: x-custom
              - name: style-custom-override
                in: query
                style: x-custom-override
              - name: schema-nullable-array
                in: query
                explode: false
                schema:
                  type: ["null", array]
              - name: schema-nullable-object
                in: query
                explode: false
                schema:
                  type: ["null", object]
              - name: schema-number
                in: query
                schema:
                  type: number
              - name: schema-integer
                in: query
                schema:
                  type: integer
              - name: schema-boolean
                in: query
                schema:
                  type: boolean
              - name: schema-string
                in: query
                schema:
                  type: string
              - name: schema-multitype
                in: query
                schema:
                  type: [integer, number, string, "null", boolean]
              - name: marshal-array
                in: query
                explode: false
                schema:
                  type: array
                  prefixItems:
                    - type: integer
                    - type: string
                  items:
                    type: integer
              - name: marshal-object
                in: query
                explode: false
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
              - name: schema-number-limit
                in: query
                schema:
                  type: number
                  minimum: 0
              - name: allow-reserved
                in: query
                allowReserved: true
            responses:
              "200":
                description: OK
        "/by-operation-parameter":
          get:
            operationId: queryParamStyleByOperationParameter
            parameters:
              - name: style-custom-override
                in: query
                style: x-custom-override
      """,
      root: "/",
      controller: ApicalTest.Parameters.QueryTest,
      styles: [{"x-custom", {__MODULE__, :x_custom}}],
      parameters: [
        "style-custom-override": [
          styles: [{"x-custom-override", {__MODULE__, :x_custom, ["by parameter"]}}]
        ]
      ],
      operation_ids: [
        queryParamStyleByOperationParameter: [
          parameters: [
            "style-custom-override": [
              styles: [{"x-custom-override", {__MODULE__, :x_custom, ["by operation parameter"]}}]
            ]
          ]
        ]
      ],
      content_type: "application/yaml"
    )

    def x_custom("ok"), do: {:ok, 47}
    def x_custom("error_message"), do: {:error, "message"}
    def x_custom("error_list"), do: {:error, message: "list"}
    def x_custom(_, true), do: {:ok, "explode"}
    def x_custom(_, level), do: {:ok, level}
  end

  use ApicalTest.EndpointCase
  alias Plug.Conn
  alias Apical.Exceptions.ParameterError

  for ops <- ~w(queryParamRequired queryParamOptional queryParamStyleByOperationParameter)a do
    def unquote(ops)(conn, params) do
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.send_resp(200, Jason.encode!(params))
    end
  end

  describe "for a required query parameter" do
    test "it serializes", %{conn: conn} do
      assert %{"required" => "foo"} = json_response(get(conn, "/required/?required=foo"), 200)
    end

    test "it fails when not present", %{conn: conn} do
      assert %{status: 400} = get(conn, "/required/?")
    end

    test "it fails no query is present", %{conn: conn} do
      assert %{status: 400} = get(conn, "/required/")
    end
  end

  describe "for an optional query parameter" do
    test "it serializes", %{conn: conn} do
      assert %{"optional" => "bar"} =
               conn
               |> get("/optional/?optional=bar")
               |> json_response(200)
    end

    test "it is not there when not", %{conn: conn} do
      refute conn
             |> get("/optional/?")
             |> json_response(200)
             |> is_map_key("optional")
    end

    test "it is not there when query is completely missing", %{conn: conn} do
      refute conn
             |> get("/optional/")
             |> json_response(200)
             |> is_map_key("optional")
    end

    test "it is empty string when content is empty", %{conn: conn} do
      assert %{"optional" => ""} =
               conn
               |> get("/optional/?optional")
               |> json_response(200)
    end
  end

  describe "for a deprecated query parameter" do
    test "it returns a 299 header", %{conn: conn} do
      response = get(conn, "/optional/?deprecated=foo")

      assert {"warning", "299 - the query parameter `deprecated` is deprecated."} =
               List.keyfind(response.resp_headers, "warning", 0)

      assert %{"deprecated" => "foo"} = json_response(response, 200)
    end
  end

  describe "for styled query parameters with array type" do
    test "default works", %{conn: conn} do
      assert %{"style-default-array" => ["foo", "bar"]} =
               conn
               |> get("/optional/?style-default-array=foo&style-default-array=bar")
               |> json_response(200)
    end

    test "form works", %{conn: conn} do
      assert %{"style-form-array" => ["foo", "bar"]} =
               conn
               |> get("/optional/?style-form-array=foo&style-form-array=bar")
               |> json_response(200)
    end

    test "form works with empty", %{conn: conn} do
      assert %{"style-form-array" => []} =
               conn
               |> get("/optional/?style-form-array=")
               |> json_response(200)
    end

    test "default unexploded works", %{conn: conn} do
      assert %{"style-default-commaDelimited-array" => ["foo", "bar"]} =
               conn
               |> get("/optional/?style-default-commaDelimited-array=foo,bar")
               |> json_response(200)
    end

    test "form unexploded works", %{conn: conn} do
      assert %{"style-form-commaDelimited-array" => ["foo", "bar"]} =
               conn
               |> get("/optional/?style-form-commaDelimited-array=foo,bar")
               |> json_response(200)
    end

    test "form unexploded works with empty", %{conn: conn} do
      assert %{"style-form-commaDelimited-array" => []} =
               conn
               |> get("/optional/?style-form-commaDelimited-array=")
               |> json_response(200)
    end

    test "spaceDelimited works with space", %{conn: conn} do
      assert %{"style-spaceDelimited-array" => ["foo", "bar"]} =
               conn
               |> get("/optional/?style-spaceDelimited-array=foo%20bar")
               |> json_response(200)
    end

    test "spaceDelimited works with empty", %{conn: conn} do
      assert %{"style-spaceDelimited-array" => []} =
               conn
               |> get("/optional/?style-spaceDelimited-array=")
               |> json_response(200)
    end

    test "pipeDelimited works with pipe", %{conn: conn} do
      assert %{"style-pipeDelimited-array" => ["foo", "bar"]} =
               conn
               |> get("/optional/?style-pipeDelimited-array=foo%7Cbar")
               |> json_response(200)
    end

    test "pipeDelimited works with empty", %{conn: conn} do
      assert %{"style-pipeDelimited-array" => []} =
               conn
               |> get("/optional/?style-pipeDelimited-array=")
               |> json_response(200)
    end
  end

  describe "for arrays with inner types" do
    test "marshalling works", %{conn: conn} do
      assert %{"marshal-array" => [1, "bar", 3]} =
               conn
               |> get("/optional/?marshal-array=1,bar,3")
               |> json_response(200)
    end
  end

  describe "for styled query parameters with object type" do
    test "default works", %{conn: conn} do
      assert %{"style-default-commaDelimited-object" => %{"foo" => "bar"}} =
               conn
               |> get("/optional/?style-default-commaDelimited-object=foo,bar")
               |> json_response(200)
    end

    test "form works", %{conn: conn} do
      assert %{"style-form-commaDelimited-object" => %{"foo" => "bar"}} =
               conn
               |> get("/optional/?style-form-commaDelimited-object=foo,bar")
               |> json_response(200)
    end

    test "odd number of form parameters fails", %{conn: conn} do
      assert_raise Apical.Exceptions.ParameterError,
                   "Parameter Error in operation queryParamOptional (in query): comma delimited object parameter `foo,bar,baz` for parameter `style-form-commaDelimited-object` has an odd number of entries",
                   fn ->
                     get(conn, "/optional/?style-form-commaDelimited-object=foo,bar,baz")
                   end
    end

    test "spaceDelimited works with space", %{conn: conn} do
      assert %{"style-spaceDelimited-object" => %{"foo" => "bar"}} =
               conn
               |> get("/optional/?style-spaceDelimited-object=foo%20bar")
               |> json_response(200)
    end

    test "odd number of space delimited parameters fails", %{conn: conn} do
      assert_raise Apical.Exceptions.ParameterError,
                   "Parameter Error in operation queryParamOptional (in query): space delimited object parameter `foo%20bar%20baz` for parameter `style-spaceDelimited-object` has an odd number of entries",
                   fn ->
                     get(conn, "/optional/?style-spaceDelimited-object=foo%20bar%20baz")
                   end
    end

    test "pipeDelimited works with pipe", %{conn: conn} do
      assert %{"style-pipeDelimited-object" => %{"foo" => "bar"}} =
               conn
               |> get("/optional/?style-pipeDelimited-object=foo%7Cbar")
               |> json_response(200)
    end

    test "odd number of pipe delimited parameters fails", %{conn: conn} do
      assert_raise Apical.Exceptions.ParameterError,
                   "Parameter Error in operation queryParamOptional (in query): pipe delimited object parameter `foo%7Cbar%7Cbaz` for parameter `style-pipeDelimited-object` has an odd number of entries",
                   fn ->
                     get(conn, "/optional/?style-pipeDelimited-object=foo%7Cbar%7Cbaz")
                   end
    end

    test "deepObject works", %{conn: conn} do
      assert %{"style-deepObject" => %{"foo" => "bar", "baz" => "quux"}} =
               conn
               |> get("/optional/?style-deepObject[foo]=bar&style-deepObject[baz]=quux")
               |> json_response(200)
    end
  end

  describe "for objects with inner types" do
    test "marshalling works", %{conn: conn} do
      assert %{"marshal-object" => %{"foo" => 1, "bar" => true, "quux" => 3}} =
               conn
               |> get("/optional/?marshal-object=foo,1,bar,true,quux,3")
               |> json_response(200)
    end
  end

  describe "for boolean schemas" do
    test "true works", %{conn: conn} do
      assert %{"schema-boolean" => true} =
               conn
               |> get("/optional/?schema-boolean=true")
               |> json_response(200)
    end

    test "false works", %{conn: conn} do
      assert %{"schema-boolean" => false} =
               conn
               |> get("/optional/?schema-boolean=false")
               |> json_response(200)
    end

    test "flag is true", %{conn: conn} do
      assert %{"schema-boolean" => true} =
               conn
               |> get("/optional/?schema-boolean")
               |> json_response(200)
    end

    test "nothing fails", %{conn: conn} do
      assert_raise ParameterError, fn ->
        get(conn, "/optional/?schema-boolean=")
      end
    end

    test "other string fails", %{conn: conn} do
      assert_raise ParameterError, fn ->
        get(conn, "/optional/?schema-boolean=not-a-boolean")
      end
    end
  end

  describe "for number schemas" do
    test "floating point works", %{conn: conn} do
      assert %{"schema-number" => 4.5} =
               conn
               |> get("/optional/?schema-number=4.5")
               |> json_response(200)
    end

    test "integer works", %{conn: conn} do
      assert %{"schema-number" => 4} =
               conn
               |> get("/optional/?schema-number=4")
               |> json_response(200)
    end

    test "string fails", %{conn: conn} do
      assert_raise ParameterError, fn ->
        get(conn, "/optional/?schema-number=foo")
      end
    end
  end

  describe "for multitype schemas" do
    test "floating point works", %{conn: conn} do
      assert %{"schema-multitype" => 4.5} =
               conn
               |> get("/optional/?schema-multitype=4.5")
               |> json_response(200)
    end

    test "integer works", %{conn: conn} do
      assert %{"schema-multitype" => 4} =
               conn
               |> get("/optional/?schema-multitype=4")
               |> json_response(200)
    end

    test "boolean works", %{conn: conn} do
      assert %{"schema-multitype" => true} =
               conn
               |> get("/optional/?schema-multitype=true")
               |> json_response(200)
    end

    test "null works with nothing", %{conn: conn} do
      assert %{"schema-multitype" => nil} =
               conn
               |> get("/optional/?schema-multitype=")
               |> json_response(200)
    end

    test "null works with explicit null", %{conn: conn} do
      assert %{"schema-multitype" => nil} =
               conn
               |> get("/optional/?schema-multitype=null")
               |> json_response(200)
    end

    test "null works with string", %{conn: conn} do
      assert %{"schema-multitype" => "string"} =
               conn
               |> get("/optional/?schema-multitype=string")
               |> json_response(200)
    end
  end

  describe "for nullable object" do
    test "basic object works", %{conn: conn} do
      %{"schema-nullable-object" => %{"foo" => "bar"}} =
        conn
        |> get("/optional/?schema-nullable-object=foo,bar")
        |> json_response(200)
    end

    test "null object works", %{conn: conn} do
      %{"schema-nullable-object" => nil} =
        conn
        |> get("/optional/?schema-nullable-object")
        |> json_response(200)
    end

    test "empty object works", %{conn: conn} do
      assert %{"schema-nullable-object" => %{}} =
               conn
               |> get("/optional/?schema-nullable-object=")
               |> json_response(200)
    end
  end

  describe "for nullable array" do
    test "basic array works", %{conn: conn} do
      assert %{"schema-nullable-array" => ["foo", "bar"]} =
               conn
               |> get("/optional/?schema-nullable-array=foo,bar")
               |> json_response(200)
    end

    test "null array works", %{conn: conn} do
      assert %{"schema-nullable-array" => nil} =
               conn
               |> get("/optional/?schema-nullable-array")
               |> json_response(200)
    end

    test "setting null will be treated as an array element", %{conn: conn} do
      assert %{"schema-nullable-array" => ["null"]} =
               conn
               |> get("/optional/?schema-nullable-array=null")
               |> json_response(200)
    end

    test "empty array works", %{conn: conn} do
      assert %{"schema-nullable-array" => []} =
               conn
               |> get("/optional/?schema-nullable-array=")
               |> json_response(200)
    end
  end

  describe "for schema" do
    test "number greater than zero works", %{conn: conn} do
      assert %{"schema-number-limit" => 2} =
               conn
               |> get("/optional/?schema-number-limit=2")
               |> json_response(200)
    end

    test "number less than zero is rejected", %{conn: conn} do
      assert_raise ParameterError,
                   "Parameter Error in operation queryParamOptional (in query): value `-1.5` at `/` fails schema criterion at `#/paths/~1optional/get/parameters/26/schema/minimum`",
                   fn ->
                     get(conn, "/optional/?schema-number-limit=-1.5")
                   end
    end
  end

  describe "for custom style" do
    test "content is overloadable with marshalling", %{conn: conn} do
      assert %{"style-custom" => 47} =
               conn
               |> get("/optional/?style-custom=ok")
               |> json_response(200)
    end

    test "content can error with a message", %{conn: conn} do
      assert_raise ParameterError, "Parameter Error in operation queryParamOptional (in query): custom parser for style `x-custom` in property `style-custom` failed: message", fn ->
        get(conn, "/optional/?style-custom=error_message")
      end
    end

    test "content can error with a keywordlist", %{conn: conn} do
      assert_raise ParameterError, "Parameter Error in operation queryParamOptional (in query): custom parser for style `x-custom` in property `style-custom` failed: list", fn ->
        get(conn, "/optional/?style-custom=error_list")
      end
    end

    test "content can error exploded", %{conn: conn} do
      assert %{"style-custom-explode" => "explode"} =
        conn
        |> get("/optional/?style-custom-explode=ok")
        |> json_response(200)
    end

    test "content can be custom styled at the parameter level", %{conn: conn} do
      assert %{"style-custom-override" => "by parameter"} =
        conn
        |> get("/optional/?style-custom-override=ok")
        |> json_response(200)
    end

    test "content can be custom styled at the operation/parameter level", %{conn: conn} do
      assert %{"style-custom-override" => "by operation parameter"} =
        conn
        |> get("/by-operation-parameter/?style-custom-override=ok")
        |> json_response(200)
    end
  end

  describe "for allowReserved" do
    test "content is obtainable", %{conn: conn} do
      # note that this is missing the # and & characters because these are ambiguous and can break
      # decoding.
      assert %{"allow-reserved" => ":/?[]@!$'()*+,;="} =
               conn
               |> get("/optional/?allow-reserved=:/?[]@!$'()*+,;=")
               |> json_response(200)
    end
  end

  describe "for unspecified content" do
    test "nothing appears the no parameters is unspecified", %{conn: conn} do
      response = get(conn, "/optional/?unspecified=abc")

      assert {_, "299 - the key `unspecified` is not specified in the schema"} =
               List.keyfind(response.resp_headers, "warning", 0)

      assert %{} == json_response(response, 200)
    end
  end

  describe "400 errors for parsing problems" do
    test "when a reserved character appears", %{conn: conn} do
      assert_raise ParameterError,
                   "Parameter Error in operation queryParamOptional (in query): invalid character [",
                   fn ->
                     get(conn, "/optional/?schema-string=[")
                   end
    end
  end
end
