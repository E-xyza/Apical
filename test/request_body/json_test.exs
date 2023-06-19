defmodule ApicalTest.RequestBody.JsonTest do
  defmodule Router do
    use Phoenix.Router

    require Apical

    Apical.router_from_string(
      """
      openapi: 3.1.0
      info:
        title: RequestBodyJsonTest
        version: 1.0.0
      paths:
        "/array":
          post:
            operationId: requestBodyJsonArray
            requestBody:
              content:
                "application/json":
                  schema:
                    type: array
        "/object":
          post:
            operationId: requestBodyJsonObject
            requestBody:
              content:
                "application/json":
                  schema:
                    type: object
        "/generic":
          post:
            operationId: requestBodyGeneric
            requestBody:
              content:
                "application/json": {}
        "/nest_all_json":
          post:
            operationId: nest_all_json
            requestBody:
              content:
                "application/json":
                  schema:
                    type: object
      """,
      root: "/",
      controller: ApicalTest.RequestBody.JsonTest,
      content_type: "application/yaml",
      operation_ids: [
        nest_all_json: [nest_all_json: true]
      ]
    )
  end

  use ApicalTest.EndpointCase

  alias Plug.Parsers.UnsupportedMediaTypeError
  alias Plug.Conn
  alias Apical.Exceptions.ParameterError
  alias ApicalTest.RequestBody.JsonTest.Endpoint

  for ops <- ~w(requestBodyJsonObject requestBodyJsonArray requestBodyGeneric nest_all_json)a do
    def unquote(ops)(conn, params) do
      conn
      |> Conn.put_resp_content_type("application/json")
      |> Conn.send_resp(200, Jason.encode!(params))
    end
  end

  defp do_post(conn, route, payload, content_type \\ "application/json") do
    payload_binary = Jason.encode!(payload)
    content_length = byte_size(payload_binary)

    conn
    |> Conn.put_req_header("content-type", content_type)
    |> Conn.put_req_header("content-length", "#{content_length}")
    |> post(route, payload_binary)
  end

  describe "for posted array data" do
    test "it is nested params under json", %{conn: conn} do
      assert %{"_json" => ["foo", "bar"]} =
               conn
               |> do_post("/array", ["foo", "bar"])
               |> json_response(200)
    end

    test "passing wrong data", %{conn: conn} do
      assert_raise ParameterError,
                   "Parameter Error in operation requestBodyJsonArray (in body): value `{\"foo\":\"bar\"}` at `/` fails schema criterion at `#/paths/~1array/post/requestBody/content/application~1json/schema/type`",
                   fn ->
                     do_post(conn, "/array", %{"foo" => "bar"})
                   end
    end
  end

  describe "for posted object data" do
    test "it incorporates into params", %{conn: conn} do
      assert %{"foo" => "bar"} =
               conn
               |> do_post("/object", %{"foo" => "bar"})
               |> json_response(200)
    end

    test "passing wrong data", %{conn: conn} do
      assert_raise ParameterError,
                   "Parameter Error in operation requestBodyJsonObject (in body): value `[\"foo\",\"bar\"]` at `/` fails schema criterion at `#/paths/~1object/post/requestBody/content/application~1json/schema/type`",
                   fn ->
                     do_post(conn, "/object", ["foo", "bar"])
                   end
    end
  end

  describe "for posted scalar data" do
    test "null is nested params under json", %{conn: conn} do
      assert %{"_json" => nil} =
               conn
               |> do_post("/generic", nil)
               |> json_response(200)
    end

    test "boolean is nested params under json", %{conn: conn} do
      assert %{"_json" => true} =
               conn
               |> do_post("/generic", true)
               |> json_response(200)
    end

    test "number is nested params under json", %{conn: conn} do
      assert %{"_json" => 4.7} =
               conn
               |> do_post("/generic", 4.7)
               |> json_response(200)
    end

    test "string is nested params under json", %{conn: conn} do
      assert %{"_json" => "string"} =
               conn
               |> do_post("/generic", "string")
               |> json_response(200)
    end

    test "array is nested params under json", %{conn: conn} do
      assert %{"_json" => [1, 2]} =
               conn
               |> do_post("/generic", [1, 2])
               |> json_response(200)
    end

    test "object is not nested", %{conn: conn} do
      assert %{"foo" => "bar"} =
               conn
               |> do_post("/generic", %{"foo" => "bar"})
               |> json_response(200)
    end
  end

  describe "generic errors when posting" do
    # TODO: create a more meaningful apical error for this
    test "passing data with the wrong content-type", %{conn: conn} do
      assert_raise UnsupportedMediaTypeError,
                   "unsupported media type text/csv",
                   fn ->
                     do_post(conn, "/object", %{}, "text/csv")
                   end
    end

    test "passing data with no content-type", %{conn: conn} do
      assert %{plug_status: 400} = %Apical.Exceptions.MissingContentTypeError{}

      assert_raise Apical.Exceptions.MissingContentTypeError, "missing content-type header", fn ->
        conn
        |> Plug.Adapters.Test.Conn.conn(:post, "/object", "{}")
        |> Endpoint.call(Endpoint.init([]))
      end
    end
  end

  describe "object with nest_all_json option" do
    test "nests the json in the _json field", %{conn: conn} do
      assert %{"_json" => %{"foo" => "bar"}} =
               conn
               |> do_post("/nest_all_json", %{"foo" => "bar"})
               |> json_response(200)
    end
  end
end
