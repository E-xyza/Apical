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
              - name: style-default-object
                in: query
                schema:
                  type: object
              - name: style-form-object
                in: query
                style: form
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
                schema:
                  type: object
              - name: style-custom
                in: query
                style: x-custom
              - name: schema-nullable-array
                in: query
                schema:
                  type: ["null", array]
              - name: schema-nullable-object
                in: query
                schema:
                  type: ["null", object]
              - name: schema-number
                in: query
                style: deepObject
                schema:
                  type: number
              - name: schema-integer
                in: query
                style: deepObject
                schema:
                  type: integer
              - name: schema-boolean
                in: query
                style: deepObject
                schema:
                  type: boolean
              - name: marshal-array
                in: query
                schema:
                  type: array
                  prefixItems:
                    - type: integer
                    - type: string
                  items:
                    type: integer
              - name: marshal-object
                in: query
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
              - name: allow-reserved
                in: query
                allowReserved: true
            responses:
              "200":
                description: OK
        "/unspecified":
          get:
            operationId: unspecified
      """,
      controller: ApicalTest.Parameters.QueryTest,
      content_type: "application/yaml",
      styles: [{"x-custom", {__MODULE__, :x_custom}}]
    )

    def x_custom("foo"), do: 47
  end

  use ApicalTest.ConnCase
  alias Plug.Conn

  for ops <- ~w(queryParamRequired queryParamOptional)a do
    def unquote(ops)(conn, params) do
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.send_resp(200, Jason.encode!(params))
    end
  end

  def unspecified(conn = %{params: params}, params) do
    conn
    |> Conn.put_resp_content_type("application/json")
    |> Conn.send_resp(
      200,
      Jason.encode!(%{"params" => params, "path_params" => conn.path_params})
    )
  end

  describe "for a required query parameter" do
    test "it serializes into required", %{conn: conn} do
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
    test "it serializes into required", %{conn: conn} do
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
      response = get(conn, "/optional/?style-default-array=foo,bar")

      assert %{"style-default-array" => ["foo", "bar"]} = json_response(response, 200)
    end

    test "form works", %{conn: conn} do
      response = get(conn, "/optional/?style-form-array=foo,bar")

      assert %{"style-form-array" => ["foo", "bar"]} = json_response(response, 200)
    end

    test "spaceDelimited works with space", %{conn: conn} do
      response = get(conn, "/optional/?style-spaceDelimited-array=foo%20bar")

      assert %{"style-spaceDelimited-array" => ["foo", "bar"]} = json_response(response, 200)
    end

    test "pipeDelimited works with pipe", %{conn: conn} do
      response = get(conn, "/optional/?style-pipeDelimited-array=foo%7Cbar")

      assert %{"style-pipeDelimited-array" => ["foo", "bar"]} = json_response(response, 200)
    end
  end

  describe "for arrays with inner types" do
    test "marshalling works", %{conn: conn} do
      response = get(conn, "/optional/?marshal-array=1,bar,2")

      assert %{"marshal-array" => [1, "bar", 2]} = json_response(response, 200)
    end
  end

  describe "for styled query parameters with object type" do
    test "default works", %{conn: conn} do
      response = get(conn, "/optional/?style-default-object=foo,bar")

      assert %{"style-default-object" => %{"foo" => "bar"}} = json_response(response, 200)
    end

    test "form works", %{conn: conn} do
      response = get(conn, "/optional/?style-form-object=foo,bar")

      assert %{"style-form-object" => %{"foo" => "bar"}} = json_response(response, 200)
    end

    test "spaceDelimited works with space", %{conn: conn} do
      response = get(conn, "/optional/?style-spaceDelimited-object=foo%20bar")

      assert %{"style-spaceDelimited-object" => %{"foo" => "bar"}} = json_response(response, 200)
    end

    test "pipeDelimited works with pipe", %{conn: conn} do
      response = get(conn, "/optional/?style-pipeDelimited-object=foo%7Cbar")

      assert %{"style-pipeDelimited-object" => %{"foo" => "bar"}} = json_response(response, 200)
    end

    test "deepObject works", %{conn: conn} do
      response = get(conn, "/optional/?style-deepObject[foo]=bar&style-deepObject[baz]=quux")

      assert %{"style-deepObject" => %{"foo" => "bar", "baz" => "quux"}} =
               json_response(response, 200)
    end
  end

  describe "for objects with inner types" do
    test "marshalling works", %{conn: conn} do
      response = get(conn, "/optional/?marshal-object=foo,1,bar,true,quux,3")

      assert %{"marshal-object" => %{"foo" => 1, "bar" => true, "quux" => 3}} =
               json_response(response, 200)
    end
  end

  describe "for boolean schemas" do
    test "true works", %{conn: conn} do
      response = get(conn, "/optional/?schema-boolean=true")
      assert %{"schema-boolean" => true} = json_response(response, 200)
    end

    test "false works", %{conn: conn} do
      response = get(conn, "/optional/?schema-boolean=false")
      assert %{"schema-boolean" => false} = json_response(response, 200)
    end

    test "flag is true", %{conn: conn} do
      response = get(conn, "/optional/?schema-boolean")
      assert %{"schema-boolean" => true} = json_response(response, 200)
    end

    test "nothing fails"

    test "other string fails"
  end

  describe "for number schemas" do
    test "floating point works", %{conn: conn} do
      response = get(conn, "/optional/?schema-number=4.5")
      assert %{"schema-number" => 4.5} = json_response(response, 200)
    end

    test "integer works", %{conn: conn} do
      response = get(conn, "/optional/?schema-number=4")
      assert %{"schema-number" => 4} = json_response(response, 200)
    end

    test "string fails"
  end

  describe "for nullable object" do
    test "basic object works", %{conn: conn} do
      response = get(conn, "/optional/?schema-nullable-object=foo,bar")
      assert %{"schema-nullable-object" => %{"foo" => "bar"}} = json_response(response, 200)
    end

    test "null object works", %{conn: conn} do
      response = get(conn, "/optional/?schema-nullable-object")
      assert %{"schema-nullable-object" => nil} = json_response(response, 200)
    end

    test "empty object works", %{conn: conn} do
      response = get(conn, "/optional/?schema-nullable-object=")
      assert %{"schema-nullable-object" => %{}} = json_response(response, 200)
    end
  end

  describe "for nullable array" do
    test "basic array works", %{conn: conn} do
      response = get(conn, "/optional/?schema-nullable-array=foo,bar")
      assert %{"schema-nullable-array" => ["foo", "bar"]} = json_response(response, 200)
    end

    test "null array works", %{conn: conn} do
      response = get(conn, "/optional/?schema-nullable-array")
      assert %{"schema-nullable-array" => nil} = json_response(response, 200)
    end

    test "empty array works", %{conn: conn} do
      response = get(conn, "/optional/?schema-nullable-array=")
      assert %{"schema-nullable-array" => []} = json_response(response, 200)
    end
  end

  describe "for custom style" do
    test "content is overloadable", %{conn: conn} do
      response = get(conn, "/optional/?style-custom=foo")
      assert %{"style-custom" => 47} = json_response(response, 200)
    end
  end

  describe "for allowReserved" do
    test "content is obtainable", %{conn: conn} do
      # note that this is missing the # and & characters because these are ambiguous and can break
      # decoding.
      response = get(conn, "/optional/?allow-reserved=:/?[]@!$'()*+,;=")
      assert %{"allow-reserved" => ":/?[]@!$'()*+,;="} = json_response(response, 200)
    end
  end

  describe "for unspecified content" do
    test "nothing appears the no parameters is unspecified", %{conn: conn} do
      response = get(conn, "/optional/?unspecified=abc")
      assert {_, "299 - the key `unspecified` is not specified in the schema"} = List.keyfind(response.resp_headers, "warning", 0)
      assert %{} == json_response(response, 200)
    end

    test "nothing appears when no parameters are given", %{conn: conn} do
      response = get(conn, "/unspecified/?unspecified=abc")
      assert %{"params" => %{}, "path_params" => %{}} == json_response(response, 200)
    end
  end
end
