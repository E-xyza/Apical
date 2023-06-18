defmodule ApicalTest.Parameters.HeaderTest do
  defmodule Router do
    use Phoenix.Router

    require Apical

    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: HeaderTest
        version: 1.0.0
      paths:
        "/required":
          get:
            operationId: headerParamRequired
            parameters:
              - name: required
                in: header
                required: true
        "/optional":
          get:
            operationId: headerParamOptional
            parameters:
              - name: optional
                in: header
              - name: deprecated
                in: header
                deprecated: true
              - name: style-default-array
                in: header
                schema:
                  type: array
              - name: style-simple-array
                in: header
                style: simple
                schema:
                  type: array
              - name: marshal-array
                in: header
                schema:
                  type: array
                  prefixItems:
                    - type: integer
                    - type: string
                  items:
                    type: integer
              - name: style-default-object
                in: header
                schema:
                  type: object
              - name: style-simple-object
                in: header
                style: simple
                schema:
                  type: object
              - name: style-simple-object-explode
                in: header
                style: simple
                explode: true
                schema:
                  type: object
              - name: marshal-object
                in: header
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
              - name: schema-boolean
                in: header
                schema:
                  type: boolean
              - name: schema-number
                in: header
                schema:
                  type: number
              - name: schema-multitype
                in: header
                schema:
                  type: [integer, number, string, "null", boolean]
              - name: schema-nullable-array
                in: header
                schema:
                  type: [array, "null"]
              - name: schema-nullable-object
                in: header
                schema:
                  type: [object, "null"]
              - name: schema-number-limit
                in: header
                schema:
                  type: number
                  minimum: 0
              - name: style-custom
                in: header
                style: x-custom
              - name: style-custom-explode
                in: header
                style: x-custom
                explode: true
              - name: style-custom-override
                in: header
                style: x-custom
        "/override":
          get:
            operationId: headerParamOverride
            parameters:
              - name: style-custom-override
                in: header
                style: x-custom

      """,
      root: "/",
      controller: ApicalTest.Parameters.HeaderTest,
      content_type: "application/yaml",
      styles: [{"x-custom", {__MODULE__, :x_custom}}],
      parameters: [
        "style-custom-override": [
          styles: [{"x-custom", {__MODULE__, :x_custom, ["by parameter"]}}],
        ]
      ],
      operation_ids: [
        headerParamOverride: [
          parameters: [
            "style-custom-override": [
              styles: [{"x-custom", {__MODULE__, :x_custom, ["by operation parameter"]}}],
            ]
          ]
        ]
      ]
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

  for ops <- ~w(headerParamRequired headerParamOptional headerParamOverride)a do
    def unquote(ops)(conn, params) do
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.send_resp(200, Jason.encode!(params))
    end
  end

  describe "for a required header parameter" do
    test "it serializes", %{conn: conn} do
      assert %{"required" => "foo"} =
               conn
               |> Conn.put_req_header("required", "foo")
               |> get("/required")
               |> json_response(200)
    end

    test "it fails when not present", %{conn: conn} do
      assert_raise ParameterError,
                   "Parameter Error in operation headerParamRequired (in header): required header `required` not present",
                   fn ->
                     get(conn, "/required")
                   end
    end
  end

  describe "for an optional header parameter" do
    test "it serializes", %{conn: conn} do
      assert %{"optional" => "foo"} =
               conn
               |> Conn.put_req_header("optional", "foo")
               |> get("/optional")
               |> json_response(200)
    end

    test "it warns if deprecated", %{conn: conn} do
      response =
        conn
        |> Conn.put_req_header("deprecated", "foo")
        |> get("/optional")

      assert {"warning", "299 - the header parameter `deprecated` is deprecated."} =
               List.keyfind(response.resp_headers, "warning", 0)

      assert %{"deprecated" => "foo"} = json_response(response, 200)
    end

    test "unlisted header doesn't appear in params", %{conn: conn} do
      assert %{} ==
               conn
               |> Conn.put_req_header("unlisted", "foo")
               |> get("/optional")
               |> json_response(200)
    end
  end

  describe "for styled header parameters with array type" do
    test "default works", %{conn: conn} do
      assert %{"style-default-array" => ["foo", "bar"]} =
               conn
               |> Conn.put_req_header("style-default-array", "foo,bar")
               |> get("/optional")
               |> json_response(200)
    end

    test "simple works", %{conn: conn} do
      assert %{"style-simple-array" => ["foo", "bar"]} =
               conn
               |> Conn.put_req_header("style-simple-array", "foo,bar")
               |> get("/optional")
               |> json_response(200)
    end

    test "empty array works", %{conn: conn} do
      assert %{"style-simple-array" => []} =
               conn
               |> Conn.put_req_header("style-simple-array", "")
               |> get("/optional")
               |> json_response(200)
    end
  end

  describe "for arrays with inner types" do
    test "marshalling works", %{conn: conn} do
      assert %{"marshal-array" => [1, "bar", 3]} =
               conn
               |> Conn.put_req_header("marshal-array", "1,bar,3")
               |> get("/optional")
               |> json_response(200)
    end
  end

  describe "for styled header parameters with object type" do
    test "default works", %{conn: conn} do
      assert %{"style-default-object" => %{"foo" => "bar"}} =
               conn
               |> Conn.put_req_header("style-default-object", "foo,bar")
               |> get("/optional")
               |> json_response(200)
    end

    test "simple works", %{conn: conn} do
      assert %{"style-simple-object" => %{"foo" => "bar", "baz" => "quux"}} =
               conn
               |> Conn.put_req_header("style-simple-object", "foo,bar,baz,quux")
               |> get("/optional")
               |> json_response(200)
    end

    test "simple errors when an odd number of terms", %{conn: conn} do
      assert_raise Apical.Exceptions.ParameterError,
                   "Parameter Error in operation headerParamOptional (in header): comma delimited object parameter `foo,bar,baz` for parameter `style-simple-object` has an odd number of entries",
                   fn ->
                     conn
                     |> Conn.put_req_header("style-simple-object", "foo,bar,baz")
                     |> get("/optional")
                   end
    end

    test "simple empty object works", %{conn: conn} do
      assert %{"style-simple-object" => %{}} =
               conn
               |> Conn.put_req_header("style-simple-object", "")
               |> get("/optional")
               |> json_response(200)
    end

    test "simple explode works", %{conn: conn} do
      assert %{"style-simple-object-explode" => %{"foo" => "bar", "baz" => "quux"}} =
               conn
               |> Conn.put_req_header("style-simple-object-explode", "foo=bar,baz=quux")
               |> get("/optional")
               |> json_response(200)
    end

    test "simple explode manages empty strings", %{conn: conn} do
      assert %{"style-simple-object-explode" => %{"foo" => "bar", "baz" => ""}} =
               conn
               |> Conn.put_req_header("style-simple-object-explode", "foo=bar,baz=")
               |> get("/optional")
               |> json_response(200)
    end

    test "simple explode manages very empty entry", %{conn: conn} do
      assert %{"style-simple-object-explode" => %{"foo" => "bar", "baz" => ""}} =
               conn
               |> Conn.put_req_header("style-simple-object-explode", "foo=bar,baz")
               |> get("/optional")
               |> json_response(200)
    end
  end

  describe "for objects with inner types" do
    test "marshalling works", %{conn: conn} do
      assert %{"marshal-object" => %{"foo" => 1, "bar" => true, "quux" => 3}} =
               conn
               |> Conn.put_req_header("marshal-object", "foo,1,bar,true,quux,3")
               |> get("/optional")
               |> json_response(200)
    end
  end

  describe "for boolean schemas" do
    test "true works", %{conn: conn} do
      assert %{"schema-boolean" => true} =
               conn
               |> Conn.put_req_header("schema-boolean", "true")
               |> get("/optional")
               |> json_response(200)
    end

    test "false works", %{conn: conn} do
      assert %{"schema-boolean" => false} =
               conn
               |> Conn.put_req_header("schema-boolean", "false")
               |> get("/optional")
               |> json_response(200)
    end

    test "other string fails", %{conn: conn} do
      assert_raise ParameterError, fn ->
        conn
        |> Conn.put_req_header("schema-boolean", "not-a-boolean")
        |> get("/optional")
      end
    end
  end

  describe "for number schemas" do
    test "floating point works", %{conn: conn} do
      assert %{"schema-number" => 4.5} =
               conn
               |> Conn.put_req_header("schema-number", "4.5")
               |> get("/optional/")
               |> json_response(200)
    end

    test "integer works", %{conn: conn} do
      assert %{"schema-number" => 4} =
               conn
               |> Conn.put_req_header("schema-number", "4")
               |> get("/optional/")
               |> json_response(200)
    end

    test "string fails", %{conn: conn} do
      assert_raise ParameterError,
                   "Parameter Error in operation headerParamOptional (in header): value `\"foo\"` at `/` fails schema criterion at `#/paths/~1optional/get/parameters/10/schema/type`",
                   fn ->
                     conn
                     |> Conn.put_req_header("schema-number", "foo")
                     |> get("/optional/")
                   end
    end
  end

  describe "for multitype schemas" do
    test "floating point works", %{conn: conn} do
      assert %{"schema-multitype" => 4.5} =
               conn
               |> Conn.put_req_header("schema-multitype", "4.5")
               |> get("/optional/")
               |> json_response(200)
    end

    test "integer works", %{conn: conn} do
      assert %{"schema-multitype" => 4} =
               conn
               |> Conn.put_req_header("schema-multitype", "4")
               |> get("/optional/")
               |> json_response(200)
    end

    test "boolean works", %{conn: conn} do
      assert %{"schema-multitype" => true} =
               conn
               |> Conn.put_req_header("schema-multitype", "true")
               |> get("/optional/")
               |> json_response(200)
    end

    test "null works with nothing", %{conn: conn} do
      assert %{"schema-multitype" => nil} =
               conn
               |> Conn.put_req_header("schema-multitype", "")
               |> get("/optional/")
               |> json_response(200)
    end

    test "null works with explicit null", %{conn: conn} do
      assert %{"schema-multitype" => nil} =
               conn
               |> Conn.put_req_header("schema-multitype", "null")
               |> get("/optional/")
               |> json_response(200)
    end

    test "null works with string", %{conn: conn} do
      assert %{"schema-multitype" => "string"} =
               conn
               |> Conn.put_req_header("schema-multitype", "string")
               |> get("/optional/")
               |> json_response(200)
    end
  end

  describe "for nullable array" do
    test "basic array works", %{conn: conn} do
      assert %{"schema-nullable-array" => ["foo", "bar"]} =
               conn
               |> Conn.put_req_header("schema-nullable-array", "foo,bar")
               |> get("/optional/")
               |> json_response(200)
    end

    test "setting null will be treated as an null element", %{conn: conn} do
      assert %{"schema-nullable-array" => nil} =
               conn
               |> Conn.put_req_header("schema-nullable-array", "null")
               |> get("/optional/")
               |> json_response(200)
    end

    test "empty string is empty array", %{conn: conn} do
      assert %{"schema-nullable-array" => []} =
               conn
               |> Conn.put_req_header("schema-nullable-array", "")
               |> get("/optional/")
               |> json_response(200)
    end
  end

  describe "for nullable object" do
    test "basic object works", %{conn: conn} do
      %{"schema-nullable-object" => %{"foo" => "bar"}} =
        conn
        |> Conn.put_req_header("schema-nullable-object", "foo,bar")
        |> get("/optional/")
        |> json_response(200)
    end

    test "null object works", %{conn: conn} do
      %{"schema-nullable-object" => nil} =
        conn
        |> Conn.put_req_header("schema-nullable-object", "null")
        |> get("/optional/")
        |> json_response(200)
    end

    test "empty object works", %{conn: conn} do
      assert %{"schema-nullable-object" => %{}} =
               conn
               |> Conn.put_req_header("schema-nullable-object", "")
               |> get("/optional/")
               |> json_response(200)
    end
  end

  describe "for schema" do
    test "number greater than zero works", %{conn: conn} do
      assert %{"schema-number-limit" => 2} =
               conn
               |> Conn.put_req_header("schema-number-limit", "2")
               |> get("/optional/")
               |> json_response(200)
    end

    test "number less than zero is rejected", %{conn: conn} do
      assert_raise ParameterError,
                   "Parameter Error in operation headerParamOptional (in header): value `-1.5` at `/` fails schema criterion at `#/paths/~1optional/get/parameters/14/schema/minimum`",
                   fn ->
                     conn
                     |> Conn.put_req_header("schema-number-limit", "-1.5")
                     |> get("/optional/")
                   end
    end
  end

  describe "for custom style" do
    test "content is overloadable with marshalling", %{conn: conn} do
      assert %{"style-custom" => 47} =
               conn
               |> Conn.put_req_header("style-custom", "ok")
               |> get("/optional/")
               |> json_response(200)
    end

    test "content can error with a message", %{conn: conn} do
      assert_raise ParameterError,
                   "Parameter Error in operation headerParamOptional (in header): custom parser for style `x-custom` in property `style-custom` failed: message",
                   fn ->
                     conn
                     |> Conn.put_req_header("style-custom", "error_message")
                     |> get("/optional/")
                   end
    end

    test "content can error with a keywordlist", %{conn: conn} do
      assert_raise ParameterError,
                   "Parameter Error in operation headerParamOptional (in header): custom parser for style `x-custom` in property `style-custom` failed: list",
                   fn ->
                     conn
                     |> Conn.put_req_header("style-custom", "error_list")
                     |> get("/optional/?style-custom=error_list")
                   end
    end

    test "content can error exploded", %{conn: conn} do
      assert %{"style-custom-explode" => "explode"} =
               conn
               |> Conn.put_req_header("style-custom-explode", "ok")
               |> get("/optional/")
               |> json_response(200)
    end

    test "content can be custom styled at the parameter level", %{conn: conn} do
      assert %{"style-custom-override" => "by parameter"} =
               conn
               |> Conn.put_req_header("style-custom-override", "ok")
               |> get("/optional/")
               |> json_response(200)
    end

    test "content can be custom styled at the operation/parameter level", %{conn: conn} do
      assert %{"style-custom-override" => "by operation parameter"} =
               conn
               |> Conn.put_req_header("style-custom-override", "ok")
               |> get("/override/")
               |> json_response(200)
    end
  end
end
