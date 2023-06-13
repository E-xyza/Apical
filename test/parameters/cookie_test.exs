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
              - name: style-form-object
                in: cookie
                style: form
                schema:
                  type: object
              - name: style-form-object-explode
                in: cookie
                style: form
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

  for ops <- ~w(cookieParamRequired cookieParamOptional)a do
    def unquote(ops)(conn, params) do
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.send_resp(200, Jason.encode!(params))
    end
  end

  defp put_cookie(conn, key, value) do
    %{conn | req_cookies: Map.put(conn.req_cookies, key, value)}
  end

  describe "for a required cookie parameter" do
    test "it serializes into required", %{conn: conn} do
      assert %{"required" => "foo"} =
               conn
               |> put_req_cookie("required", "foo")
               |> get("/required")
               |> json_response(200)
    end

    test "it fails when not present", %{conn: conn} do
      assert_raise ParameterError,
                   "Parameter Error in operation cookieParamRequired (in cookie): required cookie `required` not present",
                   fn ->
                     get(conn, "/required")
                   end
    end
  end

  describe "for an optional cookie parameter" do
    test "it serializes into required", %{conn: conn} do
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
               List.keyfind(response.resp_cookies, "warning", 0)

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
               |> put_req_cookie("style-default-array", "foo,bar")
               |> get("/optional")
               |> json_response(200)
    end

    test "form works", %{conn: conn} do
      assert %{"style-form-array" => ["foo", "bar"]} =
               conn
               |> put_req_cookie("style-form-array", "foo,bar")
               |> get("/optional")
               |> json_response(200)
    end

    test "empty array works", %{conn: conn} do
      assert %{"style-form-array" => []} =
               conn
               |> put_req_cookie("style-form-array", "")
               |> get("/optional")
               |> json_response(200)
    end
  end

  describe "for arrays with inner types" do
    test "marshalling works", %{conn: conn} do
      assert %{"marshal-array" => [1, "bar", 3]} =
               conn
               |> put_req_cookie("marshal-array", "1,bar,3")
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
                   "Parameter Error in operation cookieParamOptional (in path): comma delimited object parameter `foo,bar,baz` for parameter `style-form-object` has an odd number of entries",
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

    test "form explode works", %{conn: conn} do
      assert %{"style-form-object-explode" => %{"foo" => "bar", "baz" => "quux"}} =
               conn
               |> put_req_cookie("style-form-object-explode", "foo=bar,baz=quux")
               |> get("/optional")
               |> json_response(200)
    end

    test "form explode manages empty strings", %{conn: conn} do
      assert %{"style-form-object-explode" => %{"foo" => "bar", "baz" => ""}} =
               conn
               |> put_req_cookie("style-form-object-explode", "foo=bar,baz=")
               |> get("/optional")
               |> json_response(200)
    end

    test "form explode manages very empty entry", %{conn: conn} do
      assert %{"style-form-object-explode" => %{"foo" => "bar", "baz" => ""}} =
               conn
               |> put_req_cookie("style-form-object-explode", "foo=bar,baz")
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
                   "Parameter Error in operation cookieParamOptional (in cookie): value \"foo\" at `/` fails schema criterion at `#/paths/~1optional/get/parameters/10/schema/type`",
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

  describe "for custom style" do
    test "works"
  end

  describe "for schema" do
    test "works"
  end
end
