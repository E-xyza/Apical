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
                in: header
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
              - name: style-simple-array
                in: cookie
                style: simple
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
                schema:
                  type: object
              - name: style-simple-object
                in: cookie
                style: simple
                schema:
                  type: object
              - name: style-simple-object-explode
                in: cookie
                style: simple
                explode: true
                schema:
                  type: object
              - name: marshal-object
                in: cookie
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
      """,
      root: "/",
      controller: ApicalTest.Parameters.CookieTest,
      content_type: "application/yaml"
    )
  end

  use ApicalTest.ConnCase
  alias Plug.Conn
  alias Apical.Exceptions.ParameterError

  for ops <- ~w(headerParamRequired headerParamOptional)a do
    def unquote(ops)(conn, params) do
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.send_resp(200, Jason.encode!(params))
    end
  end

  describe "for a required header parameter" do
    test "it serializes into required", %{conn: conn} do
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
    test "it serializes into required", %{conn: conn} do
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
                   "Parameter Error in operation headerParamOptional (in path): comma delimited object parameter `foo,bar,baz` for parameter `style-simple-object` has an odd number of entries",
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
                   "Parameter Error in operation headerParamOptional (in header): value \"foo\" at `/` fails schema criterion at `#/paths/~1optional/get/parameters/10/schema/type`",
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

  describe "for custom style" do
    test "works"
  end

  describe "for schema" do
    test "works"
  end
end
