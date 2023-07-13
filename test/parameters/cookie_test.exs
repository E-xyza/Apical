defmodule ApicalTest.Parameters.CookieTest do
  defmodule Router do
    use Phoenix.Router

    require Apical

    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: CookieTest
        version: 1.0.0
      paths:
        "/required":
          get:
            operationId: cookieParamRequired
            parameters:
              - name: required
                in: cookie
                required: true
        "/optional":
          get:
            operationId: cookieParamOptional
            parameters:
              - name: optional
                in: cookie
              - name: deprecated
                in: cookie
                deprecated: true
              - name: style-default-array
                in: cookie
                schema:
                  type: array
              - name: style-form-array
                in: cookie
                style: form
                schema:
                  type: array
              - name: style-form-array-unexplode
                in: cookie
                style: form
                explode: false
                schema:
                  type: array
              - name: marshal-array
                in: cookie
                schema:
                  type: array
                  prefixItems:
                    - type: integer
                    - type: string
                  items:
                    type: integer
              - name: style-default-object
                in: cookie
                explode: false
                schema:
                  type: object
              - name: style-form-object
                in: cookie
                style: form
                explode: false
                schema:
                  type: object
              - name: marshal-object
                in: cookie
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
              - name: schema-boolean
                in: cookie
                schema:
                  type: boolean
              - name: schema-number
                in: cookie
                schema:
                  type: number
              - name: schema-multitype
                in: cookie
                schema:
                  type: [integer, number, string, "null", boolean]
              - name: schema-nullable-array
                in: cookie
                explode: false
                schema:
                  type: ["null", array]
              - name: schema-nullable-object
                in: cookie
                explode: false
                schema:
                  type: ["null", object]
              - name: schema-number-limit
                in: cookie
                schema:
                  type: number
                  minimum: 0
              - name: style-custom
                in: cookie
                style: x-custom
              - name: style-custom-explode
                in: cookie
                style: x-custom
                explode: true
              - name: style-custom-override
                in: cookie
                style: x-custom
              - name: marshal-defined
                in: cookie
                schema:
                  oneOf:
                    - type: integer
                    - type: boolean
        "/override":
          get:
            operationId: cookieParamOverride
            parameters:
              - name: style-custom-override
                in: cookie
                style: x-custom
      """,
      root: "/",
      controller: ApicalTest.Parameters.CookieTest,
      encoding: "application/yaml",
      styles: [{"x-custom", {__MODULE__, :x_custom}}],
      parameters: [
        "style-custom-override": [
          styles: [{"x-custom", {__MODULE__, :x_custom, ["by parameter"]}}]
        ],
        "marshal-defined": [
          # also test `atom` style here
          marshal: :defined_marshalling
        ]
      ],
      operation_ids: [
        cookieParamOverride: [
          parameters: [
            "style-custom-override": [
              styles: [{"x-custom", {__MODULE__, :x_custom, ["by operation parameter"]}}]
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

    def defined_marshalling("true"), do: {:ok, true}
    def defined_marshalling("47"), do: {:ok, 47}
    def defined_marshalling(_), do: {:error, "invalid"}
  end

  use ApicalTest.EndpointCase
  alias Plug.Conn
  alias Apical.Exceptions.ParameterError

  for operation <- ~w(cookieParamRequired cookieParamOptional cookieParamOverride)a do
    def unquote(operation)(conn, params) do
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.send_resp(200, Jason.encode!(params))
    end
  end

  describe "for a required cookie parameter" do
    test "it serializes", %{conn: conn} do
      assert %{"required" => "foo"} =
               conn
               |> put_req_cookie("required", "foo")
               |> get("/required")
               |> json_response(200)
    end

    test "it fails when not present", %{conn: conn} do
      assert_raise ParameterError,
                   "Parameter Error in operation cookieParamRequired (in cookie): required parameter `required` not present",
                   fn ->
                     get(conn, "/required")
                   end
    end
  end

  describe "for an optional cookie parameter" do
    test "it serializes", %{conn: conn} do
      assert %{"optional" => "foo"} =
               conn
               |> put_req_cookie("optional", "foo")
               |> get("/optional")
               |> json_response(200)
    end

    test "it warns if deprecated", %{conn: conn} do
      response =
        conn
        |> put_req_cookie("deprecated", "foo")
        |> get("/optional")

      assert {"warning", "299 - the cookie parameter `deprecated` is deprecated."} =
               List.keyfind(response.resp_headers, "warning", 0)

      assert %{"deprecated" => "foo"} = json_response(response, 200)
    end

    test "unlisted cookie doesn't appear in params", %{conn: conn} do
      assert %{} ==
               conn
               |> put_req_cookie("unlisted", "foo")
               |> get("/optional")
               |> json_response(200)
    end
  end

  describe "for styled cookie parameters with array type" do
    test "default works", %{conn: conn} do
      assert %{"style-default-array" => ["foo", "bar"]} =
               conn
               |> put_req_header("cookie", "style-default-array=foo&style-default-array=bar")
               |> get("/optional")
               |> json_response(200)
    end

    test "form works", %{conn: conn} do
      assert %{"style-form-array" => ["foo", "bar"]} =
               conn
               |> put_req_header("cookie", "style-form-array=foo&style-form-array=bar")
               |> get("/optional")
               |> json_response(200)
    end

    test "empty array works with no entries", %{conn: conn} do
      assert %{"style-form-array" => []} =
               conn
               |> put_req_cookie("style-form-array", "")
               |> get("/optional")
               |> json_response(200)
    end

    test "form not-exploded works", %{conn: conn} do
      assert %{"style-form-array-unexplode" => ["foo", "bar"]} =
               conn
               |> put_req_cookie("style-form-array-unexplode", "foo,bar")
               |> get("/optional")
               |> json_response(200)
    end
  end

  describe "for arrays with inner types" do
    test "marshalling works", %{conn: conn} do
      assert %{"marshal-array" => [1, "bar", 3]} =
               conn
               |> put_req_header("cookie", "marshal-array=1&marshal-array=bar&marshal-array=3")
               |> get("/optional")
               |> json_response(200)
    end
  end

  describe "for styled cookie parameters with object type" do
    test "default works", %{conn: conn} do
      assert %{"style-default-object" => %{"foo" => "bar"}} =
               conn
               |> put_req_cookie("style-default-object", "foo,bar")
               |> get("/optional")
               |> json_response(200)
    end

    test "form works", %{conn: conn} do
      assert %{"style-form-object" => %{"foo" => "bar", "baz" => "quux"}} =
               conn
               |> put_req_cookie("style-form-object", "foo,bar,baz,quux")
               |> get("/optional")
               |> json_response(200)
    end

    test "form errors when an odd number of terms", %{conn: conn} do
      assert_raise Apical.Exceptions.ParameterError,
                   "Parameter Error in operation cookieParamOptional (in cookie): form object parameter `foo,bar,baz` for parameter `style-form-object` has an odd number of entries",
                   fn ->
                     conn
                     |> put_req_cookie("style-form-object", "foo,bar,baz")
                     |> get("/optional")
                   end
    end

    test "form empty object works", %{conn: conn} do
      assert %{"style-form-object" => %{}} =
               conn
               |> put_req_cookie("style-form-object", "")
               |> get("/optional")
               |> json_response(200)
    end
  end

  describe "for objects with inner types" do
    test "marshalling works", %{conn: conn} do
      assert %{"marshal-object" => %{"foo" => 1, "bar" => true, "quux" => 3}} =
               conn
               |> put_req_cookie("marshal-object", "foo,1,bar,true,quux,3")
               |> get("/optional")
               |> json_response(200)
    end
  end

  describe "for boolean schemas" do
    test "true works", %{conn: conn} do
      assert %{"schema-boolean" => true} =
               conn
               |> put_req_cookie("schema-boolean", "true")
               |> get("/optional")
               |> json_response(200)
    end

    test "false works", %{conn: conn} do
      assert %{"schema-boolean" => false} =
               conn
               |> put_req_cookie("schema-boolean", "false")
               |> get("/optional")
               |> json_response(200)
    end

    test "other string fails", %{conn: conn} do
      assert_raise ParameterError, fn ->
        conn
        |> put_req_cookie("schema-boolean", "not-a-boolean")
        |> get("/optional")
      end
    end
  end

  describe "for number schemas" do
    test "floating point works", %{conn: conn} do
      assert %{"schema-number" => 4.5} =
               conn
               |> put_req_cookie("schema-number", "4.5")
               |> get("/optional/")
               |> json_response(200)
    end

    test "integer works", %{conn: conn} do
      assert %{"schema-number" => 4} =
               conn
               |> put_req_cookie("schema-number", "4")
               |> get("/optional/")
               |> json_response(200)
    end

    test "string fails", %{conn: conn} do
      assert_raise ParameterError,
                   "Parameter Error in operation cookieParamOptional (in cookie): value `\"foo\"` at `/` fails schema criterion at `#/paths/~1optional/get/parameters/10/schema/type`",
                   fn ->
                     conn
                     |> put_req_cookie("schema-number", "foo")
                     |> get("/optional/")
                   end
    end
  end

  describe "for multitype schemas" do
    test "floating point works", %{conn: conn} do
      assert %{"schema-multitype" => 4.5} =
               conn
               |> put_req_cookie("schema-multitype", "4.5")
               |> get("/optional/")
               |> json_response(200)
    end

    test "integer works", %{conn: conn} do
      assert %{"schema-multitype" => 4} =
               conn
               |> put_req_cookie("schema-multitype", "4")
               |> get("/optional/")
               |> json_response(200)
    end

    test "boolean works", %{conn: conn} do
      assert %{"schema-multitype" => true} =
               conn
               |> put_req_cookie("schema-multitype", "true")
               |> get("/optional/")
               |> json_response(200)
    end

    test "null works with nothing", %{conn: conn} do
      assert %{"schema-multitype" => nil} =
               conn
               |> put_req_cookie("schema-multitype", "")
               |> get("/optional/")
               |> json_response(200)
    end

    test "null works with explicit null", %{conn: conn} do
      assert %{"schema-multitype" => nil} =
               conn
               |> put_req_cookie("schema-multitype", "null")
               |> get("/optional/")
               |> json_response(200)
    end

    test "null works with string", %{conn: conn} do
      assert %{"schema-multitype" => "string"} =
               conn
               |> put_req_cookie("schema-multitype", "string")
               |> get("/optional/")
               |> json_response(200)
    end
  end

  describe "for nullable array" do
    test "basic array works", %{conn: conn} do
      assert %{"schema-nullable-array" => ["foo", "bar"]} =
               conn
               |> put_req_cookie("schema-nullable-array", "foo,bar")
               |> get("/optional/")
               |> json_response(200)
    end

    test "setting null will be treated as an null element", %{conn: conn} do
      assert %{"schema-nullable-array" => ["null"]} =
               conn
               |> put_req_cookie("schema-nullable-array", "null")
               |> get("/optional/")
               |> json_response(200)
    end

    test "empty string is empty array", %{conn: conn} do
      assert %{"schema-nullable-array" => []} =
               conn
               |> put_req_cookie("schema-nullable-array", "")
               |> get("/optional/")
               |> json_response(200)
    end

    test "no item is null", %{conn: conn} do
      assert %{"schema-nullable-array" => nil} =
               conn
               |> put_req_header("cookie", "schema-nullable-array")
               |> get("/optional")
               |> json_response(200)
    end
  end

  describe "for nullable object" do
    test "basic object works", %{conn: conn} do
      %{"schema-nullable-object" => %{"foo" => "bar"}} =
        conn
        |> put_req_cookie("schema-nullable-object", "foo,bar")
        |> get("/optional/")
        |> json_response(200)
    end

    test "null object works", %{conn: conn} do
      %{"schema-nullable-object" => nil} =
        conn
        |> put_req_cookie("schema-nullable-object", "null")
        |> get("/optional/")
        |> json_response(200)
    end

    test "empty object works", %{conn: conn} do
      assert %{"schema-nullable-object" => %{}} =
               conn
               |> put_req_cookie("schema-nullable-object", "")
               |> get("/optional/")
               |> json_response(200)
    end

    test "no item is null", %{conn: conn} do
      assert %{"schema-nullable-object" => nil} =
               conn
               |> put_req_header("cookie", "schema-nullable-object")
               |> get("/optional")
               |> json_response(200)
    end
  end

  describe "for schema" do
    test "number greater than zero works", %{conn: conn} do
      assert %{"schema-number-limit" => 2} =
               conn
               |> put_req_cookie("schema-number-limit", "2")
               |> get("/optional/")
               |> json_response(200)
    end

    test "number less than zero is rejected", %{conn: conn} do
      assert_raise ParameterError,
                   "Parameter Error in operation cookieParamOptional (in cookie): value `-1.5` at `/` fails schema criterion at `#/paths/~1optional/get/parameters/14/schema/minimum`",
                   fn ->
                     conn
                     |> put_req_cookie("schema-number-limit", "-1.5")
                     |> get("/optional/")
                   end
    end
  end

  describe "for custom style" do
    test "content is overloadable with marshalling", %{conn: conn} do
      assert %{"style-custom" => 47} =
               conn
               |> put_req_cookie("style-custom", "ok")
               |> get("/optional/")
               |> json_response(200)
    end

    test "content can error with a message", %{conn: conn} do
      assert_raise ParameterError,
                   "Parameter Error in operation cookieParamOptional (in cookie): custom parser for style `x-custom` in property `style-custom` failed: message",
                   fn ->
                     conn
                     |> put_req_cookie("style-custom", "error_message")
                     |> get("/optional/")
                   end
    end

    test "content can error with a keywordlist", %{conn: conn} do
      assert_raise ParameterError,
                   "Parameter Error in operation cookieParamOptional (in cookie): custom parser for style `x-custom` in property `style-custom` failed: list",
                   fn ->
                     conn
                     |> put_req_cookie("style-custom", "error_list")
                     |> get("/optional/?style-custom=error_list")
                   end
    end

    test "content can error exploded", %{conn: conn} do
      assert %{"style-custom-explode" => "explode"} =
               conn
               |> put_req_cookie("style-custom-explode", "ok")
               |> get("/optional/")
               |> json_response(200)
    end

    test "content can be custom styled at the parameter level", %{conn: conn} do
      assert %{"style-custom-override" => "by parameter"} =
               conn
               |> put_req_cookie("style-custom-override", "ok")
               |> get("/optional/")
               |> json_response(200)
    end

    test "content can be custom styled at the operation/parameter level", %{conn: conn} do
      assert %{"style-custom-override" => "by operation parameter"} =
               conn
               |> put_req_cookie("style-custom-override", "ok")
               |> get("/override/")
               |> json_response(200)
    end
  end

  describe "for a marshall-defined parameter" do
    test "works with a valid value", %{conn: conn} do
      assert %{"marshal-defined" => true} =
               conn
               |> put_req_cookie("marshal-defined", "true")
               |> get("/optional/")
               |> json_response(200)

      assert %{"marshal-defined" => 47} =
               conn
               |> put_req_cookie("marshal-defined", "47")
               |> get("/optional/")
               |> json_response(200)
    end

    test "422 with an invalid value", %{conn: conn} do
      assert_raise Apical.Exceptions.ParameterError,
                   "Parameter Error in operation cookieParamOptional (in cookie): invalid",
                   fn ->
                     conn
                     |> put_req_cookie("marshal-defined", "invalid")
                     |> get("/optional/")
                   end
    end
  end
end
