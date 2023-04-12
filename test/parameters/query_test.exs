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
            responses:
              "200":
                description: OK
      """,
      controller: ApicalTest.Parameters.QueryTest,
      content_type: "application/yaml"
    )
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
      response = get(conn, "/optional/?style-pipeDelimited-array=foo|bar")

      assert %{"style-pipeDelimited-array" => ["foo", "bar"]} = json_response(response, 200)
    end
  end
end
